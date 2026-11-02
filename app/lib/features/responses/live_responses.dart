import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/languages.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../data/repositories/repository_providers.dart';
import 'responses_data.dart';

/// Every consent stored on this phone, newest first, as list records.
/// Participants are numbered across the phone in signing order (P-001, …),
/// so a code is unique. Names are never stored.
final liveResponsesProvider = FutureProvider<List<ConsentResponse>>((
  ref,
) async {
  ref.watch(dataRevisionProvider);
  final studies = await ref.watch(studyRepositoryProvider.future);
  final consents = await ref.watch(consentRepositoryProvider.future);
  final audit = await ref.watch(auditRepositoryProvider.future);
  final all = <(m.Study, m.Consent)>[];
  final entries = <String, List<m.AuditEntry>>{};
  for (final study in await studies.listStudies()) {
    for (final c in await consents.listByStudy(study.id)) {
      all.add((study, c));
    }
    entries[study.id] = await audit.forStudy(study.id);
  }
  all.sort((a, b) => a.$2.signedAt.compareTo(b.$2.signedAt));
  final records = [
    for (final (i, (study, c)) in all.indexed)
      responseFromConsent(
        c,
        number: i + 1,
        studyTitle: study.title,
        audit: entries[study.id] ?? const [],
      ),
  ];
  return records.reversed.toList();
});

ConsentResponse responseFromConsent(
  m.Consent c, {
  required int number,
  required String studyTitle,
  List<m.AuditEntry> audit = const [],
}) {
  final status = c.withdrawnAt != null
      ? ResponseStatus.withdrew
      : c.decision == m.ConsentDecision.yes
      ? ResponseStatus.agreed
      : ResponseStatus.declined;
  final events = <AuditEvent>[
    AuditEvent(
      c.signedAt.toLocal(),
      'Consent recorded on this phone · form v${c.formVersion}',
    ),
    if (c.receivedAt != null)
      AuditEvent(c.receivedAt!.toLocal(), 'Synced to the project storage'),
    for (final e in audit.where((e) => e.entityId == c.id))
      if (e.action == m.AuditAction.consentExported)
        AuditEvent(e.createdAt.toLocal(), 'Exported as PDF'),
    if (c.withdrawnAt != null)
      AuditEvent(
        c.withdrawnAt!.toLocal(),
        'Withdrawal recorded · ${c.withdrawalReason ?? 'excluded from analysis'}',
      ),
  ]..sort((a, b) => a.time.compareTo(b.time));
  return ConsentResponse(
    number: number,
    name: 'Participant $number',
    status: status,
    at: c.signedAt.toLocal(),
    synced: c.receivedAt != null,
    language: languageName(c.language),
    site: studyTitle,
    choices: {'Take part': c.decision == m.ConsentDecision.yes},
    method: switch (c.method) {
      m.ConsentMethod.signature => 'signed',
      m.ConsentMethod.thumbprint => 'thumbprint',
      m.ConsentMethod.verbal => 'verbal',
    },
    witness: c.witnessName,
    audit: events,
    withdrawnAt: c.withdrawnAt?.toLocal(),
    consentId: c.id,
    studyId: c.studyId,
  );
}

/// Insights from the records on this phone for [period].
InsightsData liveInsights(
  InsightsPeriod period,
  List<ConsentResponse> all,
  DateTime now,
) {
  final days = switch (period) {
    InsightsPeriod.week => 7,
    InsightsPeriod.month => 30,
    InsightsPeriod.all => null,
  };
  final from = days == null
      ? (all.isEmpty
            ? now
            : all.map((r) => r.at).reduce((a, b) => a.isBefore(b) ? a : b))
      : now.subtract(Duration(days: days - 1));
  final start = DateTime(from.year, from.month, from.day);
  final records = [
    for (final r in all)
      if (!r.at.isBefore(start)) r,
  ];
  final agreed = records.where((r) => r.status == ResponseStatus.agreed).length;
  final declined = records
      .where((r) => r.status == ResponseStatus.declined)
      .length;
  final withdrew = records
      .where((r) => r.status == ResponseStatus.withdrew)
      .length;
  final synced = records.where((r) => r.synced).length;
  final total = records.length;
  String pct(int n) => total == 0 ? '0%' : '${(n * 100 / total).round()}%';

  // One bar per day (at most 30), scaled to the busiest day.
  final span =
      (DateTime(now.year, now.month, now.day).difference(start).inDays + 1)
          .clamp(1, 30)
          .toInt();
  final counts = List<int>.filled(span, 0);
  for (final r in records) {
    final d = DateTime(r.at.year, r.at.month, r.at.day);
    final i =
        span - 1 - DateTime(now.year, now.month, now.day).difference(d).inDays;
    if (i >= 0 && i < span) counts[i]++;
  }
  final peak = counts.fold<int>(0, (a, b) => a > b ? a : b);
  final byLanguage = <String, (int, int)>{};
  for (final r in records) {
    final (yes, n) = byLanguage[r.language] ?? (0, 0);
    byLanguage[r.language] = (
      yes + (r.status == ResponseStatus.agreed ? 1 : 0),
      n + 1,
    );
  }
  final languages = [
    for (final e in byLanguage.entries) (e.key, e.value.$1 / e.value.$2),
  ]..sort((a, b) => b.$2.compareTo(a.$2));
  return InsightsData(
    consented: agreed,
    goal: total,
    bars: [for (final c in counts) peak == 0 ? 0.0 : c / peak],
    from: '${shortMonths[start.month - 1]} ${start.day}',
    to: '${shortMonths[now.month - 1]} ${now.day}',
    kpis: [
      Kpi(pct(agreed), 'agreed', '$agreed of $total'),
      Kpi('$declined', 'declined', pct(declined)),
      Kpi('$withdrew', 'withdrew', pct(withdrew), warning: withdrew > 0),
      Kpi(pct(synced), 'synced', '$synced of $total', warning: synced < total),
    ],
    languages: languages.take(3).toList(),
    languageTitle: 'Agreed by language',
    goalTitle: 'Agreed of everyone asked',
  );
}
