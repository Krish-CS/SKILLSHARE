import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/chat_model.dart';
import '../../services/chat_service.dart';
import '../../services/presence_service.dart';
import '../../utils/app_helpers.dart';
import '../../utils/app_constants.dart';
import '../../widgets/universal_avatar.dart';
import 'chat_detail_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _currentUserId;
  Stream<List<ChatModel>>? _chatsStream;

  /// Map of chatId → number of pending work requests for that chat.
  /// Updated via a real subscription so amber badges are always in sync.
  Map<String, int> _pendingWorkCounts = {};
  StreamSubscription<QuerySnapshot>? _workReqSub;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _chatsStream = _chatService.getUserChats(_currentUserId!);

      // Listen to pending work requests for this user and keep the count map
      // updated via setState so every rebuild of the chat list uses fresh data.
      _workReqSub = FirebaseFirestore.instance
          .collection(AppConstants.requestsCollection)
          .where('participants', arrayContains: _currentUserId)
          .snapshots()
          .listen((snap) {
        final newCounts = <String, int>{};
        for (final doc in snap.docs) {
          final d = doc.data();
          final type = (d['type'] as String?) ?? '';
          final serviceId = (d['serviceId'] as String?) ?? '';
          final status = (d['status'] as String?) ?? '';
          final chatId = (d['chatId'] as String?) ?? '';
          if ((type == 'chat_work_request' || serviceId == 'direct_hire') &&
              status == AppConstants.requestStatusPending &&
              chatId.isNotEmpty) {
            newCounts[chatId] = (newCounts[chatId] ?? 0) + 1;
          }
        }
        if (mounted) setState(() => _pendingWorkCounts = newCounts);
      });
    }
  }

  @override
  void dispose() {
    _workReqSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Chats', style: TextStyle(color: Colors.white)),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: const Center(
          child: Text('Please sign in to view chats'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats', style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9C27B0), Color(0xFFE91E63)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Chats List
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                List<ChatModel> chats = snapshot.data!;

                // Filter chats based on search
                if (_searchQuery.isNotEmpty) {
                  chats = chats.where((chat) {
                    final otherUserId = chat.participants.firstWhere(
                      (id) => id != _currentUserId,
                      orElse: () => '',
                    );
                    final otherUserDetails =
                        chat.participantDetails[otherUserId];
                    final name =
                        otherUserDetails?['name']?.toString().toLowerCase() ??
                            '';
                    final lastMessage = chat.lastMessage.toLowerCase();

                    return name.contains(_searchQuery) ||
                        lastMessage.contains(_searchQuery);
                  }).toList();
                }

                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No chats found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    return _buildChatItem(chats[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(ChatModel chat) {
    final otherUserId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => '',
    );
    final otherUserDetails = chat.participantDetails[otherUserId];
    final name = otherUserDetails?['name'] ?? 'Unknown';
    final photo = otherUserDetails?['photo'];
    final unreadCount = chat.unreadCount[_currentUserId] ?? 0;
    final pendingWork = _pendingWorkCounts[chat.id] ?? 0;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              chatId: chat.id,
              otherUserId: otherUserId,
              otherUserName: name,
              otherUserPhoto: photo,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Amber left-border accent when there are pending work requests
          color: pendingWork > 0
              ? const Color(0xFFFFF8E1) // very light amber tint
              : null,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!),
            left: pendingWork > 0
                ? const BorderSide(color: Color(0xFFFF8F00), width: 4)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Profile Photo
            StreamBuilder<UserPresence>(
              stream: PresenceService.instance.watchUser(otherUserId),
              builder: (context, presenceSnap) {
                final isOnline = presenceSnap.data?.isOnline ?? false;
                return Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.transparent,
                      child: UniversalAvatar(
                        photoUrl: photo,
                        fallbackName: name,
                        radius: 28,
                        animate: false,
                      ),
                    ),
                    // Online indicator dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    // Unread badge (red, top-right)
                    if (unreadCount > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Pending work request badge (amber, top-left)
                    if (pendingWork > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF8F00),
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Center(
                            child: Text(
                              pendingWork > 99 ? '99+' : pendingWork.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(width: 12),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppHelpers.capitalize(name),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppHelpers.getRelativeTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? const Color(0xFFE91E63)
                              : Colors.grey[600],
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (chat.lastMessageType == 'image')
                        const Icon(
                          Icons.image,
                          size: 16,
                          color: Colors.grey,
                        ),
                      if (chat.lastMessageType == 'image')
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          chat.lastMessage.isEmpty
                              ? 'No messages yet'
                              : chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Amber work-request indicator row
                  if (pendingWork > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 13, color: Color(0xFFFF8F00)),
                        const SizedBox(width: 4),
                        Text(
                          pendingWork == 1
                              ? '1 pending work request'
                              : '$pendingWork pending work requests',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFFF8F00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with skilled professionals',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
