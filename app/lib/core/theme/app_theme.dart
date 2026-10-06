import 'package:flutter/material.dart';

abstract final class AppColors {
  // App colors from the ConsentLink Figma design system we defined.
  static const brand = Color(0xFF1FAF84);
  static const brandDark = Color(0xFF0F6850);
  static const canvas = Color(0xFFF2F3F1);
  static const ink = Color(0xFF111614);
  static const muted = Color(0xFF4A5450);
  static const line = Color(0xFFE4E7E5);
  static const navigation = Color(0xFF141A18);
}

abstract final class AppTheme {
  static double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();

    final lighter = firstLuminance > secondLuminance
        ? firstLuminance
        : secondLuminance;
    final darker = firstLuminance < secondLuminance
        ? firstLuminance
        : secondLuminance;

    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color accessiblePrimary(Color seed) {
    final opaqueSeed = seed.withAlpha(255);

    // Keep the institution colour where white text has enough contrast.
    // Otherwise progressively darken it.
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(opaqueSeed, Colors.black, step / 20)!;

      if (contrastRatio(candidate, Colors.white) >= 4.5) {
        return candidate;
      }
    }

    return Colors.black;
  }

  static ThemeData light({
    Color seed = AppColors.brand,
    bool highContrast = false,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          contrastLevel: highContrast ? 1.0 : 0.0,
        ).copyWith(
          primary: accessiblePrimary(seed),
          onPrimary: Colors.white,
          surface: AppColors.canvas,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: AppColors.ink,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: AppColors.ink,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: AppColors.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.ink),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: AppColors.muted,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: const StadiumBorder(),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: highContrast ? AppColors.muted : AppColors.line,
        thickness: 1,
      ),
    );
  }
}
