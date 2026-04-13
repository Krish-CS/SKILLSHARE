import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_dialog.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_popup.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../utils/app_constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_helpers.dart';
import '../../utils/web_image_loader.dart';
import '../../widgets/filter_bottom_sheet.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import 'cart_screen.dart';
import 'shop_storefront_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  static const double _productPriceCeiling = 1000000;

  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  StreamSubscription<List<ProductModel>>? _productsSub;
  final Map<String, StreamSubscription<UserModel?>> _sellerUserSubs = {};
  final Map<String, StreamSubscription<Map<String, dynamic>>> _sellerShopSubs =
      {};

  List<ProductModel> _allProducts = [];
  List<ProductModel> _filteredProducts = [];
  List<ProductModel> _featuredProducts = [];
  final Map<String, String> _shopNameBySellerId = {};
  final Map<String, UserModel> _sellerById = {};
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'newest';
  double _minPrice = 0;
  double _maxPrice = _productPriceCeiling;

  static const Map<String, IconData> _categoryIcons = {
    'All': Icons.apps_rounded,
    'Electronics': Icons.devices_rounded,
    'Clothing': Icons.checkroom_rounded,
    'Home': Icons.home_rounded,
    'Tools': Icons.build_rounded,
    'Food': Icons.restaurant_rounded,
    'Books': Icons.menu_book_rounded,
    'Beauty': Icons.spa_rounded,
    'Sports': Icons.sports_rounded,
    'Toys': Icons.toys_rounded,
    'Art': Icons.palette_rounded,
    'Photography': Icons.camera_alt_rounded,
    'Baking': Icons.cake_rounded,
    'Carpentry': Icons.handyman_rounded,
    'Tailoring': Icons.cut_rounded,
    'Electrician': Icons.electric_bolt_rounded,
    'Plumbing': Icons.plumbing_rounded,
    'Painting': Icons.brush_rounded,
    'Gardening': Icons.grass_rounded,
    'Other': Icons.category_rounded,
  };

  List<String> get _categories => ['All', ...AppConstants.categories];

  @override
  void initState() {
    super.initState();
    _subscribeToProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _productsSub?.cancel();
    for (final sub in _sellerUserSubs.values) {
      sub.cancel();
    }
    for (final sub in _sellerShopSubs.values) {
      sub.cancel();
    }
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), _applyFilters);
  }

  Future<void> _openFilterSheet() async {
    final result = await FilterBottomSheet.show(
      context,
      mode: 'products',
      initialCategory: _selectedCategory == 'All' ? null : _selectedCategory,
      initialSortBy: _sortBy,
      initialMinRating: 0,
      initialMinPrice: _minPrice,
      initialMaxPrice: _maxPrice,
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedCategory = result.category ?? 'All';
      _sortBy = result.sortBy ?? 'newest';
      _minPrice = result.minPrice ?? 0;
      _maxPrice = result.maxPrice ?? _productPriceCeiling;
    });
    _applyFilters();
  }

  void _subscribeToProducts() {
    _productsSub = _firestoreService.streamAllProducts().listen(
      (products) {
        if (!mounted) return;
        _allProducts = products;
        _subscribeToSellerMetadata(products);
        _featuredProducts = _allProducts
            .where((p) => p.isAvailable && p.rating >= 4.0 && p.stock > 0)
            .toList()
          ..sort((a, b) => b.rating.compareTo(a.rating));
        if (_featuredProducts.isEmpty) {
          _featuredProducts = _allProducts.take(5).toList();
        } else {
          _featuredProducts = _featuredProducts.take(5).toList();
        }
        _applyFilters();
        if (_isLoading) setState(() => _isLoading = false);
      },
      onError: (e) {
        debugPrint('Error streaming products: $e');
        if (mounted && _isLoading) setState(() => _isLoading = false);
      },
    );
  }

  void _subscribeToSellerMetadata(List<ProductModel> products) {
    final sellerIds = products
        .map((p) => p.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final removedIds =
        _sellerUserSubs.keys.where((id) => !sellerIds.contains(id)).toList();
    for (final id in removedIds) {
      _sellerUserSubs.remove(id)?.cancel();
      _sellerShopSubs.remove(id)?.cancel();
    }

    for (final sellerId in sellerIds) {
      if (!_sellerUserSubs.containsKey(sellerId)) {
        _sellerUserSubs[sellerId] =
            _firestoreService.streamUserModel(sellerId).listen((user) {
          if (!mounted) return;
          if (user != null) {
            _sellerById[sellerId] = user;
            _resolveAndSetShopName(sellerId);
          }
        });
      }

      if (!_sellerShopSubs.containsKey(sellerId)) {
        _sellerShopSubs[sellerId] =
            _firestoreService.streamShopSettings(sellerId).listen((settings) {
          if (!mounted) return;
          final rawShopName = (settings['shopName'] as String?)?.trim() ?? '';
          if (rawShopName.isNotEmpty) {
            _shopNameBySellerId[sellerId] = rawShopName;
          } else {
            _resolveAndSetShopName(sellerId);
            return;
          }
          setState(() {});
        });
      }
    }
  }

  void _resolveAndSetShopName(String sellerId) {
    final configuredName = _shopNameBySellerId[sellerId];
    final sellerName = _sellerById[sellerId]?.name.trim() ?? '';
    if ((configuredName == null ||
            configuredName.isEmpty ||
            configuredName.endsWith(' Shop')) &&
        sellerName.isNotEmpty) {
      _shopNameBySellerId[sellerId] = '$sellerName Shop';
    }
    if (mounted) setState(() {});
  }

  String _resolveShopName(ProductModel product) {
    if (product.sourceType == 'skillshare') {
      return (product.displayShopName != null &&
              product.displayShopName!.trim().isNotEmpty)
          ? product.displayShopName!.trim()
          : 'SkillShare Official';
    }
    final sellerId = product.userId.trim();
    if (sellerId.isEmpty) return 'Shop';
    return _shopNameBySellerId[sellerId] ?? 'Shop';
  }

  Future<void> _openShopFromProduct(ProductModel product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopStorefrontScreen(
          sellerId: product.userId,
          initialShopName: _resolveShopName(product),
        ),
      ),
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final matchesSearch = _searchQuery.isEmpty ||
            product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            product.description
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
        final matchesCategory =
            _selectedCategory == 'All' || product.category == _selectedCategory;
        final matchesPrice =
            product.price >= _minPrice && product.price <= _maxPrice;
        return matchesSearch && matchesCategory && matchesPrice;
      }).toList();

      switch (_sortBy) {
        case 'price_low':
          _filteredProducts.sort((a, b) => a.price.compareTo(b.price));
          break;
        case 'price_high':
          _filteredProducts.sort((a, b) => b.price.compareTo(a.price));
          break;
        case 'rating':
          _filteredProducts.sort((a, b) => b.rating.compareTo(a.rating));
          break;
        case 'newest':
        default:
          _filteredProducts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    });
  }

  Future<void> _navigateToProductDetail(ProductModel product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ProductDetailScreen(product: product)),
    );
    // Stream auto-updates, no need to manually reload
  }

  Future<void> _handleAddProduct(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (!authProvider.isSkilledPerson) {
      AppPopup.show(context,
          message: 'Only skilled persons can add products',
          type: PopupType.warning);
      return;
    }
    if (userProvider.currentProfile == null &&
        authProvider.currentUser != null) {
      await userProvider.loadProfile(authProvider.currentUser!.uid);
    }
    if (userProvider.currentProfile?.isVerified != true) {
      if (!context.mounted) return;
      AppDialog.info(
        context,
        'To open your shop and sell products, complete Aadhaar + fingerprint verification first.\n\nGo to: Profile → Edit Profile → Verify Identity',
        title: 'Verification Required',
        buttonText: 'OK',
      );
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AddProductScreen()));
    // Stream auto-updates, no need to manually reload
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isCompact = MediaQuery.of(context).size.width < 380;
    final headerExpandedHeight = isCompact ? 176.0 : 168.0;
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── Amazon-style header ──
          SliverAppBar(
            pinned: true,
            floating: true,
            snap: true,
            expandedHeight: headerExpandedHeight,
            backgroundColor: AppTheme.primaryPurple,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.primaryPink],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'SkillShare Shop',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 17 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.shopping_cart_rounded,
                                  color: Colors.white),
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const CartScreen())),
                              tooltip: 'My Cart',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              visualDensity: VisualDensity.compact,
                              splashRadius: 20,
                            ),
                            if (authProvider.isSkilledPerson) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _handleAddProduct(context),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 8 : 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryOrange,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 3),
                                      Text('Sell',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: isCompact
                                  ? 'Search products...'
                                  : 'Search products, skills & more...',
                              hintStyle: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppTheme.primaryPink, size: 20),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 18,
                                      icon: const Icon(Icons.clear,
                                          size: 18, color: Colors.grey),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                        _applyFilters();
                                      },
                                    )
                                  : IconButton(
                                      onPressed: _openFilterSheet,
                                      tooltip: 'Filters',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 18,
                                      icon: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppTheme.primaryPurple,
                                              AppTheme.primaryPink,
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.tune_rounded,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Sort chips in the collapsed bar
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: _buildSortChips(),
              ),
            ),
          ),

          // ── Category chips ──
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          SliverToBoxAdapter(
            child: _buildCategoryChips(),
          ),

          // Spacer between categories and featured
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Featured / Top Rated horizontal section ──
          if (!_isLoading &&
              _featuredProducts.isNotEmpty &&
              _searchQuery.isEmpty &&
              _selectedCategory == 'All')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildFeaturedSection(),
              ),
            ),

          // ── Result count row ──
          if (!_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _buildResultsHeader(),
              ),
            ),

          // ── Products grid / loading ──
          if (_isLoading)
            SliverToBoxAdapter(child: _buildShimmerLoading())
          else if (_gridProducts.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: () {
                    final width = MediaQuery.of(context).size.width;
                    return (width / 220).floor().clamp(2, 7);
                  }(),
                  childAspectRatio: () {
                    final width = MediaQuery.of(context).size.width;
                    final columns = (width / 220).floor().clamp(2, 7);
                    if (columns >= 6) return 0.82;
                    if (columns >= 4) return 0.78;
                    if (columns == 3) return 0.74;
                    return 0.72;
                  }(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = _gridProducts[index];
                    return ProductCard(
                      product: product,
                      shopName: _resolveShopName(product),
                      onShopTap: () => _openShopFromProduct(product),
                      onTap: () => _navigateToProductDetail(product),
                    );
                  },
                  childCount: _gridProducts.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortChips() {
    final isCompact = MediaQuery.of(context).size.width < 380;
    final sortOptions = [
      ('newest', 'New Arrivals'),
      ('rating', 'Top Rated'),
      ('price_low', 'Price ↑'),
      ('price_high', 'Price ↓'),
    ];
    return Container(
      height: 40,
      color: AppTheme.primaryPurple.withValues(alpha: 0.9),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        itemCount: sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final isSelected = _sortBy == sortOptions[i].$1;
          return GestureDetector(
            onTap: () {
              setState(() => _sortBy = sortOptions[i].$1);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryPink
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryPink
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                sortOptions[i].$2,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    return Container(
      color: Colors.white,
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat;
          final icon = _categoryIcons[cat] ?? Icons.category_rounded;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategory = cat);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryPurple
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primaryPurple : Colors.grey[300]!,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color:
                                AppTheme.primaryPurple.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2))
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 14,
                      color: isSelected ? Colors.white : Colors.grey[700]),
                  const SizedBox(width: 5),
                  Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppTheme.primaryPurple, AppTheme.primaryPink]),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('⭐ TOP RATED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
              const SizedBox(width: 8),
              const Text('Featured Products',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 210,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _featuredProducts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final product = _featuredProducts[i];
                return _FeaturedCard(
                  product: product,
                  shopName: _resolveShopName(product),
                  onShopTap: () => _openShopFromProduct(product),
                  onTap: () => _navigateToProductDetail(product),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Products for the grid — excludes featured products to avoid repetition
  List<ProductModel> get _gridProducts {
    if (_searchQuery.isNotEmpty ||
        _selectedCategory != 'All' ||
        _featuredProducts.isEmpty) {
      return _filteredProducts;
    }
    final featuredIds = _featuredProducts.map((p) => p.id).toSet();
    final nonFeatured =
        _filteredProducts.where((p) => !featuredIds.contains(p.id)).toList();
    return nonFeatured;
  }

  Widget _buildResultsHeader() {
    final products = _gridProducts;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          Text(
            '${products.length} ${products.length == 1 ? 'result' : 'results'}',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF555555),
                fontWeight: FontWeight.w500),
          ),
          if (_selectedCategory != 'All') ...[
            const Text(' in ',
                style: TextStyle(fontSize: 13, color: Color(0xFF555555))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_selectedCategory,
                  style: const TextStyle(
                      color: AppTheme.primaryPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    final width = MediaQuery.of(context).size.width;
    final shimmerCount = (width / 220).floor().clamp(2, 7);
    final shimmerRatio = shimmerCount >= 4 ? 0.78 : 0.74;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: shimmerCount,
          childAspectRatio: shimmerRatio,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: shimmerCount * 2,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: 3,
                      child: Container(
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(10))))),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 12,
                              width: double.infinity,
                              color: Colors.white),
                          const SizedBox(height: 6),
                          Container(height: 10, width: 80, color: Colors.white),
                          const SizedBox(height: 6),
                          Container(height: 14, width: 60, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _searchQuery.isNotEmpty || _selectedCategory != 'All';
    final hasAnyProducts = _allProducts.isNotEmpty;
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered
                ? Icons.search_off_rounded
                : hasAnyProducts
                    ? Icons.check_circle_outline_rounded
                    : Icons.storefront_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered
                ? 'No products found'
                : hasAnyProducts
                    ? 'All products shown above'
                    : 'Products coming soon!',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Try different search terms or category'
                : hasAnyProducts
                    ? 'Check out the featured section above'
                    : 'Skilled persons will add products here soon. Stay tuned!',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Horizontal featured product card (Amazon "deals" style)
class _FeaturedCard extends StatelessWidget {
  final ProductModel product;
  final String shopName;
  final VoidCallback? onShopTap;
  final VoidCallback onTap;
  const _FeaturedCard({
    required this.product,
    required this.shopName,
    this.onShopTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: product.images.isNotEmpty
                      ? WebImageLoader.loadImage(
                          imageUrl: product.images.first, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[100],
                          child: const Center(
                              child: Icon(Icons.image_not_supported,
                                  color: Colors.grey))),
                ),
                if (product.rating >= 4.5)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPink,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Top Pick',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  InkWell(
                    onTap: onShopTap,
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded,
                            size: 10, color: AppTheme.primaryPurple),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.primaryPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppHelpers.formatCurrency(product.price),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryPink),
                  ),
                  if (product.reviewCount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 11, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                          style:
                              TextStyle(fontSize: 9, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
