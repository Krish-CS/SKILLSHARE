import 'package:cloud_firestore/cloud_firestore.dart';

class AppealModel {
  final String id;
  final String userId;
  final String type; // verification_rejection, account_suspension, etc.
  final String title;
  final String description;
  final List<String> attachments;
  final String status; // pending, under_review, resolved, rejected
  final String? adminResponse;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppealModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.attachments = const [],
    this.status = 'pending',
    this.adminResponse,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppealModel.fromMap(Map<String, dynamic> map, String id) {
    return AppealModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      attachments: List<String>.from(map['attachments'] ?? []),
      status: map['status'] ?? 'pending',
      adminResponse: map['adminResponse'],
      resolvedBy: map['resolvedBy'],
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'description': description,
      'attachments': attachments,
      'status': status,
      'adminResponse': adminResponse,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
