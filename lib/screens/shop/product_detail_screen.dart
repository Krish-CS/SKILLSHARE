import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/web_image_loader.dart';
import '../profile/profile_screen.dart';

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
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;
  UserModel? _seller;

  @override
  void initState() {
    super.initState();
    _loadSeller();
  }

  Future<void> _loadSeller() async {
    try {
      final seller = await _firestoreService.getUserById(widget.product.userId);
      if (mounted) {
        setState(() {
          _seller = seller;
        });
      }
    } catch (e) {
      debugPrint('Error loading seller: $e');
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
          Navigator.pop(context, true); // Signal that product was deleted
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting product: $e')),
          );
        }
      }
    }
  }

  void _viewFullscreenImage(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          images: widget.product.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  bool get _isOwner {
    return FirebaseAuth.instance.currentUser?.uid == widget.product.userId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Images
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: widget.product.images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          controller: _imagePageController,
                          onPageChanged: (index) {
                            setState(() => _currentImageIndex = index);
                          },
                          itemCount: widget.product.images.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _viewFullscreenImage(index),
                              child: Hero(
                                tag: 'product_${widget.product.id}_$index',
                                child: WebImageLoader.loadImage(
                                  imageUrl: widget.product.images[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                        // Image indicator
                        if (widget.product.images.length > 1)
                          Positioned(
                            bottom: 16,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                widget.product.images.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentImageIndex == index
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, size: 64),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _shareProduct,
              ),
              if (_isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteProduct();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Product', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${widget.product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE91E63),
                                ),
                              ),
                              if (widget.product.stock > 0)
                                Text(
                                  '${widget.product.stock} in stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category and Rating
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE91E63).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.product.category,
                              style: const TextStyle(
                                color: Color(0xFFE91E63),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.product.reviewCount > 0) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.product.rating.toStringAsFixed(1)} (${widget.product.reviewCount})',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Availability
                      Row(
                        children: [
                          Icon(
                            widget.product.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: widget.product.isAvailable
                                ? Colors.green
                                : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.product.isAvailable
                                ? 'Available'
                                : 'Out of Stock',
                            style: TextStyle(
                              color: widget.product.isAvailable
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Description
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Seller Info
                if (_seller != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seller',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ProfileScreen(userId: _seller!.uid),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: WebImageLoader.getImageProvider(_seller!.profilePhoto),
                                child: _seller!.profilePhoto == null || _seller!.profilePhoto!.isEmpty
                                    ? Text(
                                        _seller!.name.isNotEmpty ? _seller!.name[0].toUpperCase() : 'S',
                                        style: const TextStyle(fontSize: 24),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _seller!.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _seller!.role,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_seller!.email.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.email,
                                            color: Colors.grey,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _seller!.email,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),

      // Bottom Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Contact Seller
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chat feature coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE91E63)),
                    foregroundColor: const Color(0xFFE91E63),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Add to Cart / Buy Now
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: widget.product.isAvailable && widget.product.stock > 0
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Add to cart feature coming soon!'),
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: Text(
                    widget.product.isAvailable && widget.product.stock > 0
                        ? 'Add to Cart'
                        : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
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

// Fullscreen Image Viewer
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

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
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'product_fullscreen_$index',
                child: WebImageLoader.loadImage(
                  imageUrl: widget.images[index],
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
