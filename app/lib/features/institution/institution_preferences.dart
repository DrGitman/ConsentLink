import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';
import 'institution.dart';

final selectedInstitutionProvider = StateProvider<Institution?>((ref) => null);

final selectedResearchRoleProvider = StateProvider<ResearchRole?>(
  (ref) => null,
);

void applyInstitutionSelection(
  WidgetRef ref, {
  required Institution institution,
  required ResearchRole role,
}) {
  ref.read(selectedInstitutionProvider.notifier).state = institution;
  ref.read(selectedResearchRoleProvider.notifier).state = role;
  ref.read(institutionSeedProvider.notifier).state = institution.primary;
  ref.read(institutionAccentProvider.notifier).state = institution.accent;
}
