import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedAppLanguageProvider = StateProvider<String>((ref) => 'English');

final appTextScaleProvider = StateProvider<double>((ref) => 1.0);

final readScreensAloudProvider = StateProvider<bool>((ref) => false);

final voiceAnswersProvider = StateProvider<bool>((ref) => false);

final largerTouchTargetsProvider = StateProvider<bool>((ref) => false);

/// App-wide Reduce motion (Settings 08.2), on top of the phone's own setting.
final reduceMotionPreferenceProvider = StateProvider<bool>((ref) => false);

/// Saved; applied once the Atkinson Hyperlegible font file is bundled.
final dyslexiaFontProvider = StateProvider<bool>((ref) => false);

/// Saved; applied during field capture once a wake-lock plugin is added.
final keepScreenBrightProvider = StateProvider<bool>((ref) => false);

final readAloudSpeedProvider = StateProvider<double>((ref) => 0.9);

/// Saved; applied once a screen-brightness plugin is added.
final screenBrightnessProvider = StateProvider<double>((ref) => 0.8);
