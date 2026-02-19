import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String type;
  final String? chatId;
  final String customerId;
  final String skilledUserId;
  final String? requesterId;
  final List<String> participants;
  final String serviceId;
  final String title;
  final String description;
  final List<String> images;
  final String status; // pending, accepted, rejected, completed
  final DateTime? scheduledDate;
  final String? rejectionReason;
  final String? responseMessage;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRequestModel({
    required this.id,
    this.type = 'service_request',
    this.chatId,
    required this.customerId,
    required this.skilledUserId,
    this.requesterId,
    this.participants = const [],
    required this.serviceId,
    required this.title,
    required this.description,
    this.images = const [],
    this.status = 'pending',
    this.scheduledDate,
    this.rejectionReason,
    this.responseMessage,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ServiceRequestModel.fromMap(Map<String, dynamic> map, String id) {
    final customerId =
        (map['customerId'] ?? map['requesterId'] ?? '').toString().trim();
    final requesterId =
        (map['requesterId'] ?? map['customerId'] ?? '').toString().trim();
    final skilledUserId = (map['skilledUserId'] ?? '').toString().trim();
    final participants = (map['participants'] is List)
        ? List<String>.from(map['participants'])
        : <String>[
            if (customerId.isNotEmpty) customerId,
            if (skilledUserId.isNotEmpty) skilledUserId,
          ];

    return ServiceRequestModel(
      id: id,
      type: map['type'] ?? 'service_request',
      chatId: map['chatId'],
      customerId: customerId,
      skilledUserId: skilledUserId,
      requesterId: requesterId,
      participants: participants,
      serviceId: map['serviceId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      status: map['status'] ?? 'pending',
      scheduledDate: (map['scheduledDate'] as Timestamp?)?.toDate(),
      rejectionReason: map['rejectionReason'],
      responseMessage: map['responseMessage'],
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'chatId': chatId,
      'customerId': customerId,
      'requesterId': requesterId ?? customerId,
      'skilledUserId': skilledUserId,
      'participants':
          participants.isNotEmpty ? participants : [customerId, skilledUserId],
      'serviceId': serviceId,
      'title': title,
      'description': description,
      'images': images,
      'status': status,
      'scheduledDate':
          scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'rejectionReason': rejectionReason,
      'responseMessage': responseMessage,
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
