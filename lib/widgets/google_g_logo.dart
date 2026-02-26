import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A widget that paints the official Google "G" logo using canvas arcs.
/// Works on all platforms without requiring the flutter_svg package.
class GoogleGLogo extends StatelessWidget {
  const GoogleGLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  const _GoogleGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ring radius (to center-line of stroke) and stroke width
    final ringR = size.width * 0.33;
    final sw = size.width * 0.23;

    void drawArc(double startDeg, double sweepDeg, Color color) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: ringR),
        startDeg * math.pi / 180,
        sweepDeg * math.pi / 180,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.butt,
      );
    }

    // ── Arcs (0=right, clockwise positive) ──────────────────────────────
    // Blue  : from -53° → 45° (top-right quadrant)
    drawArc(-53, 98, const Color(0xFF4285F4));
    // Green : from  45° → 90°
    drawArc(45, 48, const Color(0xFF34A853));
    // Yellow: from  93° → 135°
    drawArc(93, 45, const Color(0xFFFBBC05));
    // Red   : from 138° → 307°
    drawArc(138, 169, const Color(0xFFEA4335));

    // ── Horizontal right arm (blue) ──────────────────────────────────────
    // Goes from center to the outer-right of the ring, forming the G shape.
    final armStart = Offset(cx, cy);
    final armEnd = Offset(cx + ringR + sw * 0.55, cy);
    canvas.drawLine(
      armStart,
      armEnd,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = sw * 0.82
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
