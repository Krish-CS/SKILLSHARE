import 'package:flutter/material.dart';

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
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: primaryPink,
      ),
      fontFamily: 'SourceSerif4',
      textTheme: const TextTheme(
        displayLarge:  TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.10),
        displayMedium: TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.12),
        displaySmall:  TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w600, letterSpacing: -0.5, height: 1.15),
        headlineLarge: TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.18),
        headlineMedium:TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w600, letterSpacing: -0.3, height: 1.20),
        headlineSmall: TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.22),
        titleLarge:    TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w600, letterSpacing: -0.2, height: 1.25),
        titleMedium:   TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w500, letterSpacing: -0.1, height: 1.28),
        titleSmall:    TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w500, letterSpacing: -0.1, height: 1.30),
        bodyLarge:     TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.55),
        bodyMedium:    TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.55),
        bodySmall:     TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.50),
        labelLarge:    TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w600, letterSpacing: 0.0,  height: 1.30),
        labelMedium:   TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w500, letterSpacing: 0.0,  height: 1.30),
        labelSmall:    TextStyle(fontFamily: 'SourceSerif4', fontWeight: FontWeight.w400, letterSpacing: 0.0,  height: 1.30),
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          fontFamily: 'SourceSerif4',
          letterSpacing: -0.3,
          height: 1.25,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
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
