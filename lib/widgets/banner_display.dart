import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/web_image_loader.dart';

/// Renders a profile banner from [bannerData].
///
/// bannerData shape:
/// ```json
/// {
///   "type": "image" | "text",
///   "imageUrl": "https://...",
///   "text": "Hello World",
///   "fontKey": "default" | "pacifico" | "dancing" | "oswald" | "lexend" | "playfair",
///   "textColor": 4294967295,      // ARGB int (Colors.white.value)
///   "gradientIndex": 0,           // 0-4 preset gradients
///   "animation": "none" | "pulse" | "fade" | "shimmer" | "slide" | "wave",
///   "fontSize": 28.0
/// }
/// ```
class BannerDisplay extends StatefulWidget {
  const BannerDisplay({
    super.key,
    required this.bannerData,
    required this.defaultColors,
    this.height = 200.0,
    this.child, // extra overlay widget (e.g. pencil edit button)
  });

  final Map<String, dynamic>? bannerData;
  final List<Color> defaultColors;
  final double height;
  final Widget? child;

  @override
  State<BannerDisplay> createState() => _BannerDisplayState();
}

class _BannerDisplayState extends State<BannerDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ─── Gradient presets ────────────────────────────────────────────────────

  static const _gradients = <List<Color>>[
    [Color(0xFF6A11CB), Color(0xFF2575FC)], // purple-blue
    [Color(0xFFFF416C), Color(0xFFFF4B2B)], // red-orange
    [Color(0xFF000428), Color(0xFF004E92)], // dark-navy
    [Color(0xFF093637), Color(0xFF0D7377)], // teal
    [Color(0xFF1a1a2e), Color(0xFFe43396)], // dark-pink
  ];

  List<Color> get _resolvedGradient {
    final d = widget.bannerData;
    if (d == null) return widget.defaultColors;
    final idx = (d['gradientIndex'] as int?) ?? -1;
    if (idx >= 0 && idx < _gradients.length) return _gradients[idx];
    return widget.defaultColors;
  }

  // ─── Font helper ─────────────────────────────────────────────────────────

  static TextStyle fontStyle(
      String? fontKey, double fontSize, Color color, bool bold) {
    final base = TextStyle(
      fontSize: fontSize,
      color: color,
      fontWeight: bold ? FontWeight.bold : FontWeight.w700,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)
      ],
    );
    switch (fontKey) {
      case 'pacifico':
        return GoogleFonts.pacifico(textStyle: base);
      case 'dancing':
        return GoogleFonts.dancingScript(textStyle: base);
      case 'oswald':
        return GoogleFonts.oswald(textStyle: base);
      case 'lexend':
        return GoogleFonts.lexend(textStyle: base);
      case 'playfair':
        return GoogleFonts.playfairDisplay(textStyle: base);
      default:
        return base;
    }
  }

  // ─── Animated text ────────────────────────────────────────────────────────

  Widget _animatedText(String text, String? fontKey, Color color,
      double fontSize, String animation) {
    final style = fontStyle(fontKey, fontSize, color, true);

    switch (animation) {
      case 'pulse':
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.08).animate(_anim),
          child: Text(text, style: style, textAlign: TextAlign.center),
        );
      case 'fade':
        return FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_anim),
          child: Text(text, style: style, textAlign: TextAlign.center),
        );
      case 'shimmer':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: const [
                  Colors.white60,
                  Colors.white,
                  Colors.white60,
                ],
                stops: [
                  (_ctrl.value - 0.3).clamp(0.0, 1.0),
                  _ctrl.value.clamp(0.0, 1.0),
                  (_ctrl.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: Text(text, style: style, textAlign: TextAlign.center),
            );
          },
        );
      case 'slide':
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.12, 0),
            end: const Offset(0.12, 0),
          ).animate(_anim),
          child: Text(text, style: style, textAlign: TextAlign.center),
        );
      case 'wave':
        return _WaveText(text: text, style: style, animation: _anim);
      default:
        return Text(text, style: style, textAlign: TextAlign.center);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.bannerData;
    final type = d?['type'] as String?;

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // ── background ──
          if (type == 'image' && (d?['imageUrl'] as String?)?.isNotEmpty == true)
            Positioned.fill(
              child: WebImageLoader.loadImage(
                imageUrl: d!['imageUrl'] as String,
                fit: BoxFit.cover,
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _resolvedGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),

          // ── decorative blobs ──
          Positioned(
              top: -40,
              right: -40,
              child: _blob(200, Colors.white.withValues(alpha: 0.07))),
          Positioned(
              top: 20,
              left: -50,
              child: _blob(160, Colors.white.withValues(alpha: 0.05))),
          Positioned(
              bottom: 30,
              right: 60,
              child: _blob(80, Colors.white.withValues(alpha: 0.04))),

          // ── text overlay (for text-type banners) ──
          if (type == 'text' && d != null)
            Positioned.fill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _animatedText(
                    (d['text'] as String?) ?? '',
                    d['fontKey'] as String?,
                    Color((d['textColor'] as int?) ?? 0xFFFFFFFF),
                    (d['fontSize'] as num?)?.toDouble() ?? 28.0,
                    (d['animation'] as String?) ?? 'none',
                  ),
                ),
              ),
            ),

          // ── caller-supplied overlay (role pill, edit button, etc.) ──
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// ─── Wave text ────────────────────────────────────────────────────────────────

class _WaveText extends StatelessWidget {
  const _WaveText({
    required this.text,
    required this.style,
    required this.animation,
  });

  final String text;
  final TextStyle style;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final chars = text.characters.toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(chars.length, (i) {
            final phase = (animation.value + i * 0.15) % 1.0;
            final offset = -6.0 * (1 - (2 * phase - 1).abs());
            return Transform.translate(
              offset: Offset(0, offset),
              child: Text(chars[i], style: style),
            );
          }),
        );
      },
    );
  }
}

// ─── Font options registry (shared with BannerEditorScreen) ──────────────────

class BannerFonts {
  static const options = <_FontOption>[
    _FontOption(label: 'Default', key: 'default'),
    _FontOption(label: 'Pacifico', key: 'pacifico'),
    _FontOption(label: 'Dancing', key: 'dancing'),
    _FontOption(label: 'Oswald', key: 'oswald'),
    _FontOption(label: 'Lexend', key: 'lexend'),
    _FontOption(label: 'Playfair', key: 'playfair'),
  ];
}

class _FontOption {
  const _FontOption({required this.label, required this.key});
  final String label;
  final String key;
}
