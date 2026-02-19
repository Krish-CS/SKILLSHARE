import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../utils/app_constants.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic> _normalizeParticipantDetails(
      Map<String, dynamic> details) {
    final name =
        (details['name'] ?? details['displayName'] ?? '').toString().trim();
    final photo =
        (details['photo'] ?? details['profilePhoto'] ?? details['avatar'] ?? '')
            .toString()
            .trim();
    final role = (details['role'] ?? '').toString().trim();

    return {
      'name': name.isEmpty ? 'User' : name,
      'photo': photo,
      if (role.isNotEmpty) 'role': role,
    };
  }

  bool _isTwoUserChat(
      List<String> participants, String user1Id, String user2Id) {
    return participants.length == 2 &&
        participants.contains(user1Id) &&
        participants.contains(user2Id);
  }

  Future<bool> _isUserBlockedEitherWay(
    String user1Id,
    String user2Id,
  ) async {
    try {
      final checks = await Future.wait([
        _firestore
            .collection(AppConstants.blockedUsersCollection)
            .where('blockerId', isEqualTo: user1Id)
            .where('blockedUserId', isEqualTo: user2Id)
            .limit(5)
            .get(),
        _firestore
            .collection(AppConstants.blockedUsersCollection)
            .where('blockerId', isEqualTo: user2Id)
            .where('blockedUserId', isEqualTo: user1Id)
            .limit(5)
            .get(),
      ]);

      return checks.any(
        (snapshot) =>
            snapshot.docs.any((doc) => doc.data()['isActive'] == true),
      );
    } on FirebaseException catch (e) {
      // Compatibility fallback: do not hard-block chat if old rules deny checks.
      if (e.code == 'permission-denied' || e.code == 'failed-precondition') {
        debugPrint('Blocked-user check fallback: ${e.message}');
        return false;
      }
      rethrow;
    }
  }

  Future<String> _createChatWithFallbackId({
    required String preferredChatId,
    required List<String> participants,
    required Map<String, dynamic> participantDetails,
  }) async {
    final chatData = {
      'participants': participants,
      'participantDetails': participantDetails,
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {for (final id in participants) id: 0},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final preferredRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(preferredChatId);
    try {
      await preferredRef.set(chatData, SetOptions(merge: true));
      return preferredRef.id;
    } on FirebaseException catch (e) {
      // If preferred deterministic id is not writable, create a fresh chat doc.
      if (e.code != 'permission-denied') rethrow;
      debugPrint('Preferred chat id denied, creating fallback chat doc.');
    }

    try {
      final fallbackRef = await _firestore
          .collection(AppConstants.chatsCollection)
          .add(chatData);
      return fallbackRef.id;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
          'Missing chat permissions in Firestore rules for /chats and /chats/{chatId}/messages.',
        );
      }
      rethrow;
    }
  }

  // Get or create chat between two users
  Future<String> getOrCreateChat(
    String user1Id,
    String user2Id,
    Map<String, dynamic> user1Details,
    Map<String, dynamic> user2Details,
  ) async {
    if (user1Id == user2Id) {
      throw Exception('You cannot start a chat with yourself.');
    }

    final normalizedUser1 = _normalizeParticipantDetails(user1Details);
    final normalizedUser2 = _normalizeParticipantDetails(user2Details);
    final isBlocked = await _isUserBlockedEitherWay(user1Id, user2Id);
    if (isBlocked) {
      throw Exception('Chat is unavailable due to user privacy settings.');
    }

    final sortedParticipants = [user1Id, user2Id]..sort();
    final deterministicChatId =
        '${sortedParticipants[0]}__${sortedParticipants[1]}';
    final deterministicChatRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(deterministicChatId);

    try {
      final deterministicChatDoc = await deterministicChatRef.get();
      if (deterministicChatDoc.exists) {
        await deterministicChatRef.set({
          'participants': sortedParticipants,
          'participantDetails': {
            user1Id: normalizedUser1,
            user2Id: normalizedUser2,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return deterministicChatId;
      }
    } on FirebaseException catch (e) {
      // Existing inaccessible doc should not block chat creation.
      if (e.code != 'permission-denied') rethrow;
      debugPrint('Deterministic chat read/update denied: ${e.message}');
    }

    // Check if chat already exists
    try {
      final existingChat = await _firestore
          .collection(AppConstants.chatsCollection)
          .where('participants', arrayContains: user1Id)
          .limit(100)
          .get();

      for (var doc in existingChat.docs) {
        final participants =
            List<String>.from(doc.data()['participants'] ?? const []);
        if (_isTwoUserChat(participants, user1Id, user2Id)) {
          try {
            await doc.reference.set({
              'participantDetails': {
                user1Id: normalizedUser1,
                user2Id: normalizedUser2,
              },
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } on FirebaseException catch (e) {
            if (e.code != 'permission-denied') rethrow;
            debugPrint('Existing chat update denied for ${doc.id}');
            continue;
          }
          return doc.id;
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      debugPrint('Existing chat lookup denied: ${e.message}');
    }

    return _createChatWithFallbackId(
      preferredChatId: deterministicChatId,
      participants: sortedParticipants,
      participantDetails: {
        user1Id: normalizedUser1,
        user2Id: normalizedUser2,
      },
    );
  }

  // Get user chats
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final chats = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by lastMessageTime in memory to avoid composite index
      chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      return chats;
    });
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? mediaUrl,
  }) async {
    if (senderId == receiverId) {
      throw Exception('Invalid chat users.');
    }

    final trimmedText = text.trim();
    final normalizedMediaUrl = mediaUrl?.trim();
    if (trimmedText.isEmpty &&
        (normalizedMediaUrl == null || normalizedMediaUrl.isEmpty)) {
      return;
    }

    final normalizedType =
        (normalizedMediaUrl != null && normalizedMediaUrl.isNotEmpty)
            ? 'image'
            : type;
    final messageText = normalizedType == 'image'
        ? (trimmedText.isEmpty ? 'Photo' : trimmedText)
        : trimmedText;

    final chatRef =
        _firestore.collection(AppConstants.chatsCollection).doc(chatId);
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      throw Exception('Chat not found.');
    }

    final participants =
        List<String>.from(chatDoc.data()?['participants'] ?? const []);
    if (!participants.contains(senderId) ||
        !participants.contains(receiverId)) {
      throw Exception('Invalid chat participants.');
    }

    final batch = _firestore.batch();

    // Add message
    final messageRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .doc();

    batch.set(messageRef, {
      'chatId': chatId,
      'senderId': senderId,
      'text': messageText,
      'type': normalizedType,
      'mediaUrl': normalizedMediaUrl,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat
    batch.update(chatRef, {
      'lastMessage': normalizedType == 'image' ? 'Photo' : messageText,
      'lastMessageType': normalizedType,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$receiverId': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Get messages stream
  Stream<List<MessageModel>> getMessages(String chatId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final chatRef =
        _firestore.collection(AppConstants.chatsCollection).doc(chatId);

    await chatRef.update({
      'unreadCount.$userId': 0,
    });

    // Mark messages as read - simplified query to avoid index
    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('isRead', isEqualTo: false)
        .get();

    final refsToUpdate = messages.docs
        .where((doc) => doc.data()['senderId'] != userId)
        .map((doc) => doc.reference)
        .toList();
    if (refsToUpdate.isEmpty) return;

    // Update in chunks to stay under Firestore batch limits.
    const chunkSize = 400;
    for (var i = 0; i < refsToUpdate.length; i += chunkSize) {
      final end = (i + chunkSize > refsToUpdate.length)
          ? refsToUpdate.length
          : i + chunkSize;
      final batch = _firestore.batch();
      for (final ref in refsToUpdate.sublist(i, end)) {
        batch.update(ref, {'isRead': true});
      }
      await batch.commit();
    }
  }

  // Delete chat
  Future<void> deleteChat(String chatId) async {
    // Delete all messages
    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .get();

    final batch = _firestore.batch();
    for (var doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat
    batch.delete(
        _firestore.collection(AppConstants.chatsCollection).doc(chatId));

    await batch.commit();
  }
}
