import 'package:flutter/material.dart';

/// Shows an animated center-screen popup instead of a bottom snackbar.
///
/// Usage:
/// ```dart
/// AppPopup.show(context, message: 'Item added to cart!', type: PopupType.success);
/// ```
enum PopupType { success, error, info, warning }

class AppPopup {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String message,
    PopupType type = PopupType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
  }) {
    // Remove any existing popup
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AnimatedPopupWidget(
        message: message,
        type: type,
        icon: icon,
        duration: duration,
        onDismiss: () {
          entry.remove();
          if (_currentEntry == entry) _currentEntry = null;
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _AnimatedPopupWidget extends StatefulWidget {
  final String message;
  final PopupType type;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AnimatedPopupWidget({
    required this.message,
    required this.type,
    this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AnimatedPopupWidget> createState() => _AnimatedPopupWidgetState();
}

class _AnimatedPopupWidgetState extends State<_AnimatedPopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor {
    switch (widget.type) {
      case PopupType.success:
        return const Color(0xFF4CAF50);
      case PopupType.error:
        return const Color(0xFFE53935);
      case PopupType.warning:
        return const Color(0xFFFF9800);
      case PopupType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData get _defaultIcon {
    switch (widget.type) {
      case PopupType.success:
        return Icons.check_circle;
      case PopupType.error:
        return Icons.error;
      case PopupType.warning:
        return Icons.warning;
      case PopupType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => _controller.reverse().then((_) => widget.onDismiss()),
        behavior: HitTestBehavior.translucent,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, child) => Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: () {}, // Prevent tapping inside from dismissing
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: _backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _backgroundColor.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon ?? _defaultIcon,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
