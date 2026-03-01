import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/service_request_model.dart';
import '../models/job_model.dart';
import '../services/chat_service.dart';
import '../services/firestore_service.dart';
import '../screens/chat/chat_detail_screen.dart';
import '../screens/jobs/job_detail_screen.dart';
import '../screens/shop/order_tracking_screen.dart';
import 'app_constants.dart';
import 'app_helpers.dart';

/// Type of notification - used for click-based navigation.
enum NotificationType { workRequest, order, chatMessage, jobApplication }

/// A single notification item (work-request, order update, or chat message).
class NotificationItem {
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  /// Navigation metadata - used when the user taps a notification card.
  final NotificationType type;
  final String? chatId; // For work-request & chat notifications
  final String? otherUserId; // The other participant
  final String? otherUserName;
  final String? otherUserPhoto;
  final String? requestId; // For work-request notifications
  final OrderModel? orderData; // For order notifications
  final String? jobId; // For job application notifications

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.icon,
    required this.color,
    this.type = NotificationType.workRequest,
    this.chatId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserPhoto,
    this.requestId,
    this.orderData,
    this.jobId,
  });
}

String _capitalizeStatus(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Updated';
  return value[0].toUpperCase() + value.substring(1);
}

bool _isMeaningful(String? value) => (value ?? '').trim().isNotEmpty;

/// Load up to [limit] recent notifications for [userId].
/// Includes work requests, reminders, orders, AND unread chat messages.
Future<List<NotificationItem>> loadNotificationsForUser(
  String userId, {
  int limit = 25,
}) async {
  final firestoreService = FirestoreService();
  final notifications = <NotificationItem>[];

  final results = await Future.wait([
    firestoreService.getLatestUserWorkRequests(userId, limit: limit),
    firestoreService.getLatestOrdersForUser(userId, limit: limit),
    FirebaseFirestore.instance
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: userId)
        .get(),
    FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .get(),
  ]);

  final requests = results[0] as List<ServiceRequestModel>;
  final orders = results[1] as List<OrderModel>;
  final chatsSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
  final reminderSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

  final userCache = <String, Map<String, String?>>{};
  final chatCache = <String, Map<String, dynamic>?>{};

  Future<Map<String, String?>> loadUserBasic(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) return const {'name': null, 'photo': null};
    final existing = userCache[id];
    if (existing != null) return existing;
    final user = await firestoreService.getUserById(id);
    final basic = <String, String?>{
      'name': user?.name.trim().isNotEmpty == true ? user!.name.trim() : null,
      'photo': user?.profilePhoto?.trim().isNotEmpty == true
          ? user!.profilePhoto!.trim()
          : null,
    };
    userCache[id] = basic;
    return basic;
  }

  Future<Map<String, dynamic>?> loadChat(String chatId) async {
    final id = chatId.trim();
    if (id.isEmpty) return null;
    if (chatCache.containsKey(id)) return chatCache[id];
    final snap = await FirebaseFirestore.instance
        .collection(AppConstants.chatsCollection)
        .doc(id)
        .get();
    final data = snap.exists ? snap.data() : null;
    chatCache[id] = data;
    return data;
  }

  final requestById = <String, ServiceRequestModel>{
    for (final request in requests) request.id: request,
  };

  for (final request in requests) {
    final otherUserId = request.customerId == userId
        ? request.skilledUserId
        : request.customerId;
    final isCurrentUserRequestOwner = request.customerId == userId;
    var otherUserName = isCurrentUserRequestOwner
        ? request.skilledUserName
        : request.requesterName;
    var otherUserPhoto = isCurrentUserRequestOwner
        ? request.skilledUserPhoto
        : request.requesterPhoto;

    final preferredChatId = (_isMeaningful(request.workChatId) &&
            (request.status == AppConstants.requestStatusAccepted ||
                request.status == AppConstants.requestStatusCompleted))
        ? request.workChatId!.trim()
        : (request.chatId ?? '').trim();

    if ((!_isMeaningful(otherUserName) || !_isMeaningful(otherUserPhoto)) &&
        preferredChatId.isNotEmpty &&
        otherUserId.isNotEmpty) {
      final chatData = await loadChat(preferredChatId);
      final participantDetails =
          chatData?['participantDetails'] as Map<String, dynamic>?;
      final details = participantDetails?[otherUserId] as Map<String, dynamic>?;
      final nameFromChat = (details?['name'] as String?)?.trim();
      final photoFromChat = (details?['photo'] as String?)?.trim();
      if (!_isMeaningful(otherUserName) && _isMeaningful(nameFromChat)) {
        otherUserName = nameFromChat;
      }
      if (!_isMeaningful(otherUserPhoto) && _isMeaningful(photoFromChat)) {
        otherUserPhoto = photoFromChat;
      }
    }

    if ((!_isMeaningful(otherUserName) || !_isMeaningful(otherUserPhoto)) &&
        otherUserId.isNotEmpty) {
      final otherUser = await loadUserBasic(otherUserId);
      if (!_isMeaningful(otherUserName) && _isMeaningful(otherUser['name'])) {
        otherUserName = otherUser['name'];
      }
      if (!_isMeaningful(otherUserPhoto) && _isMeaningful(otherUser['photo'])) {
        otherUserPhoto = otherUser['photo'];
      }
    }

    final isPendingForSkilled =
        request.status == AppConstants.requestStatusPending &&
            request.skilledUserId == userId;
    final requestTitle =
        request.title.trim().isNotEmpty ? request.title.trim() : 'Work request';

    notifications.add(
      NotificationItem(
        title: isPendingForSkilled
            ? 'New work request: $requestTitle'
            : 'Work request: $requestTitle',
        subtitle:
            'Status: ${_capitalizeStatus(request.status)} - ${request.description.trim().isEmpty ? 'No description' : request.description.trim()}',
        createdAt: request.updatedAt,
        icon: request.status == AppConstants.requestStatusAccepted
            ? Icons.check_circle
            : request.status == AppConstants.requestStatusRejected
                ? Icons.cancel
                : request.status == AppConstants.requestStatusCompleted
                    ? Icons.task_alt
                    : Icons.work_outline,
        color: request.status == AppConstants.requestStatusAccepted
            ? Colors.green
            : request.status == AppConstants.requestStatusRejected
                ? Colors.red
                : request.status == AppConstants.requestStatusCompleted
                    ? const Color(0xFF1565C0)
                    : Colors.orange,
        type: NotificationType.workRequest,
        chatId: preferredChatId.isNotEmpty ? preferredChatId : null,
        requestId: request.id,
        otherUserId: otherUserId,
        otherUserName:
            _isMeaningful(otherUserName) ? otherUserName!.trim() : null,
        otherUserPhoto:
            _isMeaningful(otherUserPhoto) ? otherUserPhoto!.trim() : null,
      ),
    );
  }

  // Reminder notifications (from notifications collection).
  for (final doc in reminderSnap.docs) {
    final data = doc.data();
    final type = (data['type'] as String?)?.trim() ?? '';
    // ── Job application notifications ────────────────────────────────────
    if (type == 'jobApplication') {
      final fromUserId = (data['fromUserId'] as String?)?.trim() ?? '';
      final jobTitle = (data['jobTitle'] as String?)?.trim() ?? '';
      final body = (data['body'] as String?)?.trim();
      final notifTitle =
          (data['title'] as String?)?.trim() ?? 'New job application';
      final notifJobId = (data['jobId'] as String?)?.trim();
      final createdAtTs = data['createdAt'] as Timestamp?;
      final createdAt = createdAtTs?.toDate() ?? DateTime.now();

      String? fromUserName;
      String? fromUserPhoto;
      if (fromUserId.isNotEmpty) {
        final basic = await loadUserBasic(fromUserId);
        fromUserName = basic['name'];
        fromUserPhoto = basic['photo'];
      }

      notifications.add(
        NotificationItem(
          title: notifTitle,
          subtitle: _isMeaningful(body)
              ? body!
              : '${_isMeaningful(fromUserName) ? fromUserName : 'Someone'}'
                  ' applied${jobTitle.isNotEmpty ? ' for "$jobTitle"' : ''}',
          createdAt: createdAt,
          icon: Icons.work_history_rounded,
          color: const Color(0xFF4CAF50),
          type: NotificationType.jobApplication,
          otherUserId: fromUserId.isNotEmpty ? fromUserId : null,
          otherUserName: _isMeaningful(fromUserName) ? fromUserName : null,
          otherUserPhoto:
              _isMeaningful(fromUserPhoto) ? fromUserPhoto : null,
          jobId: notifJobId,
        ),
      );
      continue;
    }
    if (type != 'work_request_reminder') continue;

    final requestId = (data['requestId'] as String?)?.trim();
    final request = requestId != null ? requestById[requestId] : null;
    final fromUserId = (data['fromUserId'] as String?)?.trim() ?? '';
    final title = (data['title'] as String?)?.trim();
    final body = (data['body'] as String?)?.trim();
    final createdAtTs = data['createdAt'] as Timestamp?;
    final createdAt = createdAtTs?.toDate() ?? DateTime.now();

    String? fromUserName;
    String? fromUserPhoto;
    if (fromUserId.isNotEmpty) {
      final basic = await loadUserBasic(fromUserId);
      fromUserName = basic['name'];
      fromUserPhoto = basic['photo'];
    }

    notifications.add(
      NotificationItem(
        title: _isMeaningful(title) ? title!.trim() : 'Reminder',
        subtitle: _isMeaningful(body) ? body!.trim() : 'Work request reminder',
        createdAt: createdAt,
        icon: Icons.notifications_active_rounded,
        color: const Color(0xFFFF9800),
        type: NotificationType.workRequest,
        chatId: _isMeaningful(request?.chatId) ? request!.chatId : null,
        requestId: requestId,
        otherUserId: fromUserId.isNotEmpty ? fromUserId : null,
        otherUserName: _isMeaningful(fromUserName) ? fromUserName : null,
        otherUserPhoto: _isMeaningful(fromUserPhoto) ? fromUserPhoto : null,
      ),
    );
  }

  for (final order in orders) {
    final isBuyer = order.buyerId == userId;
    final isSeller = order.sellerId == userId;
    final actorLabel = isBuyer
        ? 'Your order'
        : isSeller
            ? 'Sale update'
            : 'Delivery update';
    final timeline = order.statusTimeline.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final latestTimeline = timeline.isNotEmpty
        ? '${timeline.first.key} at ${AppHelpers.formatDateTime(timeline.first.value)}'
        : 'status updated';

    notifications.add(
      NotificationItem(
        title: '$actorLabel: ${order.productName}',
        subtitle: 'Order ${order.status.toUpperCase()} - $latestTimeline',
        createdAt: order.updatedAt,
        icon: isBuyer
            ? Icons.shopping_bag
            : isSeller
                ? Icons.store
                : Icons.local_shipping,
        color: isBuyer
            ? const Color(0xFF2196F3)
            : isSeller
                ? const Color(0xFF6A11CB)
                : const Color(0xFFFF6B35),
        type: NotificationType.order,
        orderData: order,
      ),
    );
  }

  // Chat messages (unread).
  for (final doc in chatsSnap.docs) {
    final data = doc.data();
    final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
    final unread = unreadMap?[userId];
    final unreadCount = unread is int ? unread : 0;
    if (unreadCount <= 0) continue;

    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId =
        participants.firstWhere((id) => id != userId, orElse: () => '');

    String senderName = 'Someone';
    String? senderPhoto;
    final participantDetails =
        data['participantDetails'] as Map<String, dynamic>?;
    if (participantDetails != null && otherUserId.isNotEmpty) {
      final details = participantDetails[otherUserId] as Map<String, dynamic>?;
      final nameFromChat = (details?['name'] as String?)?.trim();
      final photoFromChat = (details?['photo'] as String?)?.trim();
      if (_isMeaningful(nameFromChat)) senderName = nameFromChat!;
      if (_isMeaningful(photoFromChat)) senderPhoto = photoFromChat;
    }
    if (senderName == 'Someone' && otherUserId.isNotEmpty) {
      final basic = await loadUserBasic(otherUserId);
      if (_isMeaningful(basic['name'])) senderName = basic['name']!;
      if (!_isMeaningful(senderPhoto) && _isMeaningful(basic['photo'])) {
        senderPhoto = basic['photo'];
      }
    }

    final lastMsg = (data['lastMessage'] as String?)?.trim() ?? '';
    final lastMsgTime = data['lastMessageTime'];
    DateTime msgTime = DateTime.now();
    if (lastMsgTime is Timestamp) msgTime = lastMsgTime.toDate();

    final badge = unreadCount > 1 ? ' (+$unreadCount)' : '';
    notifications.add(
      NotificationItem(
        title: 'New message from $senderName$badge',
        subtitle: lastMsg.isEmpty ? 'Sent you a message' : lastMsg,
        createdAt: msgTime,
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF00ACC1),
        type: NotificationType.chatMessage,
        chatId: doc.id,
        otherUserId: otherUserId,
        otherUserName: senderName,
        otherUserPhoto: senderPhoto,
      ),
    );
  }

  notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return notifications.take(limit).toList();
}

class _ResolvedChatTarget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const _ResolvedChatTarget({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });
}

Future<_ResolvedChatTarget?> _resolveChatTarget({
  required NotificationItem item,
  required String currentUserId,
}) async {
  final firestore = FirebaseFirestore.instance;
  final firestoreService = FirestoreService();
  final chatService = ChatService();

  String chatId = (item.chatId ?? '').trim();
  String otherUserId = (item.otherUserId ?? '').trim();
  String otherUserName = (item.otherUserName ?? '').trim();
  String? otherUserPhoto =
      _isMeaningful(item.otherUserPhoto) ? item.otherUserPhoto!.trim() : null;

  Map<String, dynamic>? chatData;
  if (chatId.isNotEmpty) {
    final chatDoc = await firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .get();
    chatData = chatDoc.exists ? chatDoc.data() : null;
  }

  if (chatData != null && otherUserId.isEmpty) {
    final participants = List<String>.from(chatData['participants'] ?? []);
    otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }

  if (chatData != null && otherUserId.isNotEmpty) {
    final detailsMap = chatData['participantDetails'] as Map<String, dynamic>?;
    final details = detailsMap?[otherUserId] as Map<String, dynamic>?;
    final nameFromChat = (details?['name'] as String?)?.trim() ?? '';
    final photoFromChat = (details?['photo'] as String?)?.trim() ?? '';
    if (otherUserName.isEmpty && nameFromChat.isNotEmpty) {
      otherUserName = nameFromChat;
    }
    if (!_isMeaningful(otherUserPhoto) && photoFromChat.isNotEmpty) {
      otherUserPhoto = photoFromChat;
    }
  }

  if (otherUserId.isNotEmpty && chatId.isEmpty) {
    final currentUser = await firestoreService.getUserById(currentUserId);
    final otherUser = await firestoreService.getUserById(otherUserId);
    chatId = await chatService.getOrCreateChat(
      currentUserId,
      otherUserId,
      {
        'name': currentUser?.name ?? 'You',
        'profilePhoto': currentUser?.profilePhoto ?? '',
        'role': currentUser?.role ?? '',
      },
      {
        'name': otherUser?.name ?? 'User',
        'profilePhoto': otherUser?.profilePhoto ?? '',
        'role': otherUser?.role ?? '',
      },
    );
    if (otherUserName.isEmpty && (otherUser?.name.trim().isNotEmpty == true)) {
      otherUserName = otherUser!.name.trim();
    }
    if (!_isMeaningful(otherUserPhoto) &&
        (otherUser?.profilePhoto?.trim().isNotEmpty == true)) {
      otherUserPhoto = otherUser!.profilePhoto!.trim();
    }
  }

  if (otherUserId.isNotEmpty && otherUserName.isEmpty) {
    final otherUser = await firestoreService.getUserById(otherUserId);
    if (otherUser?.name.trim().isNotEmpty == true) {
      otherUserName = otherUser!.name.trim();
    }
    if (!_isMeaningful(otherUserPhoto) &&
        (otherUser?.profilePhoto?.trim().isNotEmpty == true)) {
      otherUserPhoto = otherUser!.profilePhoto!.trim();
    }
  }

  if (chatId.isEmpty || otherUserId.isEmpty) return null;
  if (otherUserName.isEmpty) otherUserName = 'User';

  return _ResolvedChatTarget(
    chatId: chatId,
    otherUserId: otherUserId,
    otherUserName: otherUserName,
    otherUserPhoto: _isMeaningful(otherUserPhoto) ? otherUserPhoto : null,
  );
}

Future<void> openNotificationItem(
  BuildContext context, {
  required NotificationItem item,
  required String currentUserId,
}) async {
  switch (item.type) {
    case NotificationType.order:
      final order = item.orderData;
      if (order == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open this order update.')),
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderTrackingScreen(order: order)),
      );
      return;
    case NotificationType.jobApplication:
      final jobId = item.jobId?.trim();
      if (jobId == null || jobId.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job details not available.')),
        );
        return;
      }
      final jobSnap = await FirebaseFirestore.instance
          .collection(AppConstants.jobsCollection)
          .doc(jobId)
          .get();
      if (!jobSnap.exists) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This job is no longer available.')),
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(
              job: JobModel.fromMap(jobSnap.data()!, jobSnap.id)),
        ),
      );
      return;
    case NotificationType.workRequest:
    case NotificationType.chatMessage:
      final target = await _resolveChatTarget(
        item: item,
        currentUserId: currentUserId,
      );
      if (target == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unable to open this conversation right now.')),
        );
        return;
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            chatId: target.chatId,
            otherUserId: target.otherUserId,
            otherUserName: target.otherUserName,
            otherUserPhoto: target.otherUserPhoto,
          ),
        ),
      );
      return;
  }
}

/// Stream that returns the count of new notifications since [lastSeenAt].
Stream<int> newNotificationCountStream(
  String userId,
  DateTime? lastSeenAt,
) {
  final requestStream = FirebaseFirestore.instance
      .collection(AppConstants.requestsCollection)
      .where('participants', arrayContains: userId)
      .snapshots()
      .map((s) => s.docs.where((d) {
            final ts = d.data()['updatedAt'] as Timestamp?;
            if (ts == null) return false;
            if (lastSeenAt == null) return true;
            return ts.toDate().isAfter(lastSeenAt);
          }).length);

  return requestStream;
}
