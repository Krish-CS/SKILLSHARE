import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantDetails; // userId -> {name, photo}
  final String lastMessage;
  final String lastMessageType; // text, image, etc.
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount; // userId -> count
  final bool isWorkChat;
  final String? workRequestId;
  final bool isJobChat;
  final String? jobId;
  final String? jobTitle;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.participantDetails,
    required this.lastMessage,
    this.lastMessageType = 'text',
    required this.lastMessageTime,
    required this.unreadCount,
    this.isWorkChat = false,
    this.workRequestId,
    this.isJobChat = false,
    this.jobId,
    this.jobTitle,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      participantDetails:
          Map<String, dynamic>.from(map['participantDetails'] ?? {}),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageType: map['lastMessageType'] ?? 'text',
      lastMessageTime:
          (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      isWorkChat: map['isWorkChat'] == true,
      workRequestId: (map['workRequestId'] as String?)?.trim(),
      isJobChat: map['isJobChat'] == true,
      jobId: (map['jobId'] as String?)?.trim(),
      jobTitle: (map['jobTitle'] as String?)?.trim(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCount': unreadCount,
      'isWorkChat': isWorkChat,
      if (workRequestId != null && workRequestId!.isNotEmpty)
        'workRequestId': workRequestId,
      'isJobChat': isJobChat,
      if (jobId != null && jobId!.isNotEmpty) 'jobId': jobId,
      if (jobTitle != null && jobTitle!.isNotEmpty) 'jobTitle': jobTitle,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String type; // text, image, video
  final String? mediaUrl;
  final String? attachmentName;
  final bool isRead;
  final DateTime? readAt;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    this.type = 'text',
    this.mediaUrl,
    this.attachmentName,
    this.isRead = false,
    this.readAt,
    this.isDeleted = false,
    this.editedAt,
    required this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      mediaUrl: map['mediaUrl'],
      attachmentName: (map['attachmentName'] as String?)?.trim(),
      isRead: map['isRead'] ?? false,
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      isDeleted: map['isDeleted'] ?? false,
      editedAt: (map['editedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      if (attachmentName != null && attachmentName!.isNotEmpty)
        'attachmentName': attachmentName,
      'isRead': isRead,
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      'isDeleted': isDeleted,
      if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
