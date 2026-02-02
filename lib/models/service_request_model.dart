import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String customerId;
  final String skilledUserId;
  final String serviceId;
  final String title;
  final String description;
  final List<String> images;
  final String status; // pending, accepted, rejected, completed
  final DateTime? scheduledDate;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRequestModel({
    required this.id,
    required this.customerId,
    required this.skilledUserId,
    required this.serviceId,
    required this.title,
    required this.description,
    this.images = const [],
    this.status = 'pending',
    this.scheduledDate,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map, String id) {
    return ServiceRequestModel(
      id: id,
      customerId: map['customerId'] ?? '',
      skilledUserId: map['skilledUserId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'pending',
      scheduledDate: (map['scheduledDate'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'skilledUserId': skilledUserId,
      'serviceId': serviceId,
      'title': title,
      'description': description,
      'images': images,
      'status': status,
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
