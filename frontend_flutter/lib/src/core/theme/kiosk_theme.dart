import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF163B63);
  static const primarySoft = Color(0xFFE8F0F7);
  static const teal = Color(0xFF1E8A7A);
  static const tealSoft = Color(0xFFE5F4F1);
  static const gold = Color(0xFFF4B63F);
  static const goldSoft = Color(0xFFFFF4D9);
  static const ink = Color(0xFF17212B);
  static const muted = Color(0xFF667485);
  static const line = Color(0xFFDDE6EE);
  static const surface = Color(0xFFF5F8FB);
  static const panel = Color(0xFFFFFFFF);
  static const danger = Color(0xFFD94841);
  static const dangerSoft = Color(0xFFFCE8E6);
  static const success = Color(0xFF2F8F64);
  static const successSoft = Color(0xFFE7F4ED);

  static const amityBlue = primary;
  static const amityYellow = gold;
  static const jade = teal;
  static const softSlate = surface;
  static const cardLight = panel;
  static const gradientStart = primary;
  static const gradientEnd = teal;
  static const urgentRed = danger;
  static const successGreen = success;
}

class KioskTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.gold,
      tertiary: AppColors.teal,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.ink),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.ink),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.ink),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.ink),
        bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.muted),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.panel,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: AppColors.ink, size: 26),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 58),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 58),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.line),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 15, fontWeight: FontWeight.w700),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 15),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primarySoft,
        selectedColor: AppColors.primary,
        side: const BorderSide(color: AppColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData get highContrast {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFD700), // Gold
        secondary: Color(0xFF00FFFF), // Cyan
        surface: Color(0xFF121212),
        error: Color(0xFFFF4444),
        onPrimary: Colors.black,
        onSurface: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
        headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFFFFD700)),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
        bodyLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFE0E0E0)),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Color(0xFFFFD700),
        elevation: 2,
        iconTheme: IconThemeData(color: Color(0xFFFFD700)),
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFFFD700)),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFFD700), width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFD700),
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
