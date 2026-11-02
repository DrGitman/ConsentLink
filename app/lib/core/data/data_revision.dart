import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after every write to the local database (new study, saved section,
/// signed consent, withdrawal). Screens that read live data watch it, so they
/// reload right after a change instead of waiting for a restart.
final dataRevisionProvider = StateProvider<int>((ref) => 0);
