// data/local/local_database_provider.dart
// The encrypted database on this phone, opened once for the whole app.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'open_local_database.dart';

final localDatabaseProvider = FutureProvider<LocalDatabase>((ref) async {
  final db = await openLocalDatabase();
  ref.onDispose(db.close);
  return db;
});
