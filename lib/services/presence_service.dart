import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages user online/offline presence via Firestore.
///
/// Writes to `users/{uid}` with fields:
///   - `isOnline` : bool
///   - `lastSeen` : Timestamp
///
/// Heartbeat keeps the user "online" for as long as the app is running.
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _heartbeat;
  String? _uid;

  /// Call once after login / app start.
  void startTracking(String uid) {
    if (_uid == uid) return; // already tracking
    stopTracking(); // clean up previous user
    _uid = uid;
    _setOnline();
    // Heartbeat every 60 s → keeps `lastSeen` fresh so stale sessions expire
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) => _setOnline());
  }

  /// Call on logout / app termination.
  void stopTracking() {
    _heartbeat?.cancel();
    _heartbeat = null;
    if (_uid != null) {
      _setOffline();
      _uid = null;
    }
  }

  // ── Real‑time streams ───────────────────────────────────────────────────

  /// Stream the online status + lastSeen of a single user.
  Stream<UserPresence> watchUser(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return const UserPresence(isOnline: false, lastSeen: null);
      final bool isOnline = data['isOnline'] == true;
      final Timestamp? ts = data['lastSeen'] as Timestamp?;
      // If heartbeat is stale (>3 min), treat as offline
      final DateTime? lastSeen = ts?.toDate();
      final bool actuallyOnline = isOnline &&
          lastSeen != null &&
          DateTime.now().difference(lastSeen).inMinutes < 3;
      return UserPresence(isOnline: actuallyOnline, lastSeen: lastSeen);
    });
  }

  /// Stream the online status of multiple users at once (by reading individual docs).
  Stream<Map<String, bool>> watchUsers(List<String> uids) {
    if (uids.isEmpty) return Stream.value({});

    // Combine individual user presence streams
    final streams = uids.map((uid) => watchUser(uid).map((p) => MapEntry(uid, p.isOnline)));
    return _combineLatest(streams.toList());
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<void> _setOnline() async {
    if (_uid == null) return;
    try {
      await _firestore.collection('users').doc(_uid).set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PresenceService._setOnline error: $e');
    }
  }

  Future<void> _setOffline() async {
    if (_uid == null) return;
    try {
      await _firestore.collection('users').doc(_uid).set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PresenceService._setOffline error: $e');
    }
  }

  /// Combine a list of streams of `MapEntry<K,V>` into a single
  /// `Stream<Map<K,V>>` that emits whenever any source emits.
  Stream<Map<String, bool>> _combineLatest(
      List<Stream<MapEntry<String, bool>>> streams) {
    final latest = <String, bool>{};
    // ignore: close_sinks
    final controller = StreamController<Map<String, bool>>.broadcast();
    final subs = <StreamSubscription>[];

    for (final s in streams) {
      subs.add(s.listen((entry) {
        latest[entry.key] = entry.value;
        if (!controller.isClosed) {
          controller.add(Map.unmodifiable(latest));
        }
      }));
    }

    controller.onCancel = () {
      for (final sub in subs) {
        sub.cancel();
      }
    };

    return controller.stream;
  }
}

/// Simple value object for a user's presence state.
class UserPresence {
  final bool isOnline;
  final DateTime? lastSeen;

  const UserPresence({required this.isOnline, this.lastSeen});
}
