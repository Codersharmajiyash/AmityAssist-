import 'package:flutter/material.dart';

class AppTheme {
  static const _blue = Color(0xFF1B325D);
  static const _yellow = Color(0xFFFFCB05);
  static const _green = Color(0xFF2F9C7F);

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        primary: _blue,
        secondary: _yellow,
        tertiary: _green,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF4F7FA),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _blue,
        brightness: Brightness.dark,
        primary: _yellow,
        secondary: _green,
      ),
      useMaterial3: true,
    );
  }
}
