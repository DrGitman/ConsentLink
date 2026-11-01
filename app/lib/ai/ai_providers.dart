import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drafting/consent_drafting_service.dart';
import 'drafting/fake_consent_drafting_service.dart';
import 'tts/flutter_tts_engine.dart';
import 'tts/read_aloud_service.dart';

/// The drafting service. Returns the fake until the on-device model is ready.
final consentDraftingServiceProvider = Provider<ConsentDraftingService>(
  (ref) => const FakeConsentDraftingService(),
);

/// Reads consent texts aloud: recording, else a local device voice, else none.
final readAloudServiceProvider = Provider<ReadAloudService>(
  (ref) => ReadAloudService(FlutterTtsEngine()),
);
