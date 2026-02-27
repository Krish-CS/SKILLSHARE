import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/service_request_model.dart';
import '../services/firestore_service.dart';
import 'app_constants.dart';
import 'app_helpers.dart';

/// A single notification item (work-request or order update).
class NotificationItem {
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final IconData icon;
  final Color color;

  const NotificationItem({
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.icon,
    required this.color,
  });
}

/// Load up to [limit] recent notifications for [userId].
/// Includes work requests, orders, AND unread chat messages.
Future<List<NotificationItem>> loadNotificationsForUser(
  String userId, {
  int limit = 25,
}) async {
  final firestoreService = FirestoreService();
  final notifications = <NotificationItem>[];

  final results = await Future.wait([
    firestoreService.getLatestUserWorkRequests(userId, limit: limit),
    firestoreService.getLatestOrdersForUser(userId, limit: limit),
    // Also fetch chats with unread messages
    FirebaseFirestore.instance
        .collection(AppConstants.chatsCollection)
        .where('participants', arrayContains: userId)
        .get(),
  ]);

  final requests = results[0] as List<ServiceRequestModel>;
  final orders = results[1] as List<OrderModel>;
  final chatsSnap = results[2] as QuerySnapshot;

  for (final request in requests) {
    notifications.add(
      NotificationItem(
        title: 'Work request: ${request.title}',
        subtitle:
            'Status: ${request.status.toUpperCase()} • ${request.description}',
        createdAt: request.updatedAt,
        icon: request.status == AppConstants.requestStatusAccepted
            ? Icons.check_circle
            : request.status == AppConstants.requestStatusRejected
                ? Icons.cancel
                : Icons.work_outline,
        color: request.status == AppConstants.requestStatusAccepted
            ? Colors.green
            : request.status == AppConstants.requestStatusRejected
                ? Colors.red
                : Colors.orange,
      ),
    );
  }

  for (final order in orders) {
    final isBuyer = order.buyerId == userId;
    final actorLabel = isBuyer ? 'Your order' : 'Sale update';
    final timeline = order.statusTimeline.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final latestTimeline = timeline.isNotEmpty
        ? '${timeline.first.key} at ${AppHelpers.formatDateTime(timeline.first.value)}'
        : 'status updated';

    notifications.add(
      NotificationItem(
        title: '$actorLabel: ${order.productName}',
        subtitle: 'Order ${order.status.toUpperCase()} • $latestTimeline',
        createdAt: order.updatedAt,
        icon: isBuyer ? Icons.shopping_bag : Icons.store,
        color: isBuyer ? const Color(0xFF2196F3) : const Color(0xFF6A11CB),
      ),
    );
  }

  notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ── Chat messages (unread) ────────────────────────────────────────────────
  for (final doc in chatsSnap.docs) {
    final data = doc.data() as Map<String, dynamic>;
    final unreadMap = data['unreadCount'] as Map<String, dynamic>?;
    final unread = unreadMap?[userId];
    final unreadCount = unread is int ? unread : 0;
    if (unreadCount <= 0) continue;

    // Identify the sender (the other participant)
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId =
        participants.firstWhere((id) => id != userId, orElse: () => '');

    String senderName = 'Someone';
    final participantDetails =
        data['participantDetails'] as Map<String, dynamic>?;
    if (participantDetails != null && otherUserId.isNotEmpty) {
      final details =
          participantDetails[otherUserId] as Map<String, dynamic>?;
      senderName = (details?['name'] as String?)?.trim().isNotEmpty == true
          ? details!['name'] as String
          : 'Someone';
    }

    final lastMsg = (data['lastMessage'] as String?)?.trim() ?? '';
    final lastMsgTime = data['lastMessageTime'];
    DateTime msgTime = DateTime.now();
    if (lastMsgTime is Timestamp) msgTime = lastMsgTime.toDate();

    final badge = unreadCount > 1 ? ' (+$unreadCount)' : '';
    notifications.add(NotificationItem(
      title: 'New message from $senderName$badge',
      subtitle: lastMsg.isEmpty ? 'Sent you a message' : lastMsg,
      createdAt: msgTime,
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF00ACC1),
    ));
  }

  notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return notifications.take(limit).toList();
}

/// Stream that returns the count of new notifications since [lastSeenAt].
Stream<int> newNotificationCountStream(
  String userId,
  DateTime? lastSeenAt,
) {
  // React to changes in both requests and orders by merging two streams
  final requestStream = FirebaseFirestore.instance
      .collection(AppConstants.requestsCollection)
      .where('participants', arrayContains: userId)
      .snapshots()
      .map((s) => s.docs
          .where((d) {
            final ts = d.data()['updatedAt'] as Timestamp?;
            if (ts == null) return false;
            if (lastSeenAt == null) return true;
            return ts.toDate().isAfter(lastSeenAt);
          })
          .length);

  return requestStream;
}
