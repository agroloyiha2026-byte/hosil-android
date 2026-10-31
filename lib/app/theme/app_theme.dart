import 'package:flutter/material.dart';

class AppColors {
  static const forest = Color(0xFF245C36);
  static const deepForest = Color(0xFF173F2D);
  static const green = Color(0xFF3F7D3A);
  static const pale = Color(0xFFE7F0DF);
  static const cream = Color(0xFFF5F2E8);
  static const gold = Color(0xFFD9B66F);
  static const secondaryText = Color(0xFF62715F);
  static const text = Color(0xFF26332A);
  // Dark mode
  static const darkBg = Color(0xFF0F1711);
  static const darkCard = Color(0xFF18231B);
  static const darkGreen = Color(0xFF5FA85A);
  static const darkText = Color(0xFFE8F0E8);
  static const headerDark = Color(0xFF1B3A26);
  static const navDark = Color(0xFF173F2D);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.light).copyWith(
      primary: AppColors.forest, onPrimary: Colors.white, secondary: AppColors.gold,
      surface: Colors.white, onSurface: AppColors.text, primaryContainer: AppColors.pale,
      onPrimaryContainer: AppColors.forest, onSurfaceVariant: AppColors.secondaryText);
    return _base(scheme, AppColors.cream, AppColors.deepForest);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.green, brightness: Brightness.dark).copyWith(
      primary: AppColors.darkGreen, onPrimary: const Color(0xFF0C170E), secondary: AppColors.gold,
      surface: AppColors.darkCard, onSurface: AppColors.darkText,
      primaryContainer: const Color(0xFF203024), onPrimaryContainer: AppColors.darkText,
      onSurfaceVariant: const Color(0xFFB0BDB0));
    return _base(scheme, AppColors.darkBg, AppColors.headerDark);
  }

  static ThemeData _base(ColorScheme s, Color bg, Color header) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      colorScheme: s,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: header, foregroundColor: Colors.white, elevation: 0, scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), actionsIconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
        toolbarHeight: 56,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: shape,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), shape: shape,
            side: BorderSide(color: s.primary, width: 1.5),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.onSurface.withValues(alpha: 0.16)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: s.primary, width: 1.5),
        ),
      ),
      textTheme: ThemeData(brightness: s.brightness).textTheme.apply(bodyColor: s.onSurface, displayColor: s.onSurface),
    );
  }
}
