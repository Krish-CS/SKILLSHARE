import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final String productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status; // pending, confirmed, shipped, delivered, cancelled
  final String? buyerName;
  final String? buyerEmail;
  final String paymentMethod; // gpay_simulation, cod, etc.
  final String paymentStatus; // paid, pending, failed
  final String? paymentReference;
  final DateTime? paidAt;
  final String sellerTransferStatus; // credited_simulated, pending
  final DateTime? sellerTransferAt;
  final String? notes;
  final Map<String, DateTime> statusTimeline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.status = 'pending',
    this.buyerName,
    this.buyerEmail,
    this.paymentMethod = 'gpay_simulation',
    this.paymentStatus = 'paid',
    this.paymentReference,
    this.paidAt,
    this.sellerTransferStatus = 'credited_simulated',
    this.sellerTransferAt,
    this.notes,
    this.statusTimeline = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  static Map<String, DateTime> _parseTimeline(dynamic rawTimeline) {
    if (rawTimeline is! Map) return const {};
    final parsed = <String, DateTime>{};
    rawTimeline.forEach((key, value) {
      final normalizedKey = key.toString().trim();
      if (normalizedKey.isEmpty) return;
      if (value is Timestamp) {
        parsed[normalizedKey] = value.toDate();
        return;
      }
      if (value is DateTime) {
        parsed[normalizedKey] = value;
        return;
      }
      if (value is String) {
        final parsedDate = DateTime.tryParse(value);
        if (parsedDate != null) {
          parsed[normalizedKey] = parsedDate;
        }
      }
    });
    return parsed;
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productImage: map['productImage'],
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      buyerName: map['buyerName'],
      buyerEmail: map['buyerEmail'],
      paymentMethod: map['paymentMethod'] ?? 'gpay_simulation',
      paymentStatus: map['paymentStatus'] ?? 'paid',
      paymentReference: map['paymentReference'],
      paidAt: (map['paidAt'] as Timestamp?)?.toDate(),
      sellerTransferStatus: map['sellerTransferStatus'] ?? 'pending',
      sellerTransferAt: (map['sellerTransferAt'] as Timestamp?)?.toDate(),
      notes: map['notes'],
      statusTimeline: _parseTimeline(map['statusTimeline']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'status': status,
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentReference': paymentReference,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'sellerTransferStatus': sellerTransferStatus,
      'sellerTransferAt': sellerTransferAt != null
          ? Timestamp.fromDate(sellerTransferAt!)
          : null,
      'notes': notes,
      'statusTimeline': statusTimeline.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
