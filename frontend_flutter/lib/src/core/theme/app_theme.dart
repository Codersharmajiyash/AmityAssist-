import 'package:flutter/material.dart';

import 'kiosk_theme.dart';

/// App theme delegate — uses kiosk-grade premium themes.
class AppTheme {
  static ThemeData get light => KioskTheme.light;
  static ThemeData get dark => KioskTheme.dark;
}
