import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/languages.dart';
import '../../contracts/models.dart';
import '../../core/data/data_revision.dart';
import '../../data/repositories/repository_providers.dart';
import 'project_data.dart';

/// Every study on this phone as a [Project] card, with its live counts.
/// Reloads after any write (see [dataRevisionProvider]).
final liveProjectsProvider = FutureProvider<List<Project>>((ref) async {
  ref.watch(dataRevisionProvider);
  final studies = await ref.watch(studyRepositoryProvider.future);
  final consents = await ref.watch(consentRepositoryProvider.future);
  final list = await studies.listStudies();
  return [
    for (final study in list)
      projectFromStudy(
        study,
        sections: await studies.getSections(study.id),
        consents: await consents.listByStudy(study.id),
      ),
  ];
});

/// Maps a study and its records to the card the screens already show.
Project projectFromStudy(
  Study study, {
  required List<ConsentSection> sections,
  required List<Consent> consents,
}) {
  final codes = <String>[];
  for (final s in sections) {
    if (!codes.contains(s.language)) codes.add(s.language);
  }
  final names = codes.map(languageName).toList();
  final published = study.formVersion > 0;
  final status = switch (study.status) {
    StudyStatus.closed => ProjectStatus.closed,
    _ when published => ProjectStatus.collecting,
    _ => ProjectStatus.draft,
  };
  final withdrew = consents.where((c) => c.withdrawnAt != null).length;
  final agreed = consents
      .where((c) => c.withdrawnAt == null && c.decision == ConsentDecision.yes)
      .length;
  final declined = consents
      .where((c) => c.withdrawnAt == null && c.decision == ConsentDecision.no)
      .length;
  return Project(
    id: study.id,
    title: study.title,
    languages: names.isEmpty ? 'No form yet' : names.join(' · '),
    status: status,
    target: 0,
    consented: agreed,
    declined: declined,
    withdrew: withdrew,
    formTitle: published
        ? 'Participant consent v${study.formVersion}'
        : (sections.isEmpty ? null : 'Draft consent form'),
    formSource: names.isEmpty ? null : names.join(' + '),
    formApproved: published
        ? 'Published · version ${study.formVersion}'
        : (sections.isEmpty ? null : 'Not published yet'),
  );
}
