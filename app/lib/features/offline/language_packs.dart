import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../ai/language/translated_form.dart';
import '../../ai/language/translated_form_parser.dart';
import '../../contracts/languages.dart';
import '../../data/auth/auth_providers.dart';

/// A reviewed language pack on the server (view participant_language_packs:
/// ready packs, checked sections only).
class RemotePack {
  const RemotePack({
    required this.language,
    required this.version,
    required this.content,
  });
  final String language;
  final String version;
  final Map<String, dynamic> content;

  int get bytes => utf8.encode(jsonEncode(content)).length;
  int get sections => (content['sections'] as List?)?.length ?? 0;
}

Future<Directory> _packsFolder() async {
  final folder = await getApplicationSupportDirectory();
  return Directory('${folder.path}/language_packs').create(recursive: true);
}

/// Bumped after an install or removal so the screens reload.
final languagePacksRevisionProvider = StateProvider<int>((ref) => 0);

/// The newest ready pack per language on the server. Needs a signed in
/// researcher; empty when the app is built without Supabase.
final remotePacksProvider = FutureProvider<Map<String, RemotePack>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  if (client == null || client.auth.currentSession == null) return const {};
  final rows = await client
      .from('participant_language_packs')
      .select('language, version, content, created_at')
      .order('created_at', ascending: false);
  final newest = <String, RemotePack>{};
  for (final row in rows) {
    final code = row['language'] as String;
    newest.putIfAbsent(
      code,
      () => RemotePack(
        language: code,
        version: row['version'] as String,
        content: Map<String, dynamic>.from(row['content'] as Map),
      ),
    );
  }
  return newest;
});

/// Packs installed on this phone, by language code. Only sections a
/// first-language or fluent reviewer checked are ever kept.
final installedPacksProvider = FutureProvider<Map<String, TranslatedForm>>((
  ref,
) async {
  ref.watch(languagePacksRevisionProvider);
  final dir = await _packsFolder();
  final packs = <String, TranslatedForm>{};
  await for (final f in dir.list()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    try {
      final form = parseTranslatedForm(await f.readAsString());
      packs[form.languageCode] = form;
    } on LanguagePackFormatException {
      // A damaged file is ignored; downloading again replaces it.
    }
  }
  return packs;
});

Future<void> installPack(WidgetRef ref, RemotePack pack) async {
  // Parse first: a pack the app can't read is never stored.
  final text = jsonEncode(pack.content);
  parseTranslatedForm(text);
  final dir = await _packsFolder();
  await File(
    '${dir.path}/${pack.language}.json',
  ).writeAsString(text, flush: true);
  ref.read(languagePacksRevisionProvider.notifier).state++;
}

Future<void> removePack(WidgetRef ref, String code) async {
  final file = File('${(await _packsFolder()).path}/$code.json');
  if (await file.exists()) await file.delete();
  ref.read(languagePacksRevisionProvider.notifier).state++;
}

/// The reviewed text of [key] in an installed pack, or null.
TranslatedSection? reviewedSection(TranslatedForm? pack, String key) {
  if (pack == null) return null;
  for (final s in pack.participantSections) {
    if (s.element?.jsonKey == key || s.key == key) return s;
  }
  return null;
}

String languageCodeOf(String displayName) => consentLanguages
    .firstWhere(
      (l) => l.displayName == displayName,
      orElse: () => consentLanguages.first,
    )
    .code;
