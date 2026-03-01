import 'package:flutter/material.dart';
import '../models/dicebear_config.dart';
import 'avatar_picker.dart';
import '../utils/web_image_loader.dart';

/// A universal avatar widget that renders the appropriate avatar for any user.
///
/// Priority order:
/// 1. DiceBear avatar  (`avatarConfig` with type == 'dicebear')
/// 2. Static emoji avatar (`avatarKey`) — legacy emoji-based picker
/// 3. Profile photo URL (`photoUrl`) — Cloudinary / network image
/// 4. Letter fallback — first character of [fallbackName]
class UniversalAvatar extends StatelessWidget {
  /// Avatar config map from Firestore (DiceBear format).
  final Map<String, dynamic>? avatarConfig;

  /// Static emoji avatar key (legacy, from AvatarPickerSheet).
  final String? avatarKey;

  /// Profile photo URL (Cloudinary / network).
  final String? photoUrl;

  /// Displayed name (first letter used as last-resort fallback).
  final String? fallbackName;

  /// Radius of the circular avatar (width = height = radius * 2).
  final double radius;

  /// Kept for API compatibility — no longer used (DiceBear is static).
  final bool animate;

  /// Optional border color.
  final Color? borderColor;

  /// Optional border width.
  final double borderWidth;

  const UniversalAvatar({
    super.key,
    this.avatarConfig,
    this.avatarKey,
    this.photoUrl,
    this.fallbackName,
    this.radius = 24,
    this.animate = true,
    this.borderColor,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar;

    // 1. DiceBear avatar
    if (DiceBearConfig.isDiceBear(avatarConfig)) {
      final config = DiceBearConfig.fromMap(avatarConfig!);
      avatar = ClipOval(
        child: Image.network(
          config.url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _letterFallback(),
        ),
      );
    }
    // 2. Legacy emoji avatar
    else if (avatarKey != null && avatarKey!.isNotEmpty) {
      avatar = buildAvatarOrPhoto(
        avatarKey: avatarKey,
        radius: radius,
        fallback: _photoOrLetter(),
      );
    }
    // 3. Photo URL or letter fallback
    else {
      avatar = _photoOrLetter();
    }

    // Optional border
    if (borderWidth > 0 && borderColor != null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _photoOrLetter() {
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return WebImageLoader.loadAvatar(
        imageUrl: photoUrl,
        radius: radius,
        fallbackText: fallbackName,
      );
    }
    return _letterFallback();
  }

  Widget _letterFallback() {
    final letter =
        (fallbackName != null && fallbackName!.isNotEmpty)
            ? fallbackName![0].toUpperCase()
            : '?';
    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: const Color(0xFF6A11CB).withValues(alpha: 0.15),
        alignment: Alignment.center,
        child: Text(letter,
            style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6A11CB))),
      ),
    );
  }
}
