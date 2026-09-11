import 'package:flutter/material.dart';

/// Desktop console theme — dense, not the patient-facing branding.
class PortalTheme {
  static const navy = Color(0xFF1B2A4A);
  static const navyDark = Color(0xFF121C33);
  static const surface = Color(0xFFF4F6F8);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2933);
  static const muted = Color(0xFF5F6B7A);
  static const line = Color(0xFFD5DDE5);
  static const pending = Color(0xFFB45309);
  static const approved = Color(0xFF0F7B5A);
  static const rejected = Color(0xFFB42318);
  static const needsChanges = Color(0xFF6941C6);
  static const overdue = Color(0xFFB42318);

  static ThemeData get data {
    const scheme = ColorScheme.light(
      primary: navy,
      onPrimary: Colors.white,
      secondary: Color(0xFF0F7B5A),
      onSecondary: Colors.white,
      surface: card,
      onSurface: ink,
      error: rejected,
      onError: Colors.white,
      outline: line,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      visualDensity: VisualDensity.compact,
      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: navyDark,
        selectedIconTheme: IconThemeData(color: Colors.white),
        unselectedIconTheme: IconThemeData(color: Color(0xFF9AA5B4)),
        selectedLabelTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: Color(0xFF9AA5B4),
          fontSize: 12,
        ),
        indicatorColor: Color(0xFF2E4270),
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(Color(0xFFEEF2F6)),
        headingTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
        dataTextStyle: TextStyle(fontSize: 13, color: ink),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
