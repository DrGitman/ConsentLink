import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../field_capture/field_capture_data.dart';
import '../projects/project_data.dart';

/// Figma row 10: under 18, a parent or legal guardian consents AND the young
/// person gives their own assent. A child's "No" always stops participation,
/// even if the guardian agreed. Only for projects whose ethics approval
/// covers minors.

/// Age bands (10.1). 18+ always uses the standard consent form.
enum AgeBand {
  child('7–11', 'Picture + audio assent'),
  teen('12–17', 'Simplified text assent'),
  adult('18+', 'Standard consent');

  const AgeBand(this.label, this.form);
  final String label;
  final String form;

  static AgeBand? of(int age) => age < 7
      ? null
      : age < 12
      ? AgeBand.child
      : age < 18
      ? AgeBand.teen
      : AgeBand.adult;
}

/// 10.1 Project setting — Participants.
class MinorsSettings {
  const MinorsSettings({
    this.includesMinors = false,
    this.ethicsNote,
    this.childBand = false,
    this.teenBand = true,
    this.guardianPresent = true,
    this.gatekeeper = false,
  });

  final bool includesMinors;

  /// e.g. "FCI-REC-2026-041 covers ages 12–17". Null: no approval on file.
  final String? ethicsNote;
  final bool childBand;
  final bool teenBand;
  final bool guardianPresent;

  /// School / gatekeeper permission.
  final bool gatekeeper;

  bool allows(AgeBand band) => switch (band) {
    AgeBand.adult => true,
    AgeBand.child => includesMinors && childBand,
    AgeBand.teen => includesMinors && teenBand,
  };

  MinorsSettings copyWith({
    bool? includesMinors,
    bool? childBand,
    bool? teenBand,
    bool? guardianPresent,
    bool? gatekeeper,
  }) => MinorsSettings(
    includesMinors: includesMinors ?? this.includesMinors,
    ethicsNote: ethicsNote,
    childBand: childBand ?? this.childBand,
    teenBand: teenBand ?? this.teenBand,
    guardianPresent: guardianPresent ?? this.guardianPresent,
    gatekeeper: gatekeeper ?? this.gatekeeper,
  );
}

class MinorsSettingsController
    extends StateNotifier<Map<String, MinorsSettings>> {
  MinorsSettingsController(super.state);

  void update(String projectId, MinorsSettings Function(MinorsSettings) f) =>
      state = {
        ...state,
        projectId: f(state[projectId] ?? const MinorsSettings()),
      };
}

/// Preview: the Figma project (Water access & health, FCI-REC-2026-041)
/// includes 12–17 year olds. Normal mode: no project includes minors until
/// the researcher turns it on.
final minorsSettingsProvider =
    StateNotifierProvider<
      MinorsSettingsController,
      Map<String, MinorsSettings>
    >(
      (ref) => MinorsSettingsController(
        ref.watch(projectsPreviewProvider) ||
                ref.watch(fieldCapturePreviewProvider)
            ? const {
                'water-opuwo': MinorsSettings(
                  includesMinors: true,
                  ethicsNote: 'FCI-REC-2026-041 covers ages 12–17',
                ),
              }
            : const {},
      ),
    );

/// Settings for the project being captured. Field capture opened without a
/// project (the Capture tab) has no minors settings.
MinorsSettings minorsFor(WidgetRef ref, String? projectId) =>
    ref.watch(minorsSettingsProvider)[projectId] ?? const MinorsSettings();

/// The project of a minors session: the captured project, or (preview,
/// screen opened directly) the Figma project.
String? minorsProjectId(String? projectId, bool preview) =>
    projectId ?? (preview ? 'water-opuwo' : null);

enum GuardianRelationship {
  parent('Parent'),
  legalGuardian('Legal guardian'),
  caregiver('Caregiver');

  const GuardianRelationship(this.label);
  final String label;
}

/// Figma 10.4 guardian choices (the first is consent itself).
const guardianChoices = [
  ('take_part', 'My child may take part', 'Take part'),
  ('record_voice', 'My child may be voice-recorded', 'Voice'),
  ('photos', 'Photos of my child may be used', 'Photos'),
];

enum AssentAnswer {
  yes('Yes', 'projects/check'),
  notSure('Not sure', 'consent/info'),
  no('No', 'consent/x');

  const AssentAnswer(this.label, this.icon);
  final String label;
  final String icon;
}

/// One minors session, from the age check to assent.
class MinorSession {
  const MinorSession({
    this.active = false,
    this.age,
    this.birthDate,
    this.guardianName = '',
    this.relationship = GuardianRelationship.parent,
    this.guardianPhone = '',
    this.guardianLanguage,
    this.authorityConfirmed = false,
    this.guardianReading = false,
    this.choices = const {},
    this.strokes = const [],
    this.assent,
  });

  /// True once field capture went through the age check (10.2).
  final bool active;
  final int? age;

  /// Set when the researcher entered a date of birth instead of an age.
  final DateTime? birthDate;
  final String guardianName;
  final GuardianRelationship relationship;
  final String guardianPhone;
  final String? guardianLanguage;

  /// Researcher confirms legal authority (human-only decision, logged).
  final bool authorityConfirmed;

  /// The guardian is reading the consent form (06.2 in guardian mode).
  final bool guardianReading;
  final Map<String, bool> choices;

  /// The guardian's signature ink.
  final List<List<Offset>> strokes;
  final AssentAnswer? assent;

  bool get isMinor => age != null && age! < 18;

  /// This capture is for someone under 18 (feedback is never asked).
  bool get minorCapture => active && isMinor;
  AgeBand? get band => age == null ? null : AgeBand.of(age!);
  bool get signed => strokes.fold<int>(0, (n, s) => n + s.length) > 6;
  bool get allChosen => guardianChoices.every((c) => choices[c.$1] != null);
  bool get guardianDeclined => choices['take_part'] == false;
  bool get guardianDone => allChosen && signed;
  bool get detailsDone => guardianName.trim().isNotEmpty && authorityConfirmed;

  MinorSession copyWith({
    int? Function()? age,
    DateTime? Function()? birthDate,
    String? guardianName,
    GuardianRelationship? relationship,
    String? guardianPhone,
    String? guardianLanguage,
    bool? authorityConfirmed,
    bool? guardianReading,
    Map<String, bool>? choices,
    List<List<Offset>>? strokes,
    AssentAnswer? Function()? assent,
  }) => MinorSession(
    active: active,
    age: age != null ? age() : this.age,
    birthDate: birthDate != null ? birthDate() : this.birthDate,
    guardianName: guardianName ?? this.guardianName,
    relationship: relationship ?? this.relationship,
    guardianPhone: guardianPhone ?? this.guardianPhone,
    guardianLanguage: guardianLanguage ?? this.guardianLanguage,
    authorityConfirmed: authorityConfirmed ?? this.authorityConfirmed,
    guardianReading: guardianReading ?? this.guardianReading,
    choices: choices ?? this.choices,
    strokes: strokes ?? this.strokes,
    assent: assent != null ? assent() : this.assent,
  );
}

class MinorSessionController extends StateNotifier<MinorSession> {
  /// Preview starts with the Figma values (age 14, Uerimunu Tjiuma), so
  /// screens opened directly show the design.
  MinorSessionController(this._preview)
    : super(_preview ? _sample : const MinorSession());
  final bool _preview;

  static const _sample = MinorSession(
    age: 14,
    guardianName: 'Uerimunu Tjiuma',
    guardianPhone: '+264 81 000 0000',
  );

  void start() => state = MinorSession(
    active: true,
    age: _preview ? _sample.age : null,
    guardianName: _preview ? _sample.guardianName : '',
    guardianPhone: _preview ? _sample.guardianPhone : '',
  );

  void setAge(int? age) => state = state.copyWith(
    age: () => age?.clamp(1, 120),
    birthDate: () => null,
  );

  void setBirthDate(DateTime dob, DateTime today) {
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    state = state.copyWith(age: () => age.clamp(0, 120), birthDate: () => dob);
  }

  void setGuardianName(String v) => state = state.copyWith(guardianName: v);
  void setRelationship(GuardianRelationship v) =>
      state = state.copyWith(relationship: v);
  void setPhone(String v) => state = state.copyWith(guardianPhone: v);
  void setGuardianLanguage(String v) =>
      state = state.copyWith(guardianLanguage: v);
  void setAuthority(bool v) => state = state.copyWith(authorityConfirmed: v);
  void setGuardianReading(bool v) => state = state.copyWith(guardianReading: v);
  void choose(String key, bool v) =>
      state = state.copyWith(choices: {...state.choices, key: v});
  void setStrokes(List<List<Offset>> s) => state = state.copyWith(
    strokes: [
      for (final x in s) [...x],
    ],
  );
  void setAssent(AssentAnswer? a) => state = state.copyWith(assent: () => a);
  void clear() => state = const MinorSession();
}

final minorSessionProvider =
    StateNotifierProvider<MinorSessionController, MinorSession>(
      (ref) => MinorSessionController(ref.watch(fieldCapturePreviewProvider)),
    );

/// Participant code for the minors flow: the Figma sample (P-071) in
/// preview.
String minorCode(WidgetRef ref) =>
    minorCodeOf(ref.watch(fieldCapturePreviewProvider));

/// Same as [minorCode], for callbacks (no watch).
String minorCodeOf(bool preview) => preview ? 'P-071' : 'New participant';

/// Figma 10.8 consent record for a minor.
class MinorRecord {
  const MinorRecord({
    required this.code,
    required this.age,
    required this.band,
    required this.guardianName,
    required this.relationship,
    required this.choices,
    required this.assent,
    required this.at,
    required this.recordedBy,
    required this.reconsentOn,
    this.gatekeeper = false,
    this.language = 'Otjiherero',
    this.withdrawnAt,
  });
  final String code;
  final int age;
  final AgeBand band;
  final String guardianName;
  final GuardianRelationship relationship;
  final Map<String, bool> choices;
  final AssentAnswer assent;
  final DateTime at;
  final String recordedBy;

  /// The day they turn 18: the app asks for their own consent then.
  final DateTime reconsentOn;
  final bool gatekeeper;
  final String language;
  final DateTime? withdrawnAt;

  bool get completed => assent == AssentAnswer.yes && withdrawnAt == null;

  MinorRecord withdraw(DateTime when) => MinorRecord(
    code: code,
    age: age,
    band: band,
    guardianName: guardianName,
    relationship: relationship,
    choices: choices,
    assent: assent,
    at: at,
    recordedBy: recordedBy,
    reconsentOn: reconsentOn,
    gatekeeper: gatekeeper,
    language: language,
    withdrawnAt: when,
  );
}

class MinorRecordsController extends StateNotifier<List<MinorRecord>> {
  MinorRecordsController(super.state);
  void add(MinorRecord r) => state = [
    r,
    for (final x in state)
      if (x.code != r.code) x,
  ];
  void withdraw(String code, DateTime when) =>
      state = [for (final r in state) r.code == code ? r.withdraw(when) : r];
}

/// Preview: the Figma record P-071 (age 14, 4 Oct 2026). Nothing is synced:
/// the consent record store (P2) isn't connected.
final minorRecordsProvider =
    StateNotifierProvider<MinorRecordsController, List<MinorRecord>>(
      (ref) => MinorRecordsController(
        ref.watch(fieldCapturePreviewProvider) ||
                ref.watch(projectsPreviewProvider)
            ? [
                MinorRecord(
                  code: 'P-071',
                  age: 14,
                  band: AgeBand.teen,
                  guardianName: 'Uerimunu Tjiuma',
                  relationship: GuardianRelationship.parent,
                  choices: const {
                    'take_part': true,
                    'record_voice': true,
                    'photos': false,
                  },
                  assent: AssentAnswer.yes,
                  at: DateTime(2026, 10, 4, 11, 20),
                  recordedBy: 'N. Shikongo',
                  reconsentOn: DateTime(2030, 3, 12),
                  gatekeeper: true,
                ),
              ]
            : const [],
      ),
    );

/// The day they turn 18: from the birth date, or (age only) the latest it
/// can be, counted from [from].
DateTime turns18({
  required int age,
  DateTime? birthDate,
  required DateTime from,
}) => birthDate != null
    ? DateTime(birthDate.year + 18, birthDate.month, birthDate.day)
    : DateTime(from.year + (18 - age), from.month, from.day);
