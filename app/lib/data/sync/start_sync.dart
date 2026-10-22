// data/sync/start_sync.dart
// Call after the researcher signs in. Until then the app works offline only.
//
//   flutter run --dart-define=USE_REAL_SYNC=true \
//     --dart-define=POWERSYNC_URL=https://<instance>.powersync.journeyapps.com
import 'package:supabase/supabase.dart';

import '../local/open_local_database.dart';
import 'supabase_connector.dart';

const useRealSync = bool.fromEnvironment('USE_REAL_SYNC');
const powerSyncUrl = String.fromEnvironment('POWERSYNC_URL');

/// Starts syncing in the background. PowerSync keeps retrying on its own when
/// there is no signal, so this never blocks field capture.
Future<void> startSync(LocalDatabase db, SupabaseClient supabase) async {
  if (!useRealSync) return;
  if (powerSyncUrl.isEmpty) {
    throw StateError('USE_REAL_SYNC is on but POWERSYNC_URL is not set');
  }
  await db.powerSync.connect(
    connector: SupabaseConnector(
      remote: SupabaseRemote(supabase),
      local: db.drift,
      powerSyncUrl: powerSyncUrl,
    ),
  );
}

/// On sign-out: stop syncing. Local data stays (it may hold unsynced consents).
Future<void> stopSync(LocalDatabase db) => db.powerSync.disconnect();
