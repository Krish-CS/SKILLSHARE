import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_helpers.dart';
import '../../utils/web_image_loader.dart';
import '../../widgets/universal_avatar.dart';
import '../../widgets/app_popup.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../../widgets/gpay_simulation_dialog.dart';
import 'shop_storefront_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  UserModel? _seller;
  String _shopName = 'Shop';
  List<ProductModel> _sellerProducts = [];
  List<ProductModel> _recommended = [];
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadSellerProducts();
    _loadRecommended();
  }

  Future<void> _loadSeller() async {
    try {
      final results = await Future.wait([
        _firestoreService.getUserById(widget.product.userId),
        _firestoreService.getShopSettings(widget.product.userId),
      ]);
      final seller = results[0] as UserModel?;
      final shopSettings = results[1] as Map<String, dynamic>;
      final configuredShopName = (shopSettings['shopName'] as String?)?.trim();
      final resolvedShopName =
          (configuredShopName != null && configuredShopName.isNotEmpty)
              ? configuredShopName
              : ((seller?.name.trim().isNotEmpty == true)
                  ? '${seller!.name.trim()} Shop'
                  : 'Shop');
      if (mounted) {
        setState(() {
          _seller = seller;
          _shopName = resolvedShopName;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller: $e');
    }
  }

  Future<void> _openSellerShop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopStorefrontScreen(
          sellerId: widget.product.userId,
          initialShopName: _shopName,
        ),
      ),
    );
  }

  Future<void> _loadSellerProducts() async {
    try {
      final all = await _firestoreService.getAllProducts(limit: 30);
      if (mounted) {
        setState(() {
          _sellerProducts = all
              .where((p) =>
                  p.userId == widget.product.userId &&
                  p.id != widget.product.id &&
                  p.isAvailable)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading seller products: $e');
    }
  }

  Future<void> _loadRecommended() async {
    try {
      final all = await _firestoreService.getAllProducts(limit: 20);
      if (mounted) {
        setState(() {
          _recommended = all
              .where((p) =>
                  p.id != widget.product.id &&
                  p.userId != widget.product.userId &&
                  p.isAvailable &&
                  p.category == widget.product.category)
              .take(8)
              .toList();
          if (_recommended.isEmpty) {
            _recommended = all
                .where((p) =>
                    p.id != widget.product.id &&
                    p.userId != widget.product.userId &&
                    p.isAvailable)
                .take(8)
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading recommended: $e');
    }
  }

  Future<void> _shareProduct() async {
    await Share.share(
      '${widget.product.name}\n\n'
      '${widget.product.description}\n\n'
      'Price: ${AppHelpers.formatCurrency(widget.product.price)}\n\n'
      'Check it out on SkillShare!',
      subject: widget.product.name,
    );
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _firestoreService.deleteProduct(widget.product.id);
        if (mounted) {
          Navigator.pop(context, true);
          AppPopup.show(context,
              message: 'Product deleted successfully', type: PopupType.success);
        }
      } catch (e) {
        if (mounted) {
          AppPopup.show(context,
              message: 'Error deleting product: $e', type: PopupType.error);
        }
      }
    }
  }

  Future<void> _contactSeller() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppPopup.show(context,
          message: 'Please sign in to contact the seller',
          type: PopupType.warning);
      return;
    }
    if (currentUser.uid == widget.product.userId) {
      AppPopup.show(context,
          message: 'This is your own product', type: PopupType.info);
      return;
    }
    try {
      final myUser = await _firestoreService.getUserById(currentUser.uid);
      if (myUser == null) return;
      final chatId = await _chatService.getOrCreateChat(
        currentUser.uid,
        widget.product.userId,
        {'name': myUser.name, 'photo': myUser.profilePhoto ?? ''},
        {
          'name': _seller?.name ?? 'Seller',
          'photo': _seller?.profilePhoto ?? ''
        },
      );
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chatId: chatId,
              otherUserId: widget.product.userId,
              otherUserName: _seller?.name ?? 'Seller',
              otherUserPhoto: _seller?.profilePhoto,
            ),
          ));
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(context, message: 'Error: $e', type: PopupType.error);
    }
  }

  Future<void> _addToCart() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppPopup.show(context,
          message: 'Please sign in to add to cart', type: PopupType.warning);
      return;
    }
    if (currentUser.uid == widget.product.userId) {
      AppPopup.show(context,
          message: 'You cannot add your own product to cart',
          type: PopupType.info);
      return;
    }
    try {
      for (int i = 0; i < _qty; i++) {
        await _firestoreService.addToCart(
            userId: currentUser.uid, product: widget.product);
      }
      if (!mounted) return;
      AppPopup.show(context,
          message:
              '${widget.product.name}${_qty > 1 ? ' x$_qty' : ''} added to cart!',
          type: PopupType.success);
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(context,
          message: 'Error adding to cart: $e', type: PopupType.error);
    }
  }

  Future<void> _buyNow() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppPopup.show(context,
          message: 'Please sign in to purchase', type: PopupType.warning);
      return;
    }
    if (currentUser.uid == widget.product.userId) {
      AppPopup.show(context,
          message: 'You cannot buy your own product', type: PopupType.info);
      return;
    }
    final transactionId = await GPaySimulationDialog.show(
      context,
      amount: widget.product.price * _qty,
      recipientName: _seller?.name ?? 'Seller',
      description: '${widget.product.name}${_qty > 1 ? ' x$_qty' : ''}',
    );
    if (transactionId != null && mounted) {
      try {
        for (int i = 0; i < _qty; i++) {
          await _firestoreService.addToCart(
              userId: currentUser.uid, product: widget.product);
        }
        if (!mounted) return;
        AppPopup.show(
          context,
          message: 'Payment successful! Order placed.\nRef: $transactionId',
          type: PopupType.success,
        );
      } catch (e) {
        if (!mounted) return;
        AppPopup.show(context,
            message: 'Error placing order: $e', type: PopupType.error);
      }
    }
  }

  void _viewFullscreenImage(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _FullScreenImageViewer(
          images: widget.product.images, initialIndex: initialIndex),
    ));
  }

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == widget.product.userId;

  // ─── BUILD ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inStock = product.isAvailable && product.stock > 0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildAppBar(product),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Main product section: image + info/actions ──
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Product Image
                        Expanded(flex: 5, child: _buildImageSection(product)),
                        const SizedBox(width: 24),
                        // Right: Info + Actions
                        Expanded(
                            flex: 4,
                            child: _buildInfoAndActions(product, inStock)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildImageSection(product),
                        const SizedBox(height: 16),
                        _buildInfoAndActions(product, inStock),
                      ],
                    ),
            ),

            const SizedBox(height: 8),

            // ── Seller section ──
            if (_seller != null) _buildSellerCard(),

            const SizedBox(height: 8),

            // ── Description ──
            _buildDescriptionCard(product),

            // ── Seller's Other Products (grid) ──
            if (_sellerProducts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSellerProductsGrid(),
            ],

            // ── Recommended Products (grid) ──
            if (_recommended.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildRecommendedGrid(),
            ],

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─── APP BAR ────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(ProductModel product) {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryPurple, AppTheme.primaryPink],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: _shareProduct),
        if (_isOwner)
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'delete') _deleteProduct();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Product', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
      ],
    );
  }

  // ─── IMAGE SECTION ──────────────────────────────────────────────────────
  Widget _buildImageSection(ProductModel product) {
    return Column(
      children: [
        // Main image viewer
        GestureDetector(
          onTap: () => _viewFullscreenImage(_currentImageIndex),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: product.images.isNotEmpty
                ? Stack(
                    children: [
                      PageView.builder(
                        controller: _imagePageController,
                        onPageChanged: (i) =>
                            setState(() => _currentImageIndex = i),
                        itemCount: product.images.length,
                        itemBuilder: (_, i) => Hero(
                          tag: 'product_${product.id}_$i',
                          child: WebImageLoader.loadImage(
                              imageUrl: product.images[i], fit: BoxFit.contain),
                        ),
                      ),
                      // Page dots
                      if (product.images.length > 1)
                        Positioned(
                          bottom: 10,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              product.images.length,
                              (i) => AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: _currentImageIndex == i ? 22 : 8,
                                height: 8,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: _currentImageIndex == i
                                      ? AppTheme.primaryPink
                                      : Colors.grey[400],
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Zoom icon
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.zoom_in,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Icon(Icons.image_not_supported,
                        size: 48, color: Colors.grey)),
          ),
        ),
        // Thumbnail strip
        if (product.images.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: product.images.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _imagePageController.animateToPage(i,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut),
                child: Container(
                  width: 56,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _currentImageIndex == i
                          ? AppTheme.primaryPink
                          : Colors.grey.shade300,
                      width: _currentImageIndex == i ? 2.5 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: WebImageLoader.loadImage(
                      imageUrl: product.images[i], fit: BoxFit.cover),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── INFO + ACTION BUTTONS (right side on wide, below on mobile) ──────
  Widget _buildInfoAndActions(ProductModel product, bool inStock) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        Text(product.name,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                height: 1.3)),
        const SizedBox(height: 8),

        // Rating row
        if (product.reviewCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ...List.generate(
                  5,
                  (i) => Icon(
                    i < product.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  product.rating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${product.reviewCount} review${product.reviewCount != 1 ? 's' : ''})',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

        // Price
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              AppHelpers.formatCurrency(product.price),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryPink,
              ),
            ),
            if (_qty > 1) ...[
              const SizedBox(width: 8),
              Text(
                'Total: ${AppHelpers.formatCurrency(product.price * _qty)}',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Stock status
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: inStock
                    ? AppTheme.accentGreen.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(inStock ? Icons.check_circle : Icons.cancel,
                      color: inStock ? AppTheme.accentGreen : Colors.red,
                      size: 14),
                  const SizedBox(width: 4),
                  Text(
                    inStock ? 'In Stock' : 'Out of Stock',
                    style: TextStyle(
                        color: inStock ? Colors.green[700] : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (inStock && product.stock <= 10) ...[
              const SizedBox(width: 8),
              Text('${product.stock} left',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          product.stock <= 3 ? Colors.red : Colors.grey[600])),
            ],
          ],
        ),
        const SizedBox(height: 6),

        // Category chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
          ),
          child: Text(product.category,
              style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),

        const SizedBox(height: 16),

        // ── Quantity selector ──
        if (!_isOwner && inStock) ...[
          Row(
            children: [
              const Text('Qty:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 10),
              _buildQtyButton(Icons.remove, () {
                if (_qty > 1) setState(() => _qty--);
              }),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text('$_qty',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _buildQtyButton(Icons.add, () {
                if (_qty < product.stock) setState(() => _qty++);
              }),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Action Buttons ──
        if (!_isOwner) ...[
          // Add to Cart
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: inStock ? _addToCart : null,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: Text(
                inStock ? 'Add to Cart' : 'Out of Stock',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Buy Now (GPay)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: inStock ? _buyNow : null,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text(
                'Buy Now',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Chat with Seller
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: _contactSeller,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
              label: const Text('Chat with Seller',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryPurple,
                side: BorderSide(
                    color: AppTheme.primaryPurple.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, size: 16, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  // ─── SELLER CARD ────────────────────────────────────────────────────────
  Widget _buildSellerCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sold by',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded,
                        size: 14, color: AppTheme.primaryPurple),
                    const SizedBox(width: 4),
                    Text(
                      _shopName,
                      style: const TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _openSellerShop,
                icon: const Icon(Icons.store_mall_directory, size: 16),
                label: const Text('Visit Shop'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: _seller!.uid))),
            child: Row(
              children: [
                UniversalAvatar(
                  avatarConfig: _seller!.avatarConfig,
                  photoUrl: _seller!.profilePhoto,
                  fallbackName: _seller!.name,
                  radius: 22,
                  animate: false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_seller!.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(_seller!.role,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      AppTheme.primaryPurple,
                      AppTheme.primaryPink,
                    ]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('View Profile',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── DESCRIPTION ────────────────────────────────────────────────────────
  Widget _buildDescriptionCard(ProductModel product) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('Product Details',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(product.description,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[700], height: 1.6)),
        ],
      ),
    );
  }

  // ─── SELLER'S OTHER PRODUCTS (GRID) ─────────────────────────────────────
  Widget _buildSellerProductsGrid() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: AppTheme.primaryOrange,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'More from ${_shopName.isNotEmpty ? _shopName : (_seller?.name ?? 'this seller')}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: _sellerProducts.length > 6 ? 6 : _sellerProducts.length,
            itemBuilder: (_, i) =>
                _ProductGridCard(product: _sellerProducts[i]),
          ),
        ],
      ),
    );
  }

  // ─── RECOMMENDED PRODUCTS (GRID) ────────────────────────────────────────
  Widget _buildRecommendedGrid() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                    color: AppTheme.primaryBlue,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              const Text('You may also like',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: _recommended.length,
            itemBuilder: (_, i) => _ProductGridCard(product: _recommended[i]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }
}

// ─── PRODUCT GRID CARD (styled for the product detail page grids) ──────────
class _ProductGridCard extends StatelessWidget {
  final ProductModel product;
  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final validImage =
        product.images.where((url) => url.trim().isNotEmpty).toList();
    final bool inStock = product.isAvailable && product.stock > 0;

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  validImage.isNotEmpty
                      ? WebImageLoader.loadImage(
                          imageUrl: validImage.first,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.grey[50],
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryPink)),
                          ),
                          errorWidget: Container(
                            color: Colors.grey[50],
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey, size: 32),
                          ),
                        )
                      : Container(
                          color: Colors.grey[50],
                          child: const Icon(Icons.shopping_bag_outlined,
                              size: 36, color: Colors.grey),
                        ),
                  // Out of stock overlay
                  if (!inStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: const Center(
                        child: Text('Out of Stock',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.3)),
                    const SizedBox(height: 4),
                    if (product.reviewCount > 0)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < product.rating.round()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: Colors.amber,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text('(${product.reviewCount})',
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey[500])),
                        ],
                      ),
                    const Spacer(),
                    Text(
                      AppHelpers.formatCurrency(product.price),
                      style: const TextStyle(
                        color: AppTheme.primaryPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULLSCREEN IMAGE VIEWER ──────────────────────────────────────────────
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${_currentIndex + 1} / ${widget.images.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: widget.images.length,
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Hero(
              tag: 'product_fullscreen_$index',
              child: WebImageLoader.loadImage(
                  imageUrl: widget.images[index], fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
