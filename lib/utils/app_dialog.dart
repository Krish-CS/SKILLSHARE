import 'package:flutter/material.dart';

/// Centralised animated dialogs — replaces SnackBars app-wide.
///
/// Usage:
///   AppDialog.success(context, 'Profile saved!');
///   AppDialog.error(context, 'Something went wrong', detail: e.toString());
///   AppDialog.info(context, 'Please select a category first');
class AppDialog {
  AppDialog._();

  // ─── Success ─────────────────────────────────────────────────────────────

  static Future<void> success(
    BuildContext context,
    String message, {
    String? title,
    String buttonText = 'Great!',
    VoidCallback? onDismiss,
  }) {
    return _show(
      context,
      title: title ?? 'Success',
      message: message,
      buttonText: buttonText,
      gradientColors: const [Color(0xFF43A047), Color(0xFF00ACC1)],
      icon: Icons.check_circle_rounded,
      onDismiss: onDismiss,
    );
  }

  // ─── Error ────────────────────────────────────────────────────────────────

  static Future<void> error(
    BuildContext context,
    String message, {
    String? title,
    String? detail,
    String buttonText = 'Got it',
  }) {
    final body = detail != null && detail.isNotEmpty
        ? '$message\n\n$detail'
        : message;
    return _show(
      context,
      title: title ?? 'Oops!',
      message: body,
      buttonText: buttonText,
      gradientColors: const [Color(0xFFE53935), Color(0xFFFF6F61)],
      icon: Icons.error_outline_rounded,
    );
  }

  // ─── Info / Warning ───────────────────────────────────────────────────────

  static Future<void> info(
    BuildContext context,
    String message, {
    String? title,
    String buttonText = 'OK',
  }) {
    return _show(
      context,
      title: title ?? 'Heads up',
      message: message,
      buttonText: buttonText,
      gradientColors: const [Color(0xFFF57C00), Color(0xFFFFB300)],
      icon: Icons.info_outline_rounded,
    );
  }

  // ─── Core builder ─────────────────────────────────────────────────────────

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required String message,
    required String buttonText,
    required List<Color> gradientColors,
    required IconData icon,
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.82, end: 1.0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, color: Colors.white, size: 42),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Message ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                ),
              ),
              // ── Button ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: gradientColors[0],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDismiss?.call();
                    },
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
