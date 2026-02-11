import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/product_model.dart';
import '../utils/app_helpers.dart';
import '../utils/web_image_loader.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Get the first valid (non-empty) image URL
    final String? validImageUrl = product.images
        .where((url) => url.trim().isNotEmpty)
        .isEmpty
        ? null
        : product.images.firstWhere((url) => url.trim().isNotEmpty);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image - use Expanded to fill available space
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Colors.grey[200],
                child: validImageUrl != null
                    ? WebImageLoader.loadImage(
                        imageUrl: validImageUrl,
                        fit: BoxFit.cover,
                        placeholder: Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            // Product Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        RatingBarIndicator(
                          rating: product.rating,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star,
                            color: Colors.amber,
                          ),
                          itemCount: 5,
                          itemSize: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      AppHelpers.formatCurrency(product.price),
                      style: const TextStyle(
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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
