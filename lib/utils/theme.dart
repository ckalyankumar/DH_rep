import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const primaryColor = Color(0xFF3498DB);
  static const primary = Color(0xFF1A6B5A);
  static const primaryDark = Color(0xFF2980B9);
  static const primaryLight = Color(0xFF2E9B82);
  static const wearableBlue = Color(0xFF4A8AC4);
  static const accentColor = Color(0xFF27AE60);
  static const warningColor = Color(0xFFF39C12);
  static const dangerColor = Color(0xFFE74C3C);
  static const backgroundColor = Color(0xFFF8F9FA);
  static const surfaceColor = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF5F7F6);
  static const textPrimaryColor = Color(0xFF2C3E50);
  static const textSecondaryColor = Color(0xFF6C757D);
  static const textSecondary = Color(0xFF6C757D);
  static const textMuted = Color(0xFF9CA3AF);
  static const borderColor = Color(0xFFDEE2E6);
  // Wearable / risk gauge colors
  static const sleep = Color(0xFF3498DB);
  static const hrvPurple = Color(0xFF8B5CF6);
  static const riskLow = Color(0xFF27AE60);
  static const riskMed = Color(0xFFF39C12);
  static const riskHigh = Color(0xFFE74C3C);
  static const terracotta = Color(0xFFE8825A);

  static const _colorSchemeLight = ColorScheme.light(
    primary: Color(0xFF1A6B5A),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFE8825A),
    onSecondary: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF2C3E50),
    error: Color(0xFFB84040),
    onError: Color(0xFFFFFFFF),
    outline: borderColor,
    surfaceContainerHighest: Color(0xFFD5DDD9),
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: _colorSchemeLight,
      primaryColor: _colorSchemeLight.primary,
      scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A6B5A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF1A6B5A),
        unselectedItemColor: Color(0xFF8AA69B),
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: _colorSchemeLight.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F7F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A6B5A), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _colorSchemeLight.primary,
          foregroundColor: _colorSchemeLight.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: _colorSchemeLight.primary,
        inactiveTrackColor: const Color(0xFFD5DDD9),
        thumbColor: _colorSchemeLight.primary,
        overlayColor: _colorSchemeLight.primary.withValues(alpha: 0.16),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _colorSchemeLight.primary;
          }
          return _colorSchemeLight.surface;
        }),
        checkColor: WidgetStateProperty.all(_colorSchemeLight.onPrimary),
        side: const BorderSide(color: Color(0xFF1A6B5A), width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.all(_colorSchemeLight.primary),
      ),
      chipTheme: ChipThemeData(
        selectedColor: _colorSchemeLight.primary.withValues(alpha: 0.16),
        checkmarkColor: _colorSchemeLight.primary,
        labelStyle: const TextStyle(color: textPrimaryColor),
        secondaryLabelStyle: const TextStyle(color: textPrimaryColor),
        side: const BorderSide(color: borderColor),
        backgroundColor: _colorSchemeLight.surface,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: textPrimaryColor,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
          color: textPrimaryColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondaryColor,
        ),
        headlineSmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 14,
        ),
      ),
    );
  }

  /// Unused until a dedicated dark theme is designed. MaterialApp is locked
  /// to [lightTheme] via ThemeMode.light so this is not applied.
  static ThemeData get darkTheme {
    final darkScheme = ColorScheme.dark(
      primary: const Color(0xFF1A6B5A),
      secondary: const Color(0xFFE8825A),
      surface: const Color(0xFF262626),
      error: const Color(0xFFB84040),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      primaryColor: darkScheme.primary,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A6B5A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Fraunces',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkScheme.surface,
        selectedItemColor: const Color(0xFF1A6B5A),
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: darkScheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fraunces(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.6,
          color: Colors.white,
        ),
        labelMedium: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.02,
          color: Colors.white70,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
