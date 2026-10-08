import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/institution/institution.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final institution in Institution.values) {
    test('${institution.label} keeps its specified palette', () {
      final theme = AppTheme.light(
        seed: institution.primary,
        accent: institution.accent,
      );

      expect(theme.colorScheme.primary, institution.primary);
      expect(theme.colorScheme.secondary, institution.accent);
      expect(theme.scaffoldBackgroundColor, AppColors.canvas);
      expect(
        AppTheme.contrastRatio(
          theme.colorScheme.secondary,
          theme.colorScheme.onSecondary,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
