import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/preferences/accessibility_preferences.dart';
import 'app_theme.dart';

final institutionSeedProvider = StateProvider<Color>((ref) => AppColors.brand);

final institutionAccentProvider = StateProvider<Color>(
  (ref) => AppColors.brandDark,
);

final highContrastProvider = StateProvider<bool>((ref) => false);

final appThemeProvider = Provider<ThemeData>((ref) {
  return AppTheme.light(
    seed: ref.watch(institutionSeedProvider),
    accent: ref.watch(institutionAccentProvider),
    highContrast: ref.watch(highContrastProvider),
    largerTouchTargets: ref.watch(largerTouchTargetsProvider),
  );
});
