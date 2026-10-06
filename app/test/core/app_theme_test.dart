import 'package:consentlink/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary colours support white text at AA contrast', () {
    const seeds = [
      AppColors.brand,
      Color(0xFF202D5B),
      Color(0xFFD21034),
      Color(0xFFF9B21B),
      Colors.white,
    ];

    for (final seed in seeds) {
      final theme = AppTheme.light(seed: seed);

      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    }
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
