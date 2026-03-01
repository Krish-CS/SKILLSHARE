import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/skilled_user_profile.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/product_card.dart';
import '../../widgets/universal_avatar.dart';
import '../profile/profile_screen.dart';
import 'product_detail_screen.dart';

class ShopStorefrontScreen extends StatefulWidget {
  const ShopStorefrontScreen({
    super.key,
    required this.sellerId,
    this.initialShopName,
  });

  final String sellerId;
  final String? initialShopName;

  @override
  State<ShopStorefrontScreen> createState() => _ShopStorefrontScreenState();
}

class _ShopStorefrontScreenState extends State<ShopStorefrontScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  String? _error;
  UserModel? _seller;
  SkilledUserProfile? _profile;
  List<ProductModel> _products = [];
  String _shopName = 'Shop';

  @override
  void initState() {
    super.initState();
    _shopName = widget.initialShopName?.trim().isNotEmpty == true
        ? widget.initialShopName!.trim()
        : 'Shop';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final isVerified =
          await _firestoreService.isSkilledUserAadhaarVerified(widget.sellerId);
      if (!isVerified) {
        setState(() {
          _error = 'This shop is not publicly available.';
          _isLoading = false;
        });
        return;
      }

      final results = await Future.wait([
        _firestoreService.getUserById(widget.sellerId),
        _firestoreService.getSkilledUserProfile(widget.sellerId),
        _firestoreService.getShopSettings(widget.sellerId),
        _firestoreService.getUserProducts(widget.sellerId),
      ]);

      final seller = results[0] as UserModel?;
      final profile = results[1] as SkilledUserProfile?;
      final shopSettings = results[2] as Map<String, dynamic>;
      final allProducts = results[3] as List<ProductModel>;

      final configuredShopName = (shopSettings['shopName'] as String?)?.trim();
      final resolvedShopName =
          (configuredShopName != null && configuredShopName.isNotEmpty)
              ? configuredShopName
              : ((seller?.name.trim().isNotEmpty == true)
                  ? '${seller!.name.trim()} Shop'
                  : 'Shop');

      setState(() {
        _seller = seller;
        _profile = profile;
        _products = allProducts.where((p) => p.isAvailable).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _shopName = resolvedShopName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load shop: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openProduct(ProductModel product) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(_shopName, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryPurple, AppTheme.primaryPink],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _buildShopHeader(),
                      const SizedBox(height: 12),
                      Text(
                        '${_products.length} product${_products.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_products.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              const Text('No products available in this shop.'),
                        )
                      else
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.50,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final product = _products[index];
                            return ProductCard(
                              product: product,
                              onTap: () => _openProduct(product),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildShopHeader() {
    final sellerName = (_seller?.name.trim().isNotEmpty == true)
        ? _seller!.name.trim()
        : 'Skilled Person';
    final bio = (_profile?.bio ?? '').trim();
    final skills = _profile?.skills ?? const <String>[];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UniversalAvatar(
                avatarConfig: _seller?.avatarConfig,
                photoUrl: _seller?.profilePhoto,
                fallbackName: sellerName,
                radius: 24,
                animate: false,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'By $sellerName',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _seller == null
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: _seller!.uid),
                          ),
                        ),
                icon: const Icon(Icons.person, size: 16),
                label: const Text('View Profile'),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ],
          if (skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills
                  .take(6)
                  .map(
                    (skill) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
