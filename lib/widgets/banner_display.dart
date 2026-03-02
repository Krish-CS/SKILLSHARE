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
///   "fontSize": 28.0,
///   "textMatrix": [16 doubles]    // draggable/scale/rotate transform
/// }
/// ```
class BannerDisplay extends StatefulWidget {
  const BannerDisplay({
    super.key,
    required this.bannerData,
    required this.defaultColors,
    this.height = 200.0,
    this.enableAnimations = true,
    this.child, // extra overlay widget (e.g. pencil edit button)
  });

  final Map<String, dynamic>? bannerData;
  final List<Color> defaultColors;
  final double height;
  final bool enableAnimations;
  final Widget? child;

  @override
  State<BannerDisplay> createState() => _BannerDisplayState();
}

class _BannerDisplayState extends State<BannerDisplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  double get _speedFactor {
    final raw = widget.bannerData?['animationSpeed'];
    final value = (raw is num) ? raw.toDouble() : 1.0;
    return value.clamp(0.6, 2.2);
  }

  Duration get _animationDuration {
    final millis = (2000 / _speedFactor).round().clamp(900, 3600);
    return Duration(milliseconds: millis);
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    if (widget.enableAnimations) {
      _ctrl.repeat(reverse: true);
    }
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant BannerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_ctrl.duration != _animationDuration) {
      _ctrl.duration = _animationDuration;
      if (widget.enableAnimations) {
        _ctrl
          ..stop()
          ..repeat(reverse: true);
      }
    }

    if (widget.enableAnimations != oldWidget.enableAnimations) {
      if (widget.enableAnimations) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
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
    [Color(0xFF11998e), Color(0xFF38ef7d)], // green
    [Color(0xFFf12711), Color(0xFFf5af19)], // sunset
    [Color(0xFF654ea3), Color(0xFFeaafc8)], // soft purple
    [Color(0xFF0F2027), Color(0xFF2C5364)], // dark teal
    [Color(0xFFDA4453), Color(0xFF89216B)], // berry
    [Color(0xFF0B132B), Color(0xFF6FFFE9)], // deep cyan
    [Color(0xFFFC466B), Color(0xFF3F5EFB)], // pink-indigo
    [Color(0xFF30CFD0), Color(0xFF330867)], // aqua-violet
    [Color(0xFFFF9966), Color(0xFFFF5E62)], // peach-red
    [Color(0xFF56CCF2), Color(0xFF2F80ED)], // sky
    [Color(0xFF00C6FF), Color(0xFF0072FF)], // electric blue
    [Color(0xFFF4D03F), Color(0xFF16A085)], // gold-teal
    [Color(0xFF667EEA), Color(0xFF764BA2)], // dusk
    [Color(0xFFFF0844), Color(0xFFFFB199)], // coral punch
    [Color(0xFF200122), Color(0xFF6F0000)], // wine
  ];

  List<Color> get _resolvedGradient {
    final d = widget.bannerData;
    if (d == null) return widget.defaultColors;
    final idx = (d['gradientIndex'] as int?) ?? -1;
    if (idx >= 0 && idx < _gradients.length) return _gradients[idx];
    return widget.defaultColors;
  }

  Matrix4 _textMatrixFromData(Map<String, dynamic> d) {
    final raw = d['textMatrix'];
    if (raw is List && raw.length == 16) {
      final values = <double>[];
      for (final v in raw) {
        if (v is num) {
          values.add(v.toDouble());
        } else {
          return Matrix4.identity();
        }
      }
      return Matrix4.fromList(values);
    }
    return Matrix4.identity();
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
      case 'lobster':
        return GoogleFonts.lobster(textStyle: base);
      case 'raleway':
        return GoogleFonts.raleway(textStyle: base);
      case 'mono':
        return GoogleFonts.spaceMono(textStyle: base);
      case 'caveat':
        return GoogleFonts.caveat(textStyle: base);
      case 'satisfy':
        return GoogleFonts.satisfy(textStyle: base);
      case 'righteous':
        return GoogleFonts.righteous(textStyle: base);
      default:
        return base;
    }
  }

  TextStyle _applyTextStylePreset(
      TextStyle base, Color color, String stylePreset) {
    switch (stylePreset) {
      case 'neon':
        return base.copyWith(
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.95), blurRadius: 8),
            Shadow(color: color.withValues(alpha: 0.75), blurRadius: 20),
            Shadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 30),
          ],
        );
      case 'outline':
        return base.copyWith(
          fontWeight: FontWeight.w900,
          shadows: const [
            Shadow(color: Colors.black, offset: Offset(-1, -1), blurRadius: 0),
            Shadow(color: Colors.black, offset: Offset(1, -1), blurRadius: 0),
            Shadow(color: Colors.black, offset: Offset(-1, 1), blurRadius: 0),
            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 0),
          ],
        );
      case 'glass':
        return base.copyWith(
          color: color.withValues(alpha: 0.88),
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.45), blurRadius: 6),
            Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10),
          ],
        );
      case 'shadow':
        return base.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: const [
            Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 6),
            Shadow(color: Colors.black38, offset: Offset(0, 5), blurRadius: 12),
          ],
        );
      case 'bold':
      default:
        return base.copyWith(fontWeight: FontWeight.w800);
    }
  }

  // ─── Animated text ────────────────────────────────────────────────────────

  Widget _animatedText(String text, String? fontKey, Color color,
      double fontSize, String animation, String textStyle) {
    final style = _applyTextStylePreset(
      fontStyle(fontKey, fontSize, color, true),
      color,
      textStyle,
    );
    if (!widget.enableAnimations) {
      return Text(text, style: style, textAlign: TextAlign.center);
    }

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
      case 'bounce':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final bounce = -12.0 * (1 - (2 * _ctrl.value - 1).abs());
            return Transform.translate(
              offset: Offset(0, bounce),
              child: Text(text, style: style, textAlign: TextAlign.center),
            );
          },
        );
      case 'glow':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final glowRadius = 4.0 + 16.0 * _ctrl.value;
            return Text(
              text,
              textAlign: TextAlign.center,
              style: style.copyWith(
                shadows: [
                  Shadow(
                      color: color.withValues(alpha: 0.8),
                      blurRadius: glowRadius),
                  Shadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: glowRadius * 2),
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8),
                ],
              ),
            );
          },
        );
      case 'typewriter':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final charCount =
                (text.length * _ctrl.value).ceil().clamp(0, text.length);
            final visible = text.substring(0, charCount);
            return Text(visible, style: style, textAlign: TextAlign.center);
          },
        );
      case 'rotate':
        return RotationTransition(
          turns: Tween<double>(begin: -0.02, end: 0.02).animate(_anim),
          child: Text(text, style: style, textAlign: TextAlign.center),
        );
      case 'float':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final dy = -8.0 * (1 - (2 * _ctrl.value - 1).abs());
            return Transform.translate(
              offset: Offset(0, dy),
              child: Text(text, style: style, textAlign: TextAlign.center),
            );
          },
        );
      case 'flicker':
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final flicker =
                0.65 + (0.35 * ((_ctrl.value * 10).floor().isEven ? 1 : 0));
            return Opacity(
              opacity: flicker.clamp(0.45, 1.0),
              child: Text(text, style: style, textAlign: TextAlign.center),
            );
          },
        );
      default:
        return Text(text, style: style, textAlign: TextAlign.center);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.bannerData;
    final type = d?['type'] as String?;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = widget.enableAnimations ? _ctrl.value : 0.0;
        final bgBegin = Alignment(-1 + (0.45 * t), -1 + (0.15 * t));
        final bgEnd = Alignment(1 - (0.25 * t), 1);

        return SizedBox(
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (type == 'image' &&
                  (d?['imageUrl'] as String?)?.isNotEmpty == true)
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
                        begin: bgBegin,
                        end: bgEnd,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: -40 + (8 * t),
                right: -40 + (20 * t),
                child: _blob(200, Colors.white.withValues(alpha: 0.07)),
              ),
              Positioned(
                top: 20 + (10 * (1 - t)),
                left: -50 + (12 * t),
                child: _blob(160, Colors.white.withValues(alpha: 0.05)),
              ),
              Positioned(
                bottom: 30 + (12 * (1 - t)),
                right: 60 - (18 * t),
                child: _blob(80, Colors.white.withValues(alpha: 0.04)),
              ),
              if (type == 'text' && d != null)
                Positioned.fill(
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: _textMatrixFromData(d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _animatedText(
                          (d['text'] as String?) ?? '',
                          d['fontKey'] as String?,
                          Color((d['textColor'] as int?) ?? 0xFFFFFFFF),
                          (d['fontSize'] as num?)?.toDouble() ?? 28.0,
                          widget.enableAnimations
                              ? (d['animation'] as String?) ?? 'none'
                              : 'none',
                          (d['textStyle'] as String?) ?? 'bold',
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.child != null) widget.child!,
            ],
          ),
        );
      },
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
    _FontOption(label: 'Lobster', key: 'lobster'),
    _FontOption(label: 'Raleway', key: 'raleway'),
    _FontOption(label: 'Mono', key: 'mono'),
    _FontOption(label: 'Caveat', key: 'caveat'),
    _FontOption(label: 'Satisfy', key: 'satisfy'),
    _FontOption(label: 'Righteous', key: 'righteous'),
  ];
}

class _FontOption {
  const _FontOption({required this.label, required this.key});
  final String label;
  final String key;
}
