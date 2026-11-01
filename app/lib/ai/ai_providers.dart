import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drafting/consent_drafting_service.dart';
import 'drafting/fake_consent_drafting_service.dart';

/// The drafting service. Returns the fake until the on-device model is ready.
final consentDraftingServiceProvider = Provider<ConsentDraftingService>(
  (ref) => const FakeConsentDraftingService(),
);
