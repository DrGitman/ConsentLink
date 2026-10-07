import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedAppLanguageProvider = StateProvider<String>((ref) => 'English');

final appTextScaleProvider = StateProvider<double>((ref) => 1.0);

final readScreensAloudProvider = StateProvider<bool>((ref) => false);

final voiceAnswersProvider = StateProvider<bool>((ref) => false);

final largerTouchTargetsProvider = StateProvider<bool>((ref) => false);
