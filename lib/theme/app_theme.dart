import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFFF4F6F3);
  static const surface = Color(0xFFFCFDFB);
  static const surfaceSecondary = Color(0xFFE9EEEA);
  static const text = Color(0xFF17201D);
  static const muted = Color(0xFF68736F);
  static const mutedDark = Color(0xFF5E6965);
  static const line = Color(0xFFD8DFDB);
  static const accent = Color(0xFF2F6D62);
  static const accentSoft = Color(0xFFDCEAE5);
  static const error = Color(0xFFB95C52);
  static const errorSoft = Color(0xFFF3E1DE);
  static const avatarTeal = Color(0xFF4CA5A4);
  static const avatarBlue = Color(0xFF6488D8);
  static const avatarAmber = Color(0xFFD9A84B);
  static const avatarCoral = Color(0xFFDB7466);
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.accent,
        onPrimary: Colors.white,
        primaryContainer: AppColors.accentSoft,
        onPrimaryContainer: AppColors.text,
        surface: AppColors.canvas,
        surfaceContainerHighest: AppColors.surfaceSecondary,
        onSurface: AppColors.text,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.line,
        outlineVariant: AppColors.line,
        error: AppColors.error,
        errorContainer: AppColors.errorSoft,
        onErrorContainer: AppColors.text,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'sans',
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.muted,
        minimumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.surfaceSecondary,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.surface),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()},
    ),
  );
}
