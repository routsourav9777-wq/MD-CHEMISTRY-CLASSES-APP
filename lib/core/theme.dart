import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF07111F);
  static const panel = Color(0xFF0D1B2A);
  static const cyan = Color(0xFF4DE7FF);
  static const blue = Color(0xFF5D7CFF);
  static const text = Color(0xFFF4F8FF);
  static const muted = Color(0xFF9CAFC5);

  static ThemeData get dark => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: cyan,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(.055),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: cyan, width: 1.4),
      ),
    ),
  );
}
