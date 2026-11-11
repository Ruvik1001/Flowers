import 'package:flutter/material.dart';

class AppColors {
  static const leaf = Color(0xFF2A5A4A);
  static const leafDark = Color(0xFF17382F);
  static const leafSoft = Color(0xFF3F7564);
  static const blush = Color(0xFFD08490);
  static const blushSoft = Color(0xFFE8B4BC);
  static const paper = Color(0xFFF6F1E8);
  static const mist = Color(0xFFE8E2D6);
  static const ink = Color(0xFF0B100E);
  static const muted = Color(0xFF1C2622);
  static const success = Color(0xFF2F6B4D);
  static const warning = Color(0xFF9A6A28);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const outline = Color(0xFFC8C1B4);
}

class AppRadii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
}

List<BoxShadow> softShadow({double opacity = 0.08}) => [
      BoxShadow(
        color: AppColors.leafDark.withValues(alpha: opacity),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ];

ThemeData buildAppTheme() {
  const displayFamily = 'Fraunces';
  const bodyFamily = 'Source Sans 3';

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: bodyFamily,
  );

  final textTheme = base.textTheme.copyWith(
    displayLarge: const TextStyle(
      fontFamily: displayFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      letterSpacing: -0.5,
      fontSize: 40,
    ),
    displayMedium: const TextStyle(
      fontFamily: displayFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      fontSize: 32,
    ),
    headlineLarge: const TextStyle(
      fontFamily: displayFamily,
      color: AppColors.leafDark,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      fontSize: 34,
      height: 1.15,
    ),
    headlineMedium: const TextStyle(
      fontFamily: displayFamily,
      color: AppColors.leafDark,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      fontSize: 22,
    ),
    titleLarge: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      fontSize: 18,
    ),
    titleMedium: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      fontSize: 17,
    ),
    bodyLarge: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
      fontSize: 16,
      height: 1.4,
    ),
    bodyMedium: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
      fontSize: 15,
      height: 1.4,
    ),
    bodySmall: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w600,
      fontVariations: [FontVariation('wght', 600)],
      fontSize: 14,
      height: 1.35,
    ),
    labelLarge: const TextStyle(
      fontFamily: bodyFamily,
      color: AppColors.ink,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      letterSpacing: 0.2,
      fontSize: 14,
    ),
    labelMedium: const TextStyle(
      fontFamily: bodyFamily,
      fontWeight: FontWeight.w700,
      fontVariations: [FontVariation('wght', 700)],
      color: AppColors.ink,
      fontSize: 13,
    ),
  );

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.leaf,
    brightness: Brightness.light,
    primary: AppColors.leaf,
    onPrimary: Colors.white,
    secondary: AppColors.blush,
    onSecondary: Colors.white,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerHighest: AppColors.mist,
    outline: AppColors.outline,
    error: const Color(0xFFB3261E),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    fontFamily: bodyFamily,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.leafDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.leafDark),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: AppColors.leaf.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 74,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: bodyFamily,
          fontSize: 12,
          height: 1.15,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          color: selected ? AppColors.leafDark : AppColors.ink,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.leaf : AppColors.ink,
          size: 24,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.leafDark,
      unselectedLabelColor: AppColors.ink,
      indicatorColor: AppColors.leaf,
      dividerColor: Colors.transparent,
      labelStyle: textTheme.labelLarge,
      unselectedLabelStyle: textTheme.labelMedium,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.leaf,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.leafDark,
        side: const BorderSide(color: AppColors.outline),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.leafDark,
        textStyle: textTheme.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.leaf,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevated.withValues(alpha: 0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        borderSide: const BorderSide(color: AppColors.leaf, width: 1.5),
      ),
      labelStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceElevated.withValues(alpha: 0.88),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.55)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceElevated,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      titleTextStyle: textTheme.headlineMedium,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.mist,
      selectedColor: AppColors.leaf.withValues(alpha: 0.16),
      labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.leafDark),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide.none,
      ),
      side: BorderSide.none,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.leafDark,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceElevated,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.leaf,
      textColor: AppColors.ink,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
    ),
  );
}
