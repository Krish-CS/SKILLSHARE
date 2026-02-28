import 'package:flutter/material.dart';

/// WhatsApp-style avatar picker with emoji/icon-based avatars.
///
/// Returns the selected avatar key (e.g. 'avatar_1') or null if dismissed.
class AvatarPickerSheet extends StatefulWidget {
  const AvatarPickerSheet({super.key, this.currentAvatar});

  final String? currentAvatar;

  /// Show the avatar picker and return the selected key.
  static Future<String?> show(BuildContext context, {String? currentAvatar}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerSheet(currentAvatar: currentAvatar),
    );
  }

  @override
  State<AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<AvatarPickerSheet> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentAvatar;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.face_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Choose Avatar',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_selected != null)
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'remove_avatar'),
                    child: const Text('Remove',
                        style: TextStyle(color: Colors.red)),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Avatar grid
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: avatarOptions.length,
              itemBuilder: (context, index) {
                final avatar = avatarOptions[index];
                final isSelected = _selected == avatar.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selected = avatar.key);
                    Navigator.pop(context, avatar.key);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? avatar.bgColor.withValues(alpha: 0.2)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF6A11CB)
                            : Colors.grey[200]!,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6A11CB)
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// An avatar option with a key, emoji, and background color.
class AvatarOption {
  const AvatarOption({
    required this.key,
    required this.emoji,
    required this.bgColor,
  });
  final String key;
  final String emoji;
  final Color bgColor;
}

/// All available avatar options
const avatarOptions = <AvatarOption>[
  // People
  AvatarOption(key: 'avatar_smile', emoji: '😊', bgColor: Color(0xFFFFF9C4)),
  AvatarOption(key: 'avatar_cool', emoji: '😎', bgColor: Color(0xFFBBDEFB)),
  AvatarOption(key: 'avatar_nerd', emoji: '🤓', bgColor: Color(0xFFC8E6C9)),
  AvatarOption(key: 'avatar_wink', emoji: '😉', bgColor: Color(0xFFFFF9C4)),
  AvatarOption(key: 'avatar_star', emoji: '🤩', bgColor: Color(0xFFFFE0B2)),
  AvatarOption(key: 'avatar_think', emoji: '🤔', bgColor: Color(0xFFE1BEE7)),
  AvatarOption(key: 'avatar_heart', emoji: '🥰', bgColor: Color(0xFFF8BBD0)),
  AvatarOption(key: 'avatar_laugh', emoji: '😂', bgColor: Color(0xFFFFF9C4)),
  // Professionals
  AvatarOption(key: 'avatar_worker', emoji: '👷', bgColor: Color(0xFFFFE0B2)),
  AvatarOption(key: 'avatar_artist', emoji: '🧑‍🎨', bgColor: Color(0xFFE1BEE7)),
  AvatarOption(key: 'avatar_chef', emoji: '👨‍🍳', bgColor: Color(0xFFFFF9C4)),
  AvatarOption(key: 'avatar_tech', emoji: '👨‍💻', bgColor: Color(0xFFBBDEFB)),
  AvatarOption(key: 'avatar_camera', emoji: '📷', bgColor: Color(0xFFB2DFDB)),
  AvatarOption(key: 'avatar_teacher', emoji: '👩‍🏫', bgColor: Color(0xFFC8E6C9)),
  AvatarOption(key: 'avatar_mechanic', emoji: '🔧', bgColor: Color(0xFFCFD8DC)),
  AvatarOption(key: 'avatar_scientist', emoji: '🧑‍🔬', bgColor: Color(0xFFBBDEFB)),
  // Animals
  AvatarOption(key: 'avatar_cat', emoji: '🐱', bgColor: Color(0xFFFFE0B2)),
  AvatarOption(key: 'avatar_dog', emoji: '🐶', bgColor: Color(0xFFD7CCC8)),
  AvatarOption(key: 'avatar_fox', emoji: '🦊', bgColor: Color(0xFFFFE0B2)),
  AvatarOption(key: 'avatar_panda', emoji: '🐼', bgColor: Color(0xFFE0E0E0)),
  AvatarOption(key: 'avatar_lion', emoji: '🦁', bgColor: Color(0xFFFFF9C4)),
  AvatarOption(key: 'avatar_unicorn', emoji: '🦄', bgColor: Color(0xFFF3E5F5)),
  AvatarOption(key: 'avatar_owl', emoji: '🦉', bgColor: Color(0xFFD7CCC8)),
  AvatarOption(key: 'avatar_eagle', emoji: '🦅', bgColor: Color(0xFFBBDEFB)),
  // Objects & Abstract
  AvatarOption(key: 'avatar_rocket', emoji: '🚀', bgColor: Color(0xFFBBDEFB)),
  AvatarOption(key: 'avatar_fire', emoji: '🔥', bgColor: Color(0xFFFFCDD2)),
  AvatarOption(key: 'avatar_diamond', emoji: '💎', bgColor: Color(0xFFB3E5FC)),
  AvatarOption(key: 'avatar_crown', emoji: '👑', bgColor: Color(0xFFFFF9C4)),
  AvatarOption(key: 'avatar_music', emoji: '🎵', bgColor: Color(0xFFE1BEE7)),
  AvatarOption(key: 'avatar_palette', emoji: '🎨', bgColor: Color(0xFFF3E5F5)),
  AvatarOption(key: 'avatar_globe', emoji: '🌍', bgColor: Color(0xFFC8E6C9)),
  AvatarOption(key: 'avatar_thunder', emoji: '⚡', bgColor: Color(0xFFFFF9C4)),
];

/// Resolve an avatar key to its emoji display string.
String? getAvatarEmoji(String? avatarKey) {
  if (avatarKey == null || avatarKey.isEmpty) return null;
  try {
    return avatarOptions.firstWhere((a) => a.key == avatarKey).emoji;
  } catch (_) {
    return null;
  }
}

/// Build an avatar widget: if avatarKey is set, show emoji; otherwise fall back
/// to photo or letter avatar via [fallback].
Widget buildAvatarOrPhoto({
  String? avatarKey,
  required double radius,
  required Widget fallback,
  Color? bgColor,
}) {
  final emoji = getAvatarEmoji(avatarKey);
  if (emoji == null) return fallback;

  final bg = bgColor ??
      avatarOptions
          .firstWhere(
            (a) => a.key == avatarKey,
            orElse: () => const AvatarOption(
                key: '', emoji: '', bgColor: Color(0xFFE0E0E0)),
          )
          .bgColor;

  return ClipOval(
    child: Container(
      width: radius * 2,
      height: radius * 2,
      color: bg,
      alignment: Alignment.center,
      child: Text(emoji, style: TextStyle(fontSize: radius * 0.9)),
    ),
  );
}
