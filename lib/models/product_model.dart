import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String userId;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final String category;
  final int stock;
  final bool isAvailable;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.price,
    this.images = const [],
    required this.category,
    this.stock = 0,
    this.isAvailable = true,
    this.rating = 0.0,
    this.reviewCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    String normalizeId(dynamic value) => value?.toString().trim() ?? '';
    final userId = normalizeId(map['userId']);
    final sellerId = normalizeId(map['sellerId']);
    final ownerId = normalizeId(map['ownerId']);
    final uid = normalizeId(map['uid']);
    final resolvedUserId = userId.isNotEmpty
        ? userId
        : sellerId.isNotEmpty
            ? sellerId
            : ownerId.isNotEmpty
                ? ownerId
                : uid;

    return ProductModel(
      id: id,
      userId: resolvedUserId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      images: List<String>.from(map['images'] ?? []),
      category: map['category'] ?? '',
      stock: map['stock'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'category': category,
      'stock': stock,
      'isAvailable': isAvailable,
      'rating': rating,
      'reviewCount': reviewCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
