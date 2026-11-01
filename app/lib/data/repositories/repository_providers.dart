// data/repositories/repository_providers.dart
// The contracts for screens (ref.watch). With USE_REAL_SYNC: the encrypted
// database that syncs. Without: the same code on a throwaway in-memory one.
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/audit_repository.dart';
import '../../contracts/consent_repository.dart';
import '../../contracts/participant_repository.dart';
import '../../contracts/study_repository.dart';
import '../local/app_database.dart';
import '../local/local_database_provider.dart';
import '../sync/start_sync.dart' show useRealSync;
import 'drift_consent_repository.dart';
import 'drift_study_repository.dart';

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  if (useRealSync) return (await ref.watch(localDatabaseProvider.future)).drift;
  final memory = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(memory.close);
  return memory;
});

final studyRepositoryProvider = FutureProvider<StudyRepository>(
  (ref) async =>
      DriftStudyRepository(await ref.watch(appDatabaseProvider.future)),
);

final consentRepositoryProvider = FutureProvider<ConsentRepository>(
  (ref) async => DriftConsentRepository(
    await ref.watch(appDatabaseProvider.future),
    sync: useRealSync
        ? (await ref.watch(localDatabaseProvider.future)).powerSync
        : null,
  ),
);

final participantRepositoryProvider = FutureProvider<ParticipantRepository>(
  (ref) async =>
      DriftParticipantRepository(await ref.watch(appDatabaseProvider.future)),
);

final auditRepositoryProvider = FutureProvider<AuditRepository>(
  (ref) async =>
      DriftAuditRepository(await ref.watch(appDatabaseProvider.future)),
);
