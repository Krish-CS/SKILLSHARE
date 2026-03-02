import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ModernPickers {
  static Future<DateTime?> showModernDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    Color seedColor = const Color(0xFF6A11CB),
    String? helpText,
    String? confirmText,
    String? cancelText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      confirmText: confirmText,
      cancelText: cancelText,
      builder: (ctx, child) {
        final scheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        );
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: scheme,
            textTheme: GoogleFonts.loraTextTheme(Theme.of(ctx).textTheme),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFFF7F9FF),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              headerBackgroundColor: seedColor,
              headerForegroundColor: Colors.white,
              dayForegroundColor:
                  WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFFB8BCD2);
                }
                return const Color(0xFF1D2140);
              }),
              dayBackgroundColor:
                  WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedColor;
                }
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.all<Color>(seedColor),
              todayBorder: BorderSide(color: seedColor, width: 1.8),
              rangePickerBackgroundColor: const Color(0xFFF7F9FF),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: seedColor,
                textStyle: GoogleFonts.lora(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  static Future<TimeOfDay?> showModernTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    Color seedColor = const Color(0xFF6A11CB),
    String? helpText,
    String? confirmText,
    String? cancelText,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: helpText,
      confirmText: confirmText,
      cancelText: cancelText,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            textTheme: GoogleFonts.loraTextTheme(Theme.of(ctx).textTheme),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFFF7F9FF),
              hourMinuteColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedColor;
                }
                return const Color(0xFFE9ECF8);
              }),
              hourMinuteTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return const Color(0xFF22274A);
              }),
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedColor.withValues(alpha: 0.18);
                }
                return const Color(0xFFE9ECF8);
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return seedColor;
                }
                return const Color(0xFF22274A);
              }),
              dialHandColor: seedColor,
              dialBackgroundColor: const Color(0xFFEEF1FC),
              dialTextColor: const Color(0xFF2A2F52),
              entryModeIconColor: seedColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: seedColor,
                textStyle: GoogleFonts.lora(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
