import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/dicebear_config.dart';
import '../../utils/web_image_loader.dart';

/// Full-screen DiceBear avatar customiser.
///
/// Opens with an optional [initialConfig].  On save, pops and returns a
/// `Map<String, dynamic>` (DiceBear format) that can be stored directly in
/// Firestore.
class AvatarBuilderScreen extends StatefulWidget {
  /// Pass the existing avatarConfig map (or null for a new avatar).
  final Map<String, dynamic>? initialConfig;

  const AvatarBuilderScreen({super.key, this.initialConfig});

  @override
  State<AvatarBuilderScreen> createState() => _AvatarBuilderScreenState();
}

class _AvatarBuilderScreenState extends State<AvatarBuilderScreen> {
  late DiceBearConfig _config;

  // Styles that support skinColor
  static const _hasSkin = {
    'adventurer', 'avataaars', 'micah', 'lorelei',
    'big-ears', 'pixel-art',
  };
  // Styles that support hairColor
  static const _hasHair = {
    'adventurer', 'avataaars', 'micah', 'lorelei',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null &&
        DiceBearConfig.isDiceBear(widget.initialConfig)) {
      _config = DiceBearConfig.fromMap(widget.initialConfig!);
    } else {
      _config = DiceBearConfig(
        seed: _randomSeed(),
        backgroundColor: DiceBearConfig.bgColors.first,
        skinColor: DiceBearConfig.skinColors[2],
        hairColor: DiceBearConfig.hairColors[0],
      );
    }
  }

  String _randomSeed() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _shuffleSeed() {
    setState(() {
      _config = _config.copyWith(seed: _randomSeed());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Avatar',
            style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(_config.toMap()),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Save',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live Preview ─────────────────────────────────────────────────
          _buildPreview(),
          const SizedBox(height: 24),

          // ── Style Picker ─────────────────────────────────────────────────
          _sectionTitle('Style'),
          const SizedBox(height: 10),
          _buildStylePicker(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _shuffleSeed,
              icon: const Icon(Icons.shuffle_rounded),
              label: const Text('Shuffle Look'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6A11CB),
                side: const BorderSide(color: Color(0xFF6A11CB)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── Background Color ──────────────────────────────────────────────
          _sectionTitle('Background'),
          const SizedBox(height: 10),
          _buildColorRow(
            colors: DiceBearConfig.bgColors,
            selected: _config.backgroundColor,
            onTap: (c) =>
                setState(() => _config = _config.copyWith(backgroundColor: c)),
          ),
          const SizedBox(height: 24),

          // ── Skin Color ────────────────────────────────────────────────────
          if (_hasSkin.contains(_config.style)) ...[
            _sectionTitle('Skin Tone'),
            const SizedBox(height: 10),
            _buildColorRow(
              colors: DiceBearConfig.skinColors,
              selected: _config.skinColor,
              onTap: (c) =>
                  setState(() => _config = _config.copyWith(skinColor: c)),
            ),
            const SizedBox(height: 24),
          ],

          // ── Hair Color ────────────────────────────────────────────────────
          if (_hasHair.contains(_config.style)) ...[
            _sectionTitle('Hair Color'),
            const SizedBox(height: 10),
            _buildColorRow(
              colors: DiceBearConfig.hairColors,
              selected: _config.hairColor,
              onTap: (c) =>
                  setState(() => _config = _config.copyWith(hairColor: c)),
            ),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6A11CB), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A11CB).withValues(alpha: 0.2),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: WebImageLoader.loadImage(
                imageUrl: _config.url,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                errorWidget: const Center(
                  child: Icon(Icons.face, size: 60, color: Color(0xFF6A11CB)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Live Preview',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildStylePicker() {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DiceBearConfig.styles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final s = DiceBearConfig.styles[i];
          final id = s['id']!;
          final label = s['label']!;
          final selected = _config.style == id;
          final previewUrl =
              'https://api.dicebear.com/9.x/$id/png'
              '?seed=${_config.seed}&size=64'
              '&backgroundColor=${_config.backgroundColor}';
          return GestureDetector(
            onTap: () =>
                setState(() => _config = _config.copyWith(style: id)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6A11CB)
                          : Colors.grey.shade300,
                      width: selected ? 3 : 1.5,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6A11CB)
                                  .withValues(alpha: 0.3),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                  child: ClipOval(
                    child: WebImageLoader.loadImage(
                      imageUrl: previewUrl,
                      fit: BoxFit.cover,
                      errorWidget: const Icon(Icons.face, size: 28),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                    color: selected
                        ? const Color(0xFF6A11CB)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF212121)),
      );

  Widget _buildColorRow({
    required List<String> colors,
    required String? selected,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((hex) {
        final color = Color(int.parse('FF$hex', radix: 16));
        final isSelected = selected == hex;
        return GestureDetector(
          onTap: () => onTap(hex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6A11CB)
                    : Colors.grey.shade300,
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF6A11CB)
                            .withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: color.computeLuminance() > 0.5
                        ? Colors.black87
                        : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}
