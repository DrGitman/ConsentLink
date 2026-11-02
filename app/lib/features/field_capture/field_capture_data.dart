import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/languages.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../data/repositories/repository_providers.dart';
import '../new_consent/consent_draft_data.dart';
import '../projects/project_data.dart';
import '../responses/live_responses.dart';

/// Sample participant, consent text and questions appear only with
/// FIELD_CAPTURE_PREVIEW=true or the existing preview flags. Nothing is synced:
/// the consent record store (P2) and the recorded voice packs are not
/// connected yet, so read-aloud, thumbprint and "Say it" are simulated.
final fieldCapturePreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('FIELD_CAPTURE_PREVIEW') ||
      ref.watch(newConsentPreviewProvider),
);

enum ConsentMethod {
  sign('Sign', 'form/sign'),
  thumbprint('Thumbprint', 'form/fingerprint'),
  verbal('Say it', 'mic');

  const ConsentMethod(this.label, this.icon);
  final String label;
  final String icon;

  /// Figma 06.5: a witness is required for thumbprint and verbal consent.
  bool get needsWitness => this != ConsentMethod.sign;
}

class CaptureParticipant {
  const CaptureParticipant({
    required this.code,
    required this.name,
    required this.project,
    required this.site,
    required this.isMinor,
  });
  final String code;
  final String name;
  final String project;
  final String site;
  final bool isMinor;

  String get firstName => name.split(' ').first;
}

class ConsentReadSection {
  const ConsentReadSection({
    required this.title,
    required this.question,
    required this.sentences,
  });
  final String title;
  final String question;
  final List<String> sentences;
}

class CaptureQuestion {
  const CaptureQuestion({
    required this.id,
    required this.question,
    required this.helper,
  });
  final String id;
  final String question;
  final String helper;
}

class ConsentChoice {
  const ConsentChoice({required this.key, required this.label});
  final String key;
  final String label;
}

const captureLanguages = [
  'Otjiherero',
  'Ju/\'hoansi',
  'English',
  'Afrikaans',
  'Oshiwambo',
];

const sampleParticipant = CaptureParticipant(
  code: 'P-065',
  name: 'Kaera Tjiuma',
  project: 'Water access & health',
  site: 'Opuwo',
  isMinor: false,
);

/// The approved consent text, one plain question per section (Figma 06.2).
const sampleReadSections = [
  ConsentReadSection(
    title: 'About the study',
    question: 'What is this study about?',
    sentences: [
      'We want to learn how families get clean water.',
      'We also ask how water affects your health.',
      'The study is run by NUST.',
    ],
  ),
  ConsentReadSection(
    title: 'What you will do',
    question: 'What will I do?',
    sentences: [
      'You will answer some questions.',
      'We will talk for about 40 minutes.',
      'You can answer by voice or by typing.',
    ],
  ),
  ConsentReadSection(
    title: 'Risks',
    question: 'Is there any risk to me?',
    sentences: [
      'You may feel tired during the interview.',
      'It takes about 40 minutes.',
      'You can rest or stop at any time.',
      'Stopping will not cause you any problem.',
    ],
  ),
  ConsentReadSection(
    title: 'Benefits',
    question: 'Will this help me?',
    sentences: [
      'You will not be paid.',
      'Your answers may help improve water services in your area.',
    ],
  ),
  ConsentReadSection(
    title: 'Privacy',
    question: 'Who will see my answers?',
    sentences: [
      'Only the research team will see your answers.',
      'Your name is never written next to your answers.',
      'Everything is stored safely on this phone until it is sent.',
    ],
  ),
  ConsentReadSection(
    title: 'Your choice',
    question: 'Do I have to take part?',
    sentences: [
      'No. Taking part is your choice.',
      'You can say no now or stop later.',
      'Saying no will not change how you are treated.',
    ],
  ),
  ConsentReadSection(
    title: 'Recording',
    question: 'Will you record me?',
    sentences: [
      'Only if you say yes on the next screens.',
      'Recordings are kept safe and deleted after the study.',
    ],
  ),
  ConsentReadSection(
    title: 'Contacts',
    question: 'Who can I talk to?',
    sentences: [
      'You can ask the researcher any question now.',
      'You can also call the NUST ethics office.',
      'Their number is on the paper copy you will get.',
    ],
  ),
];

/// Answer questions (Figma 06.3 shows question 2 of 4).
const sampleQuestions = [
  CaptureQuestion(
    id: 'village',
    question: 'Where do you live?',
    helper: 'Your village or area is enough.',
  ),
  CaptureQuestion(
    id: 'name',
    question: 'What is your name?',
    helper: 'You can also use a nickname. We will not share it.',
  ),
  CaptureQuestion(
    id: 'household',
    question: 'How many people live in your home?',
    helper: 'Count everyone who sleeps there most nights.',
  ),
  CaptureQuestion(
    id: 'water',
    question: 'Where do you get water?',
    helper: 'For example a tap, a borehole or a river.',
  ),
];

/// Figma 06.4. The first choice is consent itself.
const consentChoices = [
  ConsentChoice(key: 'take_part', label: 'I agree to take part in this study'),
  ConsentChoice(key: 'record_voice', label: 'You may record my voice'),
  ConsentChoice(key: 'quote', label: 'You may quote me (no name)'),
  ConsentChoice(key: 'contact_again', label: 'You may contact me again later'),
];

const feedbackFaces = [
  ('capture/face_very_hard', 'Very hard'),
  ('capture/face_hard', 'Hard'),
  ('capture/face_ok', 'OK'),
  ('capture/face_easy', 'Easy'),
  ('capture/face_very_easy', 'Very easy'),
];

const feedbackTags = ['Too long', 'Unclear', 'Voice helped'];

class CaptureSession {
  const CaptureSession({
    this.projectId,
    this.language = 'Otjiherero',
    this.readAloud = true,
    this.largeText = true,
    this.interpreter = false,
    this.section = 0,
    this.question = 0,
    this.answers = const {},
    this.choices = const {},
    this.method = ConsentMethod.sign,
    this.signed = false,
    this.thumbCaptured = false,
    this.verbalSeconds = 0,
    this.witness,
    this.completedAt,
  });

  final String? projectId;
  final String language;
  final bool readAloud;
  final bool largeText;
  final bool interpreter;
  final int section;
  final int question;
  final Map<String, String> answers;
  final Map<String, bool> choices;
  final ConsentMethod method;
  final bool signed;
  final bool thumbCaptured;
  final int verbalSeconds;
  final String? witness;
  final DateTime? completedAt;

  bool get allChosen => consentChoices.every((c) => choices[c.key] != null);
  bool get declined => choices['take_part'] == false;

  bool get captured => switch (method) {
    ConsentMethod.sign => signed,
    ConsentMethod.thumbprint => thumbCaptured,
    ConsentMethod.verbal => verbalSeconds > 0,
  };

  bool get canFinish => captured && (!method.needsWitness || witness != null);

  CaptureSession copyWith({
    String? projectId,
    String? language,
    bool? readAloud,
    bool? largeText,
    bool? interpreter,
    int? section,
    int? question,
    Map<String, String>? answers,
    Map<String, bool>? choices,
    ConsentMethod? method,
    bool? signed,
    bool? thumbCaptured,
    int? verbalSeconds,
    String? Function()? witness,
    DateTime? completedAt,
  }) => CaptureSession(
    projectId: projectId ?? this.projectId,
    language: language ?? this.language,
    readAloud: readAloud ?? this.readAloud,
    largeText: largeText ?? this.largeText,
    interpreter: interpreter ?? this.interpreter,
    section: section ?? this.section,
    question: question ?? this.question,
    answers: answers ?? this.answers,
    choices: choices ?? this.choices,
    method: method ?? this.method,
    signed: signed ?? this.signed,
    thumbCaptured: thumbCaptured ?? this.thumbCaptured,
    verbalSeconds: verbalSeconds ?? this.verbalSeconds,
    witness: witness != null ? witness() : this.witness,
    completedAt: completedAt ?? this.completedAt,
  );
}

class CaptureSessionController extends StateNotifier<CaptureSession> {
  CaptureSessionController(this._ref) : super(const CaptureSession());
  final Ref _ref;

  void start({String? projectId}) =>
      state = CaptureSession(projectId: projectId);

  void setLanguage(String value) => state = state.copyWith(language: value);
  void setReadAloud(bool value) => state = state.copyWith(readAloud: value);
  void setLargeText(bool value) => state = state.copyWith(largeText: value);
  void setInterpreter(bool value) => state = state.copyWith(interpreter: value);

  void goToSection(int index) {
    final count = _ref.read(readSectionsProvider).length;
    state = state.copyWith(section: count == 0 ? 0 : index.clamp(0, count - 1));
  }

  void goToQuestion(int index) => state = state.copyWith(
    question: index.clamp(0, sampleQuestions.length - 1),
  );

  void answer(String id, String text) =>
      state = state.copyWith(answers: {...state.answers, id: text});

  void choose(String key, bool value) =>
      state = state.copyWith(choices: {...state.choices, key: value});

  void setMethod(ConsentMethod value) => state = state.copyWith(method: value);
  void setSigned(bool value) => state = state.copyWith(signed: value);
  void setThumbCaptured(bool value) =>
      state = state.copyWith(thumbCaptured: value);
  void setVerbalSeconds(int value) =>
      state = state.copyWith(verbalSeconds: value);
  void setWitness(String? name) => state = state.copyWith(witness: () => name);

  void complete() => state = state.copyWith(completedAt: DateTime.now());
}

final captureSessionProvider =
    StateNotifierProvider<CaptureSessionController, CaptureSession>(
      (ref) => CaptureSessionController(ref),
    );

/// Preview: the sample participant. Live: the next participant number of the
/// project being captured. Names are never stored, only the code.
final captureParticipantProvider = Provider<CaptureParticipant?>((ref) {
  if (ref.watch(fieldCapturePreviewProvider)) return sampleParticipant;
  final id = ref.watch(captureSessionProvider.select((s) => s.projectId));
  if (id == null) return null;
  final project = ref
      .watch(projectsProvider)
      .where((p) => p.id == id)
      .firstOrNull;
  if (project == null) return null;
  // Numbered across the phone, the same way the responses list numbers them.
  final n = (ref.watch(liveResponsesProvider).valueOrNull?.length ?? 0) + 1;
  return CaptureParticipant(
    code: 'P-${n.toString().padLeft(3, '0')}',
    name: 'Participant $n',
    project: project.title,
    site: project.languages,
    isMinor: false,
  );
});

/// The published form of a study, as the plain sections participants read.
final publishedReadSectionsProvider =
    FutureProvider.family<List<m.ConsentSection>, String>((ref, studyId) async {
      ref.watch(dataRevisionProvider);
      final studies = await ref.watch(studyRepositoryProvider.future);
      return studies.getPublishedSections(studyId);
    });

/// The language the participant's text is shown (and read aloud) in: the
/// chosen language when the published form has it, else English, else the
/// form's own language. The preview sample is English.
final readLanguageCodeProvider = Provider<String>((ref) {
  if (ref.watch(fieldCapturePreviewProvider)) return 'en';
  final session = ref.watch(captureSessionProvider);
  final id = session.projectId;
  if (id == null) return 'en';
  final all =
      ref.watch(publishedReadSectionsProvider(id)).valueOrNull ?? const [];
  final wanted = languageCodeForName(session.language);
  final codes = completeLanguages(all);
  if (codes.isEmpty || codes.contains(wanted)) return wanted;
  return codes.contains('en') ? 'en' : codes.first;
});

/// What the participant reads: the sample in preview, otherwise the published
/// form of the project in [readLanguageCodeProvider].
final readSectionsProvider = Provider<List<ConsentReadSection>>((ref) {
  if (ref.watch(fieldCapturePreviewProvider)) return sampleReadSections;
  final id = ref.watch(captureSessionProvider.select((s) => s.projectId));
  if (id == null) return const [];
  final all =
      ref.watch(publishedReadSectionsProvider(id)).valueOrNull ?? const [];
  final language = ref.watch(readLanguageCodeProvider);
  final sections = all.where((s) => s.language == language).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return [for (final s in sections) readSectionFrom(s)];
});

/// True when the text the participant reads is an AI translation no fluent
/// speaker has checked yet (allowed for now; shown to the researcher).
final readTextUncheckedProvider = Provider<bool>((ref) {
  if (ref.watch(fieldCapturePreviewProvider)) return false;
  final id = ref.watch(captureSessionProvider.select((s) => s.projectId));
  if (id == null) return false;
  final language = ref.watch(readLanguageCodeProvider);
  final all =
      ref.watch(publishedReadSectionsProvider(id)).valueOrNull ?? const [];
  return all.any(
    (s) =>
        s.language == language &&
        s.changes.any((c) => c.startsWith('AI translation')),
  );
});

/// Languages the published form has in full: every element of the main
/// language has a checked text in it. A half translated form never reaches
/// a participant.
Set<String> completeLanguages(List<m.ConsentSection> all) {
  final byLanguage = <String, Set<String>>{};
  for (final s in all) {
    byLanguage.putIfAbsent(s.language, () => {}).add(s.requiredElement ?? s.id);
  }
  if (byLanguage.isEmpty) return const {};
  final base = byLanguage.containsKey('en')
      ? byLanguage['en']!
      : byLanguage.values.reduce((a, b) => a.length >= b.length ? a : b);
  return {
    for (final e in byLanguage.entries)
      if (e.value.containsAll(base)) e.key,
  };
}

/// The app code for a language name shown on a chip. Accepts the ASCII
/// spelling Ju/'hoansi and the umbrella name Oshiwambo (Oshindonga).
String languageCodeForName(String name) {
  for (final l in consentLanguages) {
    if (l.displayName == name) return l.code;
  }
  return switch (name) {
    "Ju/'hoansi" => 'ktz',
    'Oshiwambo' => 'ng',
    _ => 'en',
  };
}

/// Language chips for field capture: the sample list in preview, else the
/// languages the project's published form is in (English first).
final captureLanguagesProvider = Provider<List<String>>((ref) {
  if (ref.watch(fieldCapturePreviewProvider)) return captureLanguages;
  final id = ref.watch(captureSessionProvider.select((s) => s.projectId));
  if (id == null) return const ['English'];
  final all =
      ref.watch(publishedReadSectionsProvider(id)).valueOrNull ?? const [];
  final codes = completeLanguages(all).toList()
    ..sort((a, b) => a == 'en' ? -1 : (b == 'en' ? 1 : a.compareTo(b)));
  return codes.isEmpty
      ? const ['English']
      : [for (final c in codes) languageName(c)];
});

/// One published section as a title, a plain question and short sentences.
ConsentReadSection readSectionFrom(m.ConsentSection s) {
  final key = s.requiredElement ?? '';
  final label = elementLabels[key];
  final sentences = s.text
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  return ConsentReadSection(
    title: label == null
        ? 'Section ${s.order + 1}'
        : label[0].toUpperCase() + label.substring(1),
    question: _plainQuestions[key] ?? 'What does this part say?',
    sentences: sentences.isEmpty ? [s.text] : sentences,
  );
}

const _plainQuestions = {
  'purpose': 'What is this study about?',
  'procedures': 'What will I do?',
  'duration': 'How long will it take?',
  'risks': 'Is there any risk to me?',
  'benefits': 'Will this help me?',
  'compensation': 'Will I be paid?',
  'confidentiality': 'Who will see my answers?',
  'voluntary_withdrawal': 'Do I have to take part?',
  'contacts_researcher': 'Who can I ask?',
  'contacts_ethics': 'Who can I complain to?',
  'guardian_permission': 'Does my guardian need to agree?',
  'child_assent': 'Do I get to choose?',
  'child_dissent_respected': 'What if I say no?',
  'safeguarding_contact': 'Who keeps me safe?',
};

/// Optional feedback (Figma 06.6). Kept apart from the consent answers and
/// never asked of minors.
class CaptureFeedback {
  const CaptureFeedback({
    required this.rating,
    required this.tags,
    required this.comment,
  });
  final int? rating;
  final Set<String> tags;
  final String comment;
}

final captureFeedbackProvider = StateProvider<List<CaptureFeedback>>(
  (ref) => const [],
);

bool shouldAskFeedback(CaptureParticipant? participant) =>
    participant != null && !participant.isMinor;

String formatCaptureDate(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatClock(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
