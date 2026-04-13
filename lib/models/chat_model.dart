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
  final String? chatCategory;
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
    this.chatCategory,
    required this.createdAt,
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    List<String> parseParticipants(dynamic value) {
      if (value is! Iterable) return const <String>[];
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }

    Map<String, dynamic> parseParticipantDetails(dynamic value) {
      if (value is! Map) return <String, dynamic>{};
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) return;
        if (val is Map) {
          result[normalizedKey] = Map<String, dynamic>.from(val);
        } else {
          result[normalizedKey] = val;
        }
      });
      return result;
    }

    Map<String, int> parseUnreadCount(dynamic value) {
      if (value is! Map) return <String, int>{};
      final result = <String, int>{};
      value.forEach((key, val) {
        final normalizedKey = key.toString().trim();
        if (normalizedKey.isEmpty) return;
        if (val is num) {
          result[normalizedKey] = val.toInt();
          return;
        }
        final parsed = int.tryParse(val?.toString() ?? '');
        result[normalizedKey] = parsed ?? 0;
      });
      return result;
    }

    return ChatModel(
      id: id,
      participants: parseParticipants(map['participants']),
      participantDetails: parseParticipantDetails(map['participantDetails']),
      lastMessage: (map['lastMessage'] ?? '').toString(),
      lastMessageType: (map['lastMessageType'] ?? 'text').toString(),
      lastMessageTime: parseDate(map['lastMessageTime']),
      unreadCount: parseUnreadCount(map['unreadCount']),
      isWorkChat: map['isWorkChat'] == true,
      workRequestId: (map['workRequestId'] as String?)?.trim(),
      isJobChat: map['isJobChat'] == true,
      jobId: (map['jobId'] as String?)?.trim(),
      jobTitle: (map['jobTitle'] as String?)?.trim(),
      chatCategory: (map['chatCategory'] as String?)?.trim(),
      createdAt: parseDate(map['createdAt']),
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
      if (chatCategory != null && chatCategory!.isNotEmpty)
        'chatCategory': chatCategory,
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
    DateTime parseRequiredDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseOptionalDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return MessageModel(
      id: id,
      chatId: (map['chatId'] ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
      type: (map['type'] ?? 'text').toString(),
      mediaUrl: (map['mediaUrl'] as String?)?.trim(),
      attachmentName: (map['attachmentName'] as String?)?.trim(),
      isRead: map['isRead'] ?? false,
      readAt: parseOptionalDate(map['readAt']),
      isDeleted: map['isDeleted'] ?? false,
      editedAt: parseOptionalDate(map['editedAt']),
      createdAt: parseRequiredDate(map['createdAt']),
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
