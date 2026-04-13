import 'package:flutter/material.dart';
import 'app_fonts.dart';

class AppTheme {
  // Colors from the UI reference
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryPink = Color(0xFFE91E63);
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color primaryPurple = Color(0xFF9C27B0);
  static const Color accentGreen = Color(0xFF4CAF50);

  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryPink, primaryOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF2196F3), Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    // Always use bundled app fonts for consistent rendering and offline safety.
    final baseTextTheme = ThemeData.light(useMaterial3: true).textTheme;
    final loraTextTheme = AppFonts.loraTextTheme(baseTextTheme);

    final appBarTitleStyle = AppFonts.lora(
      color: textPrimary,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.25,
    );

    final buttonTextStyle = AppFonts.lora(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: primaryPink,
      ),
      textTheme: loraTextTheme,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: appBarTitleStyle,
      ),
      cardTheme: CardThemeData(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: buttonTextStyle,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: buttonTextStyle,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppFonts.lora(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }
}
