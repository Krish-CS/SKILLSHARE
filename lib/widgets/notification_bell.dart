import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

/// A bell icon with an animated badge showing pending notification count.
///
/// Usage:
/// ```dart
/// NotificationBell(
///   userId: currentUser.uid,
///   color: Colors.white,
///   onTap: () => _showNotificationsSheet(context, currentUser.uid),
/// )
/// ```
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.userId,
    required this.onTap,
    this.color = Colors.white,
    this.size = 24.0,
  });

  final String userId;
  final VoidCallback onTap;
  final Color color;
  final double size;

  /// Stream the count of pending notifications (work requests + recent orders)
  Stream<int> _notificationCountStream() {
    // Stream pending work requests involving this user
    return FirebaseFirestore.instance
        .collection(AppConstants.requestsCollection)
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: AppConstants.requestStatusPending)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _notificationCountStream(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  count > 0
                      ? Icons.notifications
                      : Icons.notifications_outlined,
                  color: color,
                  size: size,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF3D3D)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.5),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
