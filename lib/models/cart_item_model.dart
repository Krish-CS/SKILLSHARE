import 'package:cloud_firestore/cloud_firestore.dart';

class CartItemModel {
  final String id;
  final String userId;
  final String productId;
  final String sellerId;
  final String productName;
  final String? productImage;
  final double price;
  final int quantity;
  final int availableStock;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CartItemModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.sellerId,
    required this.productName,
    this.productImage,
    required this.price,
    required this.quantity,
    required this.availableStock,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalPrice => price * quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map, String id) {
    return CartItemModel(
      id: id,
      userId: map['userId'] ?? '',
      productId: map['productId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'],
      price: (map['price'] ?? 0).toDouble(),
      quantity: map['quantity'] ?? 1,
      availableStock: map['availableStock'] ?? 0,
      isAvailable: map['isAvailable'] ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productId': productId,
      'sellerId': sellerId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'availableStock': availableStock,
      'isAvailable': isAvailable,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CartItemModel copyWith({
    int? quantity,
    int? availableStock,
    bool? isAvailable,
    DateTime? updatedAt,
  }) {
    return CartItemModel(
      id: id,
      userId: userId,
      productId: productId,
      sellerId: sellerId,
      productName: productName,
      productImage: productImage,
      price: price,
      quantity: quantity ?? this.quantity,
      availableStock: availableStock ?? this.availableStock,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
