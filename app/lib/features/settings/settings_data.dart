import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sample profile, form languages and sync numbers appear only with
/// SETTINGS_PREVIEW=true or the dashboard / projects preview flags. The
/// settings themselves (text size, contrast, read aloud, reduce motion …) are
/// real and saved on the phone.
final settingsPreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('SETTINGS_PREVIEW') ||
      const bool.fromEnvironment('DASHBOARD_PREVIEW') ||
      const bool.fromEnvironment('PROJECTS_PREVIEW'),
);

/// Profile photo (08.5), resized to 512 px. Kept only on this phone and never
/// added to consent records.
final profilePhotoProvider = StateProvider<Uint8List?>((ref) => null);

/// Researcher email (Account → Researcher details). The other details share
/// `researcherDraftProvider` with onboarding.
final researcherEmailProvider = StateProvider<String>((ref) => '');

enum Appearance {
  system('System'),
  light('Light'),
  dark('Dark');

  const Appearance(this.label);
  final String label;
}

final appearanceProvider = StateProvider<Appearance>(
  (ref) => Appearance.system,
);

enum FeedbackFrequency {
  everyForm('After every form', 1),
  everySecond('After every 2nd form', 2),
  everyThird('After every 3rd form', 3),
  random('At random (about 1 in 3)', 0),
  never('Never', -1);

  const FeedbackFrequency(this.label, this.every);
  final String label;

  /// 1, 2, 3 = every n-th form; 0 = random; -1 = never.
  final int every;
}

class FeedbackSettings {
  const FeedbackSettings({
    this.enabled = true,
    this.frequency = FeedbackFrequency.everySecond,
    this.voiceComments = true,
    this.allowHide = true,
  });
  final bool enabled;
  final FeedbackFrequency frequency;
  final bool voiceComments;
  final bool allowHide;

  /// What 08.1 shows under "Feedback pop-up".
  String get summary => !enabled || frequency == FeedbackFrequency.never
      ? 'Off'
      : frequency.label;

  FeedbackSettings copyWith({
    bool? enabled,
    FeedbackFrequency? frequency,
    bool? voiceComments,
    bool? allowHide,
  }) => FeedbackSettings(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    voiceComments: voiceComments ?? this.voiceComments,
    allowHide: allowHide ?? this.allowHide,
  );
}

final feedbackSettingsProvider = StateProvider<FeedbackSettings>(
  (ref) => const FeedbackSettings(),
);

/// Counts finished forms so "every 2nd form" can be honoured.
final completedFormsProvider = StateProvider<int>((ref) => 0);

/// Whether the pop-up should show after this form. [count] is how many forms
/// have been finished including this one.
bool feedbackDue(FeedbackSettings s, int count, {double random = 0}) {
  if (!s.enabled) return false;
  return switch (s.frequency) {
    FeedbackFrequency.never => false,
    FeedbackFrequency.random => random < 1 / 3,
    // First form, then every n-th after it (1st, 3rd, 5th … for "2nd").
    _ => (count - 1) % s.frequency.every == 0,
  };
}

enum FormLanguageStatus { on, off, review, notDownloaded, downloading }

class FormLanguage {
  const FormLanguage(this.name, this.status, {this.note});
  final String name;
  final FormLanguageStatus status;

  /// "Reviewed by J. Kavari" etc.; falls back to the status text.
  final String? note;

  String get detail =>
      note ??
      switch (status) {
        FormLanguageStatus.on => 'Ready',
        FormLanguageStatus.off => 'Turned off',
        FormLanguageStatus.review => 'Needs review',
        FormLanguageStatus.notDownloaded => 'Not downloaded',
        FormLanguageStatus.downloading => 'Downloading…',
      };

  FormLanguage withStatus(FormLanguageStatus s, {String? note}) =>
      FormLanguage(name, s, note: note);
}

/// Figma 08.3.
const sampleFormLanguages = [
  FormLanguage('English', FormLanguageStatus.on),
  FormLanguage('Afrikaans', FormLanguageStatus.on),
  FormLanguage('Deutsch', FormLanguageStatus.on),
  FormLanguage(
    'Otjiherero',
    FormLanguageStatus.on,
    note: 'Reviewed by J. Kavari',
  ),
  FormLanguage('Khoekhoegowab', FormLanguageStatus.review),
  FormLanguage('Rukwangali', FormLanguageStatus.review),
  FormLanguage('Silozi', FormLanguageStatus.notDownloaded),
  FormLanguage('Oshiwambo', FormLanguageStatus.notDownloaded),
];

/// Without the preview only English is ready; the rest still have to be
/// downloaded.
const defaultFormLanguages = [
  FormLanguage('English', FormLanguageStatus.on),
  FormLanguage('Afrikaans', FormLanguageStatus.notDownloaded),
  FormLanguage('Deutsch', FormLanguageStatus.notDownloaded),
  FormLanguage('Otjiherero', FormLanguageStatus.notDownloaded),
  FormLanguage('Khoekhoegowab', FormLanguageStatus.notDownloaded),
  FormLanguage('Rukwangali', FormLanguageStatus.notDownloaded),
  FormLanguage('Silozi', FormLanguageStatus.notDownloaded),
  FormLanguage('Oshiwambo', FormLanguageStatus.notDownloaded),
];

class FormLanguages extends StateNotifier<List<FormLanguage>> {
  FormLanguages(super.state);

  void set(String name, FormLanguageStatus status, {String? note}) => state = [
    for (final l in state)
      l.name == name ? l.withStatus(status, note: note) : l,
  ];
}

final formLanguagesProvider =
    StateNotifierProvider<FormLanguages, List<FormLanguage>>(
      (ref) => FormLanguages(
        ref.watch(settingsPreviewProvider)
            ? sampleFormLanguages
            : defaultFormLanguages,
      ),
    );

/// App languages offered on 08.3 (same list as onboarding).
const appLanguages = [
  'English',
  'Afrikaans',
  'Deutsch',
  'Otjiherero',
  'Khoekhoegowab',
  'Rukwangali',
  'Silozi',
  'Oshiwambo',
];
