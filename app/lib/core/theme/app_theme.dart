import 'package:flutter/material.dart';

abstract final class AppColors {
  static const brand = Color(0xFF1FAF84);
  static const brand600 = Color(0xFF168C69);
  static const brandDark = Color(0xFF0F6B50);
  static const brand100 = Color(0xFFC8EDDF);
  static const brand50 = Color(0xFFE7F6F0);

  static const ink = Color(0xFF111614);
  static const muted = Color(0xFF4A5450);
  static const subtle = Color(0xFF8A938F);

  static const line = Color(0xFFE4E7E5);
  static const canvas = Color(0xFFF2F3F1);
  static const surface = Colors.white;
  static const navigation = Color(0xFF141A18);

  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFE5484D);
  static const info = Color(0xFF3E7BFA);
  static const mint = Color(0xFF9FE3C9);
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
    final isDefaultBrand = seed == AppColors.brand;

    final generatedScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      contrastLevel: highContrast ? 1.0 : 0.0,
    );

    final scheme = generatedScheme.copyWith(
      primary: highContrast ? accessiblePrimary(seed) : seed.withAlpha(255),
      onPrimary: Colors.white,
      primaryContainer: isDefaultBrand
          ? AppColors.brand50
          : generatedScheme.primaryContainer,
      onPrimaryContainer: isDefaultBrand
          ? AppColors.brandDark
          : generatedScheme.onPrimaryContainer,
      surface: AppColors.surface,
      surfaceTint: Colors.transparent,
      onSurface: AppColors.ink,
      onSurfaceVariant: highContrast ? AppColors.muted : AppColors.subtle,
      outline: highContrast ? AppColors.ink : AppColors.line,
      outlineVariant: highContrast ? AppColors.muted : AppColors.line,
      error: AppColors.error,
    );

    final interactionOverlay = WidgetStateProperty.resolveWith<Color?>((
      states,
    ) {
      if (states.contains(WidgetState.pressed)) {
        return Colors.transparent;
      }

      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return scheme.primary.withAlpha(30);
      }

      return Colors.transparent;
    });

    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      shadowColor: Colors.transparent,
      applyElevationOverlayColor: false,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: highContrast ? AppColors.muted : AppColors.line,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        color: AppColors.surface,
      ),
      dialogTheme: const DialogThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
        style:
            FilledButton.styleFrom(
              minimumSize: const Size(48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: const StadiumBorder(),
            ).copyWith(
              splashFactory: NoSplash.splashFactory,
              overlayColor: interactionOverlay,
              elevation: const WidgetStatePropertyAll<double>(0),
              shadowColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              surfaceTintColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: interactionOverlay,
          elevation: const WidgetStatePropertyAll<double>(0),
          shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: interactionOverlay,
          elevation: const WidgetStatePropertyAll<double>(0),
          shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          splashFactory: NoSplash.splashFactory,
          overlayColor: interactionOverlay,
          elevation: const WidgetStatePropertyAll<double>(0),
          shadowColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: highContrast ? AppColors.muted : AppColors.line,
        thickness: 1,
      ),
    );
  }
}
