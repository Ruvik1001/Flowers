import 'package:flutter/material.dart';

class AppColors {
  static const leaf = Color(0xFF2F5D50);
  static const leafDark = Color(0xFF1E3D35);
  static const blush = Color(0xFFC97884);
  static const paper = Color(0xFFF3EEE6);
  static const mist = Color(0xFFE7E1D6);
  static const ink = Color(0xFF1C2421);
  static const muted = Color(0xFF5E6B66);
}

ThemeData buildAppTheme() {
  const baseText = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'serif',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.leafDark,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'serif',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.leafDark,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.ink),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink),
    labelMedium: TextStyle(fontWeight: FontWeight.w600),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.leaf,
    brightness: Brightness.light,
    primary: AppColors.leaf,
    secondary: AppColors.blush,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: baseText,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.leafDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        color: AppColors.leafDark,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.mist,
      indicatorColor: AppColors.leaf.withValues(alpha: 0.18),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.leaf,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.mist),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.55),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.leafDark,
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
