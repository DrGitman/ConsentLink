// data/auth/auth_providers.dart
// Real sign-in is on when the app is built with the Supabase project:
//   --dart-define=SUPABASE_URL=https://<project>.supabase.co
//   --dart-define=SUPABASE_ANON_KEY=<publishable key>
// Without them the auth screens keep their preview behaviour.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import '../local/database_key.dart';
import '../local/local_database_provider.dart';
import '../sync/start_sync.dart';
import 'auth_service.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const realAuthConfigured = supabaseUrl != '' && supabaseAnonKey != '';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!realAuthConfigured) return null;
  final client = SupabaseClient(
    supabaseUrl,
    supabaseAnonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Null when the app is built without the Supabase project.
final authServiceProvider = Provider<AuthService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return AuthService(
    SupabaseAuthGateway(client, SecureKeyStore()),
    onSignedIn: () async {
      if (!useRealSync) return;
      await startSync(await ref.read(localDatabaseProvider.future), client);
    },
    onSignedOut: () async {
      final db = ref.read(localDatabaseProvider).valueOrNull;
      if (db != null) await stopSync(db);
    },
  );
});

/// Watched once at app start: signs back in with the login saved on the phone.
final sessionRestoreProvider = FutureProvider<bool>(
  (ref) async => await ref.watch(authServiceProvider)?.restore() ?? false,
);
