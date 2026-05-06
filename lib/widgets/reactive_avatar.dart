import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'universal_avatar.dart';

class ReactiveAvatar extends StatefulWidget {
  final String userId;
  final double radius;
  final String? fallbackName;

  // Stale/cached details from Chat details
  final String? initialPhotoUrl;
  final Map<String, dynamic>? initialAvatarConfig;
  final String? initialAvatarKey;

  const ReactiveAvatar({
    super.key,
    required this.userId,
    this.radius = 24.0,
    this.fallbackName,
    this.initialPhotoUrl,
    this.initialAvatarConfig,
    this.initialAvatarKey,
  });

  @override
  State<ReactiveAvatar> createState() => _ReactiveAvatarState();
}

class _ReactiveAvatarState extends State<ReactiveAvatar> {
  Stream<UserModel?>? _userStream;

  @override
  void initState() {
    super.initState();
    _bindStream();
  }

  @override
  void didUpdateWidget(covariant ReactiveAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _bindStream();
    }
  }

  void _bindStream() {
    final userId = widget.userId.trim();
    if (userId.isEmpty) {
      _userStream = null;
      return;
    }
    final firestoreService = FirestoreService();
    _userStream = firestoreService.streamUserModel(userId);
  }

  @override
  Widget build(BuildContext context) {
    if (_userStream == null) {
      return UniversalAvatar(
        radius: widget.radius,
        fallbackName: widget.fallbackName,
        photoUrl: widget.initialPhotoUrl,
        avatarConfig: widget.initialAvatarConfig,
        avatarKey: widget.initialAvatarKey,
      );
    }

    return StreamBuilder<UserModel?>(
      stream: _userStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          // While loading real-time data, display any passed denormalized/cached information so there's no UI flash.
          return UniversalAvatar(
            radius: widget.radius,
            fallbackName: widget.fallbackName,
            photoUrl: widget.initialPhotoUrl,
            avatarConfig: widget.initialAvatarConfig,
            avatarKey: widget.initialAvatarKey,
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // Using cached data if user document mysteriously fails
          return UniversalAvatar(
            radius: widget.radius,
            fallbackName: widget.fallbackName,
            photoUrl: widget.initialPhotoUrl,
            avatarConfig: widget.initialAvatarConfig,
            avatarKey: widget.initialAvatarKey,
          );
        }

        return UniversalAvatar(
          radius: widget.radius,
          fallbackName:
              user.name.isNotEmpty ? user.name : widget.fallbackName,
          photoUrl: user.profilePhoto,
          avatarConfig: user.avatarConfig,
          // avatarKey is usually encapsulated inside avatarConfig or profilePhoto on an updated profile
        );
      },
    );
  }
}
