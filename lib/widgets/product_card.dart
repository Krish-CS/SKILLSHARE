import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../utils/app_theme.dart';
import '../utils/app_helpers.dart';
import '../utils/web_image_loader.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final String? validImageUrl = product.images
            .where((url) => url.trim().isNotEmpty)
            .isEmpty
        ? null
        : product.images.firstWhere((url) => url.trim().isNotEmpty);

    final bool inStock = product.isAvailable && product.stock > 0;
    final bool isTopRated = product.rating >= 4.5 && product.reviewCount > 0;
    final bool isBestSeller = product.reviewCount >= 10;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product Image ──
            Expanded(
              flex: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  validImageUrl != null
                      ? WebImageLoader.loadImage(
                          imageUrl: validImageUrl,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryPink,
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey, size: 36),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFF5F5F5),
                          child: const Icon(Icons.shopping_bag_outlined,
                              size: 40, color: Colors.grey),
                        ),

                  // Badge (Best Seller / Top Rated)
                  if (isBestSeller || isTopRated)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isBestSeller
                              ? AppTheme.primaryPurple
                              : AppTheme.primaryOrange,
                          borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(8)),
                        ),
                        child: Text(
                          isBestSeller ? 'Best Seller' : 'Top Rated',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),

                  // Out of stock overlay
                  if (!inStock)
                    Container(
                      color: Colors.black.withValues(alpha: 0.38),
                      child: const Center(
                        child: Text(
                          'Out of\nStock',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Info section ──
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Rating row
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
                          Text(
                            '(${product.reviewCount})',
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary),
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 3),

                    const Spacer(),

                    // Price
                    Text(
                      AppHelpers.formatCurrency(product.price),
                      style: const TextStyle(
                        color: AppTheme.primaryPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Stock indicator
                    if (inStock && product.stock <= 5)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          'Only ${product.stock} left',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryPink,
                              fontWeight: FontWeight.w500),
                        ),
                      ),

                    // Add to Cart button
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton(
                        onPressed: inStock ? onTap : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          disabledBackgroundColor: Colors.grey[300],
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        child: Text(
                          inStock ? 'View' : 'Out of Stock',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
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
