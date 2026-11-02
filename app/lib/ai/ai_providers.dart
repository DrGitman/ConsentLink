import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'drafting/consent_drafting_service.dart';
import 'drafting/fake_consent_drafting_service.dart';
import 'pdf/pdfrx_text_extractor.dart';
import 'pdf/proposal_text_extractor.dart';

/// The drafting service. Returns the fake until the on-device model is ready.
final consentDraftingServiceProvider = Provider<ConsentDraftingService>(
  (ref) => const FakeConsentDraftingService(),
);

/// Reads the text of an accepted proposal PDF, on the device only.
final proposalTextExtractorProvider = Provider<ProposalTextExtractor>(
  (ref) => const PdfrxTextExtractor(),
);
