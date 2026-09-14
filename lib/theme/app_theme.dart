import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFE8C840);       // yellow
  static const Color primaryDark = Color(0xFFD4B530);
  static const Color dark = Color(0xFF2C1A00);           // dark brown/black
  static const Color background = Color(0xFFF5F0E8);    // warm beige
  static const Color white = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF888888);
  static const Color cardBg = Colors.white;
  static const Color green = Color(0xFF4CAF50);
  static const Color red = Color(0xFFE53935);
  static const Color tagCancer = Color(0xFFFFE0B2);
  static const Color tagDetox = Color(0xFFE8F5E9);
  static const Color tagBorder = Color(0xFFFFCC02);
  static const Color herbGreen = Color(0xFF8B9B5A);
  static const Color starColor = Color(0xFFFFCC02);
  static const Color levelBadge = Color(0xFFFFF8E1);
  static const Color lightGreen = Color(0xFFE8F5E9);
  static const Color lightYellow = Color(0xFFFFFDE7);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
    fontFamily: 'Lato',
    letterSpacing: 0.2,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.dark,
    fontFamily: 'Lato',
    letterSpacing: 0.1,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.dark,
    fontFamily: 'Lato',
  );
  static const TextStyle body = TextStyle(
    fontSize: 13,
    color: AppColors.textPrimary,
    fontFamily: 'Lato',
    height: 1.5,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFamily: 'Lato',
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
    fontFamily: 'Lato',
  );
}

ThemeData appTheme() {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Lato',
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold),
      displayMedium: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold),
      displaySmall:  TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.bold),
      headlineMedium:TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w600),
      titleLarge:    TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w500),
      titleSmall:    TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w500),
      bodyLarge:     TextStyle(fontFamily: 'Lato', height: 1.5),
      bodyMedium:    TextStyle(fontFamily: 'Lato', height: 1.5),
      bodySmall:     TextStyle(fontFamily: 'Lato', color: AppColors.textSecondary),
      labelLarge:    TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w600),
      labelMedium:   TextStyle(fontFamily: 'Lato'),
      labelSmall:    TextStyle(fontFamily: 'Lato'),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleTextStyle: AppTextStyles.heading1,
      iconTheme: IconThemeData(color: AppColors.dark),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        textStyle: const TextStyle(fontFamily: 'Lato', fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: AppTextStyles.caption,
    ),
  );
}

// ── Prep-time display helper ──────────────────────────────────────────────────
// Rule (from product spec):
//   • null / 0              → ''            (nothing shown)
//   • value > 100 minutes   → 'see instructions'  (tinctures, salves, etc.)
//   • value ≤ 100 minutes   → '${value} min'
// The DB stores integers (minutes); this function is the single source of truth
// for how the value is presented to the user — no calculations are ever done.
String formatPrepTime(dynamic val) {
  if (val == null) return '';
  final n = val is int
      ? val
      : int.tryParse(val.toString().replaceAll(RegExp(r'\.0$'), '').trim());
  if (n == null || n == 0) return '';
  return n > 100 ? 'see instructions' : '$n min';
}
