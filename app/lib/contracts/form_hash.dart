// contracts/form_hash.dart
// Needs `crypto` in pubspec.yaml.
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'models.dart';

/// Fingerprint of an approved consent form.
///
/// Rule (everyone must use THIS function, never their own version):
/// 1. keep only approved sections
/// 2. sort by language, then by order
/// 3. each section becomes "<id>\n<text>"
/// 4. join with "\n---\n", then SHA-256 (lowercase hex)
///
/// Change one character of an approved section and the hash changes, so a
/// consent can always be proven to belong to the exact text the participant saw.
String computeFormHash(List<ConsentSection> sections) {
  final approved = sections
      .where((s) => s.status == SectionStatus.approved)
      .toList()
    ..sort((a, b) {
      final byLanguage = a.language.compareTo(b.language);
      return byLanguage != 0 ? byLanguage : a.order.compareTo(b.order);
    });
  final canonical = approved.map((s) => '${s.id}\n${s.text}').join('\n---\n');
  return sha256.convert(utf8.encode(canonical)).toString();
}
