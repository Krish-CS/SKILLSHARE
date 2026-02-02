import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../utils/app_constants.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create chat between two users
  Future<String> getOrCreateChat(String user1Id, String user2Id, Map<String, dynamic> user1Details, Map<String, dynamic> user2Details) async {
    // Check if chat already exists
    final existingChat = await _firestore
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: user1Id)
        .get();

    for (var doc in existingChat.docs) {
      final participants = List<String>.from(doc.data()['participants']);
      if (participants.contains(user2Id)) {
        return doc.id;
      }
    }

    // Create new chat
    final chatData = {
      'participants': [user1Id, user2Id],
      'participantDetails': {
        user1Id: user1Details,
        user2Id: user2Details,
      },
      'lastMessage': '',
      'lastMessageType': 'text',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {user1Id: 0, user2Id: 0},
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await _firestore
        .collection(AppConstants.chatsCollection)
        .add(chatData);

    return docRef.id;
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
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update chat
    final chatRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId);

    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageType': type,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount.$receiverId': FieldValue.increment(1),
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
    final batch = _firestore.batch();

    // Update unread count
    final chatRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId);

    batch.update(chatRef, {
      'unreadCount.$userId': 0,
    });

    // Mark messages as read - simplified query to avoid index
    final messages = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .collection(AppConstants.messagesCollection)
        .where('isRead', isEqualTo: false)
        .get();

    // Filter in memory to avoid composite index
    for (var doc in messages.docs) {
      if (doc.data()['senderId'] != userId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }

    await batch.commit();
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
    batch.delete(_firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId));

    await batch.commit();
  }
}
