import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';

final institutionSeedProvider = StateProvider<Color>((ref) => AppColors.brand);

final highContrastProvider = StateProvider<bool>((ref) => false);

final appThemeProvider = Provider<ThemeData>((ref) {
  return AppTheme.light(
    seed: ref.watch(institutionSeedProvider),
    highContrast: ref.watch(highContrastProvider),
  );
});
