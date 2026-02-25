import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/chat_service.dart';
import '../../utils/web_image_loader.dart';
import '../../widgets/app_popup.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_detail_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ChatService _chatService = ChatService();
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  UserModel? _seller;
  List<ProductModel> _recommended = [];

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _loadRecommended();
  }

  Future<void> _loadSeller() async {
    try {
      final seller = await _firestoreService.getUserById(widget.product.userId);
      if (mounted) setState(() => _seller = seller);
    } catch (e) {
      debugPrint('Error loading seller: $e');
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
                  p.isAvailable &&
                  p.category == widget.product.category)
              .take(6)
              .toList();
          if (_recommended.isEmpty) {
            _recommended = all
                .where((p) => p.id != widget.product.id && p.isAvailable)
                .take(6)
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
      'Price: \$${widget.product.price.toStringAsFixed(2)}\n\n'
      'Check it out on SkillShare!',
      subject: widget.product.name,
    );
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
          AppPopup.show(context, message: 'Product deleted successfully', type: PopupType.success);
        }
      } catch (e) {
        if (mounted) {
          AppPopup.show(context, message: 'Error deleting product: $e', type: PopupType.error);
        }
      }
    }
  }

  Future<void> _contactSeller() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      AppPopup.show(context, message: 'Please sign in to contact the seller', type: PopupType.warning);
      return;
    }
    if (currentUser.uid == widget.product.userId) {
      AppPopup.show(context, message: 'This is your own product', type: PopupType.info);
      return;
    }
    try {
      final myUser = await _firestoreService.getUserById(currentUser.uid);
      if (myUser == null) return;
      final chatId = await _chatService.getOrCreateChat(
        currentUser.uid,
        widget.product.userId,
        {'name': myUser.name, 'photo': myUser.profilePhoto ?? ''},
        {'name': _seller?.name ?? 'Seller', 'photo': _seller?.profilePhoto ?? ''},
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
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
      AppPopup.show(context, message: 'Please sign in to add to cart', type: PopupType.warning);
      return;
    }
    if (currentUser.uid == widget.product.userId) {
      AppPopup.show(context, message: 'You cannot add your own product to cart', type: PopupType.info);
      return;
    }
    try {
      await _firestoreService.addToCart(userId: currentUser.uid, product: widget.product);
      if (!mounted) return;
      AppPopup.show(context, message: '${widget.product.name} added to cart!', type: PopupType.success);
    } catch (e) {
      if (!mounted) return;
      AppPopup.show(context, message: 'Error adding to cart: $e', type: PopupType.error);
    }
  }

  void _viewFullscreenImage(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => _FullScreenImageViewer(images: widget.product.images, initialIndex: initialIndex),
    ));
  }

  bool get _isOwner => FirebaseAuth.instance.currentUser?.uid == widget.product.userId;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final inStock = product.isAvailable && product.stock > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
        title: Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: _shareProduct),
          if (_isOwner)
            PopupMenuButton<String>(
              onSelected: (value) { if (value == 'delete') _deleteProduct(); },
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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(product),
            const SizedBox(height: 8),
            _buildMainInfoCard(product, inStock),
            const SizedBox(height: 8),
            if (_seller != null) _buildSellerCard(),
            const SizedBox(height: 8),
            _buildDescriptionCard(product),
            const SizedBox(height: 8),
            if (_recommended.isNotEmpty) _buildRecommendedSection(),
            const SizedBox(height: 12),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(inStock),
    );
  }

  Widget _buildImageGallery(ProductModel product) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _viewFullscreenImage(_currentImageIndex),
              child: Container(
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey[100],
                ),
                clipBehavior: Clip.antiAlias,
                child: product.images.isNotEmpty
                    ? Stack(
                        children: [
                          PageView.builder(
                            controller: _imagePageController,
                            onPageChanged: (i) => setState(() => _currentImageIndex = i),
                            itemCount: product.images.length,
                            itemBuilder: (_, i) => Hero(
                              tag: 'product_${product.id}_$i',
                              child: WebImageLoader.loadImage(imageUrl: product.images[i], fit: BoxFit.contain),
                            ),
                          ),
                          if (product.images.length > 1)
                            Positioned(
                              bottom: 8, left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(product.images.length, (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: _currentImageIndex == i ? 20 : 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: _currentImageIndex == i ? const Color(0xFFE91E63) : Colors.grey[400],
                                  ),
                                )),
                              ),
                            ),
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      )
                    : const Center(child: Icon(Icons.image_not_supported, size: 48, color: Colors.grey)),
              ),
            ),
          ),
          if (product.images.length > 1) ...[
            const SizedBox(width: 10),
            SizedBox(
              width: 60,
              height: 260,
              child: ListView.builder(
                itemCount: product.images.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _imagePageController.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    height: 55,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _currentImageIndex == i ? const Color(0xFFE91E63) : Colors.grey[300]!,
                        width: _currentImageIndex == i ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: WebImageLoader.loadImage(imageUrl: product.images[i], fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainInfoCard(ProductModel product, bool inStock) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3)),
          const SizedBox(height: 8),
          if (product.reviewCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ...List.generate(5, (i) => Icon(
                    i < product.rating.round() ? Icons.star : Icons.star_border,
                    color: Colors.amber, size: 16,
                  )),
                  const SizedBox(width: 6),
                  Text('${product.rating.toStringAsFixed(1)} (${product.reviewCount} reviews)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('\$${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: inStock ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(inStock ? Icons.check_circle : Icons.cancel,
                            color: inStock ? Colors.green : Colors.red, size: 14),
                        const SizedBox(width: 4),
                        Text(inStock ? 'In Stock' : 'Out of Stock',
                            style: TextStyle(color: inStock ? Colors.green[700] : Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (inStock)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${product.stock} left', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF9C27B0).withValues(alpha: 0.3)),
                ),
                child: Text(product.category,
                    style: const TextStyle(color: Color(0xFF9C27B0), fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _contactSeller,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Contact', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                    foregroundColor: const Color(0xFFE91E63),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: inStock ? _addToCart : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16, color: Colors.white),
                  label: Text(inStock ? 'Add to Cart' : 'Out of Stock',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sold by', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: _seller!.uid))),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: WebImageLoader.getImageProvider(_seller!.profilePhoto),
                  child: (_seller!.profilePhoto == null || _seller!.profilePhoto!.isEmpty)
                      ? Text(_seller!.name.isNotEmpty ? _seller!.name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 18))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_seller!.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(_seller!.role, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('View Profile', style: TextStyle(fontSize: 12, color: Color(0xFF9C27B0), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(ProductModel product) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Product Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(product.description, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.recommend_outlined, size: 18, color: Color(0xFF9C27B0)),
              const SizedBox(width: 6),
              const Text('You may also like', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(widget.product.category, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommended.length,
              itemBuilder: (_, i) => _RecommendedCard(product: _recommended[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool inStock) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _contactSeller,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(11),
                side: const BorderSide(color: Color(0xFFE91E63)),
                foregroundColor: const Color(0xFFE91E63),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                minimumSize: Size.zero,
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: inStock ? _addToCart : null,
                icon: const Icon(Icons.add_shopping_cart, size: 18, color: Colors.white),
                label: Text(inStock ? 'Add to Cart' : 'Out of Stock',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  disabledBackgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }
}

class _RecommendedCard extends StatelessWidget {
  final ProductModel product;
  const _RecommendedCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: product.images.isNotEmpty
                  ? Hero(
                      tag: 'product_${product.id}_0',
                      child: WebImageLoader.loadImage(imageUrl: product.images.first, fit: BoxFit.cover),
                    )
                  : Container(
                      color: Colors.grey[100],
                      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                  if (product.reviewCount > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(product.rating.toStringAsFixed(1),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({required this.images, required this.initialIndex});

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
              child: WebImageLoader.loadImage(imageUrl: widget.images[index], fit: BoxFit.contain),
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
