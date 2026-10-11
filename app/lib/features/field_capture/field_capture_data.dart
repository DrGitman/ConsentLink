import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../new_consent/consent_draft_data.dart';

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

const captureLanguages = ['Otjiherero', 'English', 'Afrikaans', 'Oshiwambo'];

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
  CaptureSessionController() : super(const CaptureSession());

  void start({String? projectId}) =>
      state = CaptureSession(projectId: projectId);

  void setLanguage(String value) => state = state.copyWith(language: value);
  void setReadAloud(bool value) => state = state.copyWith(readAloud: value);
  void setLargeText(bool value) => state = state.copyWith(largeText: value);
  void setInterpreter(bool value) => state = state.copyWith(interpreter: value);

  void goToSection(int index) => state = state.copyWith(
    section: index.clamp(0, sampleReadSections.length - 1),
  );

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
      (ref) => CaptureSessionController(),
    );

final captureParticipantProvider = Provider<CaptureParticipant?>(
  (ref) => ref.watch(fieldCapturePreviewProvider) ? sampleParticipant : null,
);

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
