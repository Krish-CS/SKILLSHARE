import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRequestModel {
  final String id;
  final String type;
  final String? chatId;
  final String customerId;
  final String skilledUserId;
  final String? requesterId;
  final String? requesterName;
  final String? requesterPhoto;
  final String? skilledUserName;
  final String? skilledUserPhoto;
  final String? workChatId;
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
  final String? hireType; // full_time, part_time, project_based
  /// Role of the person who sent this request: 'company', 'customer', etc.
  final String? requesterRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRequestModel({
    required this.id,
    this.type = 'service_request',
    this.chatId,
    required this.customerId,
    required this.skilledUserId,
    this.requesterId,
    this.requesterName,
    this.requesterPhoto,
    this.skilledUserName,
    this.skilledUserPhoto,
    this.workChatId,
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
    this.hireType,
    this.requesterRole,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompanyProject => requesterRole == 'company';

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
      requesterName: (map['requesterName'] as String?)?.trim(),
      requesterPhoto: (map['requesterPhoto'] as String?)?.trim(),
      skilledUserName: (map['skilledUserName'] as String?)?.trim(),
      skilledUserPhoto: (map['skilledUserPhoto'] as String?)?.trim(),
      workChatId: (map['workChatId'] as String?)?.trim(),
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
      hireType: map['hireType'],
      requesterRole: map['requesterRole'],
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
      if (requesterName != null) 'requesterName': requesterName,
      if (requesterPhoto != null) 'requesterPhoto': requesterPhoto,
      if (skilledUserName != null) 'skilledUserName': skilledUserName,
      if (skilledUserPhoto != null) 'skilledUserPhoto': skilledUserPhoto,
      if (workChatId != null) 'workChatId': workChatId,
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
      if (hireType != null) 'hireType': hireType,
      if (requesterRole != null) 'requesterRole': requesterRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
