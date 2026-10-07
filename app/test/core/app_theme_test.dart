import 'package:consentlink/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('high-contrast primary colours support white text at AA contrast', () {
    const seeds = [
      AppColors.brand,
      Color(0xFF202D5B),
      Color(0xFFD21034),
      Color(0xFFF9B21B),
      Colors.white,
    ];

    for (final seed in seeds) {
      final theme = AppTheme.light(seed: seed, highContrast: true);

      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('normal theme preserves the exact ConsentLink green', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary, const Color(0xFF1FAF84));
  });

  test('normal theme separates white surfaces from the canvas', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.surface, Colors.white);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF2F3F1));
    expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF8A938F));
  });

  test('an institution seed changes the primary theme colour', () {
    final defaultTheme = AppTheme.light();
    final institutionTheme = AppTheme.light(seed: const Color(0xFF202D5B));

    expect(
      institutionTheme.colorScheme.primary,
      isNot(defaultTheme.colorScheme.primary),
    );
  });

  test('the canvas matches the ConsentLink design token', () {
    expect(AppTheme.light().scaffoldBackgroundColor, AppColors.canvas);
  });
}
