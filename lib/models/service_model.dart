import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final double priceMin;
  final double priceMax;
  final String priceUnit; // per session, per hour, per order, etc.
  final List<String> images;
  final String category;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.priceMin,
    required this.priceMax,
    required this.priceUnit,
    this.images = const [],
    required this.category,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceModel(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priceMin: (map['priceMin'] ?? 0).toDouble(),
      priceMax: (map['priceMax'] ?? 0).toDouble(),
      priceUnit: map['priceUnit'] ?? 'per session',
      images: List<String>.from(map['images'] ?? []),
      category: map['category'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'priceUnit': priceUnit,
      'images': images,
      'category': category,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
