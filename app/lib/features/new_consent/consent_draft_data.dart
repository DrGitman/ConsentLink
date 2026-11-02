import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../ai/ai_exceptions.dart';
import '../../ai/ai_providers.dart';
import '../../ai/pdf/proposal_file_guard.dart';
import '../../ai/pdf/proposal_page.dart';
import '../../ai/pdf/proposal_text_extractor.dart';
import '../../ai/rules/readability.dart';
import '../../ai/service/on_device_consent_ai_service.dart';
import '../../contracts/consent_ai_service.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../data/repositories/repository_providers.dart';
import '../ai_assist/on_device_assistant.dart';

/// Sample upload/draft data appears only with NEW_CONSENT_PREVIEW=true or the
/// existing DASHBOARD_PREVIEW / PROJECTS_PREVIEW flags. No file is read, scanned
/// or uploaded, and no AI model runs: the on-device model (P3) and the file
/// scan service (P4) are not connected yet.
final newConsentPreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('NEW_CONSENT_PREVIEW') ||
      const bool.fromEnvironment('DASHBOARD_PREVIEW') ||
      const bool.fromEnvironment('PROJECTS_PREVIEW'),
);

enum UploadStatus { uploading, scanning, safe, blocked }

class UploadedFile {
  const UploadedFile({
    required this.name,
    required this.status,
    this.pages = 0,
    this.progress = 0,
  });
  final String name;
  final UploadStatus status;
  final int pages;
  final double progress;

  String get extension => name.split('.').last.toUpperCase();

  UploadedFile copyWith({UploadStatus? status, double? progress}) =>
      UploadedFile(
        name: name,
        pages: pages,
        status: status ?? this.status,
        progress: progress ?? this.progress,
      );
}

enum SectionStatus { aiDraft, approved, edited }

/// One consent-form section. Field names follow the agreed AI output,
/// schemas/consent_draft.schema.json (Figma Development Diagrams, frame G),
/// and the shared `Section` contract (frame F):
/// key, title, text, sourcePages, sourceQuote, changes, confidence,
/// aiGenerated, readingGrade, approvedBy, approvedAt.
/// [status] is UI state only (AI draft / approved / edited).
class DraftSection {
  const DraftSection({
    this.id,
    required this.key,
    required this.title,
    required this.text,
    required this.status,
    this.sourcePages = const [],
    this.sourceQuote,
    this.changes = const [],
    this.confidence = 'high',
    this.aiGenerated = true,
    this.readingGrade = 6,
    this.approvedBy,
    this.approvedAt,
  });

  /// The saved ConsentSection id once the draft is stored on the phone.
  final String? id;

  /// Required-element key from G, e.g. `risks`, `contacts_ethics`.
  final String key;
  final String title;
  final String text;
  final SectionStatus status;
  final List<int> sourcePages;
  final String? sourceQuote;
  final List<String> changes;

  /// `high`, `medium` or `low` (text, as in G).
  final String confidence;
  final bool aiGenerated;
  final int readingGrade;
  final String? approvedBy;
  final DateTime? approvedAt;

  bool get done => status != SectionStatus.aiDraft;

  String get readingLevel => 'Grade $readingGrade';

  String get confidenceLabel => confidence.isEmpty
      ? confidence
      : confidence[0].toUpperCase() + confidence.substring(1);

  /// "From proposal p.6", or why there is no page.
  String get sourceLabel => sourcePages.isNotEmpty
      ? 'From proposal p.${sourcePages.join(', ')}'
      : aiGenerated
      ? 'Not in your proposal'
      : 'You wrote this';

  /// Audit line, e.g. "Logged: approved by Ndapewa, 9 Oct 14:12".
  String? get log {
    if (approvedBy == null || approvedAt == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final t = approvedAt!;
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final verb = status == SectionStatus.edited ? 'edited' : 'approved';
    return 'Logged: $verb by $approvedBy, ${t.day} ${months[t.month - 1]} $time';
  }

  DraftSection withId(String newId) => DraftSection(
    id: newId,
    key: key,
    title: title,
    text: text,
    status: status,
    sourcePages: sourcePages,
    sourceQuote: sourceQuote,
    changes: changes,
    confidence: confidence,
    aiGenerated: aiGenerated,
    readingGrade: readingGrade,
    approvedBy: approvedBy,
    approvedAt: approvedAt,
  );

  DraftSection copyWith({
    SectionStatus? status,
    String? text,
    bool? aiGenerated,
    String? approvedBy,
    DateTime? approvedAt,
    bool clearApproval = false,
  }) => DraftSection(
    id: id,
    key: key,
    title: title,
    text: text ?? this.text,
    status: status ?? this.status,
    sourcePages: sourcePages,
    sourceQuote: sourceQuote,
    changes: changes,
    confidence: confidence,
    aiGenerated: aiGenerated ?? this.aiGenerated,
    readingGrade: readingGrade,
    approvedBy: clearApproval ? null : (approvedBy ?? this.approvedBy),
    approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
  );
}

/// The 10 required consent elements (G), in display order.
const requiredElementKeys = [
  'purpose',
  'procedures',
  'duration',
  'risks',
  'benefits',
  'compensation',
  'confidentiality',
  'voluntary_withdrawal',
  'contacts_researcher',
  'contacts_ethics',
];

/// Extra required elements for projects that include minors (Figma C + G).
/// Not used by these screens yet; the rule checker (P3) owns them.
const minorsElementKeys = [
  'guardian_permission',
  'child_assent',
  'child_dissent_respected',
  'safeguarding_contact',
];

/// Plain-language names for the "Missing: …" checklist.
const elementLabels = {
  'purpose': 'purpose of the study',
  'procedures': 'what participants will do',
  'duration': 'how long it takes',
  'risks': 'risks and discomforts',
  'benefits': 'possible benefits',
  'compensation': 'payment or compensation',
  'confidentiality': 'confidentiality',
  'voluntary_withdrawal': 'right to say no or stop',
  'contacts_researcher': 'researcher contact',
  'contacts_ethics': 'complaints contact (ethics committee)',
  'guardian_permission': 'guardian permission',
  'child_assent': 'child assent',
  'child_dissent_respected': 'child’s “No” is respected',
  'safeguarding_contact': 'safeguarding contact',
};

/// Required consent elements. The tenth one is missing until it is added.
const requiredElementCount = 10; // = requiredElementKeys.length

class ConsentDraftState {
  const ConsentDraftState({
    this.file,
    this.blocked,
    this.sections = const [],
    this.language = 'English',
    this.bytes,
    this.studyId,
    this.involvesMinors = false,
    this.sample = false,
    this.problem,
    this.answers,
  });
  final UploadedFile? file;
  final UploadedFile? blocked;
  final List<DraftSection> sections;
  final String language;

  /// The accepted proposal. Read on this phone only, never uploaded.
  final Uint8List? bytes;

  /// The study the draft is saved in, once drafting has finished.
  final String? studyId;
  final bool involvesMinors;

  /// True when the on-device model was not on this phone, so the review shows
  /// the built-in sample draft instead of a draft of the uploaded proposal.
  final bool sample;

  /// Why the last file or drafting attempt failed, in plain words.
  final String? problem;

  /// Answers to the six guided questions, when there is no proposal (04.1
  /// "Describe your study by voice or text").
  final List<String>? answers;

  bool get canAnalyse => file?.status == UploadStatus.safe;
  int get doneCount => sections.where((s) => s.done).length;

  /// Every element this form needs: the 10, plus the 4 for minors.
  List<String> get neededKeys => [
    ...requiredElementKeys,
    if (involvesMinors) ...minorsElementKeys,
  ];

  /// Keys with no section yet (G "missing").
  List<String> get missingKeys => [
    for (final key in neededKeys)
      if (!sections.any((s) => s.key == key)) key,
  ];
  bool get missingElement => missingKeys.isNotEmpty;
  bool get allApproved =>
      !missingElement && sections.isNotEmpty && sections.every((s) => s.done);

  ConsentDraftState copyWith({
    UploadedFile? file,
    UploadedFile? blocked,
    bool clearBlocked = false,
    List<DraftSection>? sections,
    String? language,
    Uint8List? bytes,
    String? studyId,
    bool? involvesMinors,
    bool? sample,
    String? problem,
    bool clearProblem = false,
    List<String>? answers,
  }) => ConsentDraftState(
    file: file ?? this.file,
    blocked: clearBlocked ? null : (blocked ?? this.blocked),
    sections: sections ?? this.sections,
    language: language ?? this.language,
    bytes: bytes ?? this.bytes,
    studyId: studyId ?? this.studyId,
    involvesMinors: involvesMinors ?? this.involvesMinors,
    sample: sample ?? this.sample,
    problem: clearProblem ? null : (problem ?? this.problem),
    answers: answers ?? this.answers,
  );
}

/// Opens the phone's file picker. Null when the researcher cancels.
/// Replaced in tests.
final proposalPickerProvider =
    Provider<Future<({String name, Uint8List bytes})?> Function()>(
      (ref) => () async {
        final picked = await FilePicker.platform.pickFiles(withData: true);
        final f = picked?.files.singleOrNull;
        return f == null
            ? null
            : (name: f.name, bytes: f.bytes ?? Uint8List(0));
      },
    );

class ConsentDraftController extends StateNotifier<ConsentDraftState> {
  ConsentDraftController(this._ref) : super(const ConsentDraftState());
  final Ref _ref;
  final _timers = <Timer>[];

  void _after(int ms, void Function() run) => _timers.add(
    Timer(Duration(milliseconds: ms), () {
      if (mounted) run();
    }),
  );

  void reset() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    state = const ConsentDraftState();
  }

  /// Preview: Figma "Upload & file scan" — upload 0.9 s, scan 0.9 s, safe.
  void pickSampleProposal() {
    state = state.copyWith(
      file: const UploadedFile(
        name: 'Opuwo_water_proposal_v3.pdf',
        pages: 18,
        status: UploadStatus.uploading,
      ),
    );
    for (var i = 1; i <= 6; i++) {
      _after(i * 150, () {
        state = state.copyWith(file: state.file?.copyWith(progress: i / 6));
      });
    }
    _after(950, () {
      state = state.copyWith(
        file: state.file?.copyWith(status: UploadStatus.scanning),
      );
    });
    _after(1850, () {
      state = state.copyWith(
        file: state.file?.copyWith(status: UploadStatus.safe),
      );
    });
  }

  /// Preview: a program file is refused before it is stored anywhere.
  void pickSampleBlockedFile() {
    state = state.copyWith(
      blocked: const UploadedFile(
        name: 'survey_tool.exe',
        status: UploadStatus.blocked,
      ),
    );
  }

  void dismissBlocked() => state = state.copyWith(clearBlocked: true);

  /// Preview result of drafting: the Figma 04.3 sections.
  void loadSampleDraft() =>
      state = state.copyWith(sections: sampleSections, language: 'English');

  void setLanguage(String language) =>
      state = state.copyWith(language: language);

  void addMissingElement() {
    if (!state.missingElement) return;
    final key = state.missingKeys.first;
    final section = key == complaintsSection.key
        ? complaintsSection
        : DraftSection(
            key: key,
            title: _titleCase(elementLabels[key] ?? key),
            status: SectionStatus.aiDraft,
            text: elementTemplates[key] ?? 'Write this section in plain words.',
            changes: const ['Added because it is a required consent element'],
            confidence: 'medium',
          );
    final id = state.studyId == null ? null : const Uuid().v4();
    state = state.copyWith(
      sections: [...state.sections, id == null ? section : section.withId(id)],
    );
    _store(key);
  }

  void _update(String key, DraftSection Function(DraftSection) change) {
    state = state.copyWith(
      sections: [for (final s in state.sections) s.key == key ? change(s) : s],
    );
  }

  void approve(String key, String by) {
    _update(
      key,
      (s) => s.copyWith(
        status: SectionStatus.approved,
        approvedBy: by,
        approvedAt: DateTime.now(),
      ),
    );
    _store(key);
  }

  void undo(String key) {
    _update(
      key,
      (s) => s.copyWith(status: SectionStatus.aiDraft, clearApproval: true),
    );
    _store(key);
  }

  void edit(String key, String text, String by) {
    _update(
      key,
      (s) => s.copyWith(
        status: SectionStatus.edited,
        text: text,
        aiGenerated: false,
        approvedBy: by,
        approvedAt: DateTime.now(),
      ),
    );
    _store(key);
  }

  // ---- Live mode: a real file, the on-device model, the local database ----

  /// Program and macro files are refused before they are read.
  static const blockedExtensions = {
    'exe',
    'apk',
    'bat',
    'cmd',
    'com',
    'msi',
    'sh',
    'js',
    'jar',
    'vbs',
    'ps1',
    'scr',
    'docm',
    'xlsm',
    'pptm',
  };

  /// The form language code of the draft, e.g. 'en'.
  String _formLanguage = 'en';

  void setInvolvesMinors(bool value) =>
      state = state.copyWith(involvesMinors: value);

  /// Lets the researcher choose a proposal, then checks it on the phone.
  Future<void> pickProposal() async {
    final ({String name, Uint8List bytes})? file;
    try {
      file = await _ref.read(proposalPickerProvider)();
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          problem: 'The file picker could not open. Try again.',
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    await acceptFile(file.name, file.bytes);
  }

  /// Programs are blocked; a PDF is opened and read page by page on the phone
  /// (the "scan"), so a broken, scanned or locked file is caught here.
  Future<void> acceptFile(String name, Uint8List bytes) async {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    state = state.copyWith(clearProblem: true, clearBlocked: true);
    if (blockedExtensions.contains(ext)) {
      state = state.copyWith(
        blocked: UploadedFile(name: name, status: UploadStatus.blocked),
      );
      return;
    }
    state = state.copyWith(
      file: UploadedFile(
        name: name,
        status: UploadStatus.uploading,
        progress: 1,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    state = state.copyWith(
      file: state.file?.copyWith(status: UploadStatus.scanning),
    );
    try {
      if (ext != 'pdf') {
        throw const CorruptedPdfException(
          'Only PDF proposals can be read on this phone for now. '
          'Save it as a PDF and try again.',
        );
      }
      checkProposalBytes(bytes);
      final pages = await _ref
          .read(proposalTextExtractorProvider)
          .extract(bytes);
      if (!mounted) return;
      state = state.copyWith(
        bytes: bytes,
        file: UploadedFile(
          name: name,
          pages: pages.length,
          status: UploadStatus.safe,
          progress: 1,
        ),
      );
    } on ConsentAiException catch (e) {
      if (!mounted) return;
      state = ConsentDraftState(
        involvesMinors: state.involvesMinors,
        problem: e.message,
      );
    }
  }

  /// Drafts the form with the on-device model and saves it as a new study.
  /// When the model is not on this phone, the built-in sample draft is used
  /// instead and [ConsentDraftState.sample] says so on the review screen.
  /// Drafting from the six guided answers instead of a proposal.
  void useAnswers(List<String> answers) {
    state = ConsentDraftState(
      answers: answers,
      involvesMinors: state.involvesMinors,
    );
  }

  Stream<AiDraftingEvent> draft() async* {
    final answers = state.answers;
    if (answers != null) {
      yield* _draftFromAnswers(answers);
      return;
    }
    final bytes = state.bytes;
    final ai = _ref.read(consentAiServiceProvider);
    final modelReady = bytes != null && await ai.isAvailable();
    if (!modelReady) {
      for (final step in AiDraftingStep.values) {
        yield AiStepStarted(step);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        yield AiStepCompleted(step);
      }
      await saveDraft(
        [
          for (final s in sampleSections)
            s.copyWith(status: SectionStatus.aiDraft, clearApproval: true),
        ],
        formLanguage: 'en',
        sample: true,
      );
      return;
    }
    final request = AiDraftRequest(
      proposalPdf: bytes,
      fileName: state.file?.name ?? 'proposal.pdf',
      involvesMinors: state.involvesMinors,
    );
    await for (final event in ai.draftConsent(request)) {
      if (event is AiDraftCompleted) {
        final r = event.result;
        await saveDraft(
          [for (final s in r.sections) _fromAi(s, r.readingGrade)],
          formLanguage: r.formLanguage,
          sample: false,
        );
      }
      yield event;
    }
  }

  /// The on-device model drafts from the answers as if they were proposal
  /// pages (one page per answer). Without the model, each answer becomes its
  /// section and the other required elements get standard wording.
  Stream<AiDraftingEvent> _draftFromAnswers(List<String> answers) async* {
    final title = studyTitleFromAnswers(answers);
    if (await _ref.read(onDeviceAssistantProvider).isAvailable()) {
      final ai = OnDeviceConsentAiService(
        extractor: AnswersExtractor(answers),
        runtime: _ref.read(llmRuntimeProvider),
      );
      final request = AiDraftRequest(
        proposalPdf: Uint8List.fromList(utf8.encode(answers.join('\n'))),
        fileName: 'answers.txt',
        involvesMinors: state.involvesMinors,
      );
      await for (final event in ai.draftConsent(request)) {
        if (event is AiDraftCompleted) {
          final r = event.result;
          await saveDraft(
            [for (final s in r.sections) _fromAi(s, r.readingGrade)],
            formLanguage: r.formLanguage,
            sample: false,
            title: title,
          );
        }
        yield event;
      }
      return;
    }
    for (final step in AiDraftingStep.values) {
      yield AiStepStarted(step);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      yield AiStepCompleted(step);
    }
    await saveDraft(
      sectionsFromAnswers(answers, neededKeys: state.neededKeys),
      formLanguage: 'en',
      sample: false,
      title: title,
    );
  }

  /// Creates the study and stores every drafted section on the phone.
  Future<void> saveDraft(
    List<DraftSection> sections, {
    required String formLanguage,
    required bool sample,
    String? title,
  }) async {
    final studies = await _ref.read(studyRepositoryProvider.future);
    final study = await studies.createStudy(
      m.StudyDraft(
        title: title ?? studyTitleFromFile(state.file?.name),
        involvesMinors: state.involvesMinors,
      ),
    );
    _formLanguage = formLanguage;
    final saved = <DraftSection>[];
    for (final (i, s) in sections.indexed) {
      final withId = s.withId(const Uuid().v4());
      await studies.saveSection(_toSection(withId, study.id, i));
      saved.add(withId);
    }
    if (!mounted) return;
    state = state.copyWith(
      sections: saved,
      studyId: study.id,
      sample: sample,
      language: _displayLanguage(formLanguage),
    );
    _ref.read(dataRevisionProvider.notifier).state++;
  }

  /// Locks the approved sections as the participant form. Returns the study id.
  Future<String?> publish() async {
    final id = state.studyId;
    if (id == null) return null;
    final studies = await _ref.read(studyRepositoryProvider.future);
    await studies.publishForm(id);
    _ref.read(dataRevisionProvider.notifier).state++;
    return id;
  }

  /// Saves one section, then approves it again if the researcher has.
  Future<void> _store(String key) async {
    final studyId = state.studyId;
    final index = state.sections.indexWhere((s) => s.key == key);
    if (studyId == null || index < 0) return;
    final section = state.sections[index];
    if (section.id == null) return;
    try {
      final studies = await _ref.read(studyRepositoryProvider.future);
      await studies.saveSection(_toSection(section, studyId, index));
      if (section.done) await studies.approveSection(section.id!);
      _ref.read(dataRevisionProvider.notifier).state++;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(problem: 'This change could not be saved: $e');
      }
    }
  }

  m.ConsentSection _toSection(DraftSection s, String studyId, int order) =>
      m.ConsentSection(
        id: s.id!,
        studyId: studyId,
        order: order,
        language: _formLanguage,
        text: s.text,
        sourcePage: s.sourcePages.isEmpty ? null : s.sourcePages.first,
        sourceQuote: s.sourceQuote,
        changes: s.changes,
        confidence: m.Confidence.values
            .where((c) => c.name == s.confidence)
            .firstOrNull,
        requiredElement: s.key,
        // Saved as a draft; approveSection() records the approval itself.
        status: m.SectionStatus.draft,
      );

  DraftSection _fromAi(AiDraftSection a, double? grade) => DraftSection(
    key: a.elementKey,
    title: a.title,
    text: a.text,
    status: SectionStatus.aiDraft,
    sourcePages: a.sourcePages,
    sourceQuote: a.sourceQuote,
    changes: a.changes,
    confidence: a.confidence.name,
    readingGrade: grade?.round() ?? 6,
  );

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

final consentDraftProvider =
    StateNotifierProvider<ConsentDraftController, ConsentDraftState>(
      (ref) => ConsentDraftController(ref),
    );

/// Figma 04.3 sample. 9 of 10 required elements; 7 approved or edited.
/// Field names and keys follow schemas/consent_draft (Figma G).
final _sampleApproved = DateTime(2026, 10, 4, 14, 12);

final sampleSections = [
  DraftSection(
    key: 'purpose',
    title: 'Purpose of the study',
    status: SectionStatus.approved,
    text:
        'We want to learn how families in Opuwo get clean water and how this affects their health.',
    sourcePages: const [2],
    sourceQuote:
        '“This study investigates household water access and associated health outcomes in Opuwo.”',
    changes: const ['Reading level: university → Grade 6'],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  DraftSection(
    key: 'procedures',
    title: 'What you will do',
    readingGrade: 5,
    status: SectionStatus.approved,
    text: 'You will answer questions in one interview with the researcher.',
    sourcePages: const [5],
    sourceQuote:
        '“Data will be collected through a single semi-structured interview.”',
    changes: const ['Replaced “semi-structured interview” with “interview”'],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  const DraftSection(
    key: 'risks',
    title: 'Risks & discomforts',
    status: SectionStatus.aiDraft,
    text:
        'You may feel tired during the 40-minute interview. You can rest or stop at any time without any problem.',
    sourcePages: [6],
    sourceQuote:
        '“Participants may experience mild fatigue owing to the duration of the semi-structured interview (approx. 40 min).”',
    changes: [
      'Replaced “semi-structured interview” with “interview”',
      'Added that stopping has no penalty (required element)',
      'Reading level: university → Grade 6',
    ],
  ),
  DraftSection(
    key: 'voluntary_withdrawal',
    title: 'Your rights & withdrawing',
    status: SectionStatus.edited,
    aiGenerated: false,
    text:
        'Taking part is your choice. You can say no, skip any question, or stop at any time. Nothing bad will happen if you stop.',
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  DraftSection(
    key: 'benefits',
    title: 'Possible benefits',
    status: SectionStatus.approved,
    text:
        'There is no direct benefit to you. What we learn may help improve water services in your area.',
    sourcePages: const [6],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  DraftSection(
    key: 'confidentiality',
    title: 'Keeping your information private',
    status: SectionStatus.approved,
    text:
        'Your name will not be written on your answers. Only the research team can see them, and they are deleted after 5 years.',
    sourcePages: const [7, 8],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  DraftSection(
    key: 'compensation',
    title: 'Payment',
    readingGrade: 5,
    status: SectionStatus.approved,
    text: 'You will not be paid. We will give you water and a snack.',
    sourcePages: const [7],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  DraftSection(
    key: 'duration',
    title: 'How long it takes',
    readingGrade: 5,
    status: SectionStatus.approved,
    text: 'The interview takes about 40 minutes. We only meet once.',
    sourcePages: const [5],
    approvedBy: 'Ndapewa',
    approvedAt: _sampleApproved,
  ),
  const DraftSection(
    key: 'contacts_researcher',
    title: 'Questions about the study',
    status: SectionStatus.aiDraft,
    text:
        'If you have questions, you can ask the researcher now or contact them later. Their details are on the copy you keep.',
    sourcePages: [9],
    sourceQuote:
        '“Participants will receive the principal investigator’s contact details.”',
    changes: ['Reading level: university → Grade 6'],
  ),
];

/// The missing `contacts_ethics` element, added from the institution template.
const complaintsSection = DraftSection(
  key: 'contacts_ethics',
  title: 'If you have a complaint',
  status: SectionStatus.aiDraft,
  text:
      'If you are unhappy with how this study is done, you can contact the ethics committee that approved it. Their contact details are on the copy you keep.',
  changes: ['Added because it is a required consent element'],
  confidence: 'medium',
);

/// "Opuwo_water_proposal_v3.pdf" -> "Opuwo water proposal v3".
/// The six guided questions (04.1), in order, and the element each answer
/// becomes.
const guidedQuestions = <(String, String, String)>[
  (
    'purpose',
    'What is your study about, and why are you doing it?',
    'For example: how families in Opuwo get clean water, to improve services.',
  ),
  (
    'procedures',
    'What will participants do?',
    'For example: answer questions in one interview with the researcher.',
  ),
  (
    'duration',
    'How long will it take for each participant?',
    'For example: one interview of about 40 minutes.',
  ),
  (
    'risks',
    'What risks or discomforts could participants have?',
    'For example: they may feel tired; they can rest or stop.',
  ),
  (
    'benefits',
    'What good could come from it, for them or others?',
    'For example: better water services in the area.',
  ),
  (
    'contacts_researcher',
    'Who can participants contact with questions?',
    'Your name and a phone number or email.',
  ),
];

/// A study title from the first answer: its first sentence, shortened.
String studyTitleFromAnswers(List<String> answers) {
  final first = answers.isEmpty ? '' : answers.first.trim();
  if (first.isEmpty) return 'New study';
  var title = first.split(RegExp(r'[.!?\n]')).first.trim();
  title = title.replaceFirst(
    RegExp(
      r'^(my|our|the|this)\s+(study|research|project)\s+(is\s+)?(about\s+)?',
      caseSensitive: false,
    ),
    '',
  );
  if (title.length > 60) title = '${title.substring(0, 57).trimRight()}…';
  return title.isEmpty ? 'New study' : _titleCase(title);
}

/// Sections built from the guided answers without the model: each answer as
/// written (the researcher reviews every one), standard wording for the rest.
List<DraftSection> sectionsFromAnswers(
  List<String> answers, {
  required List<String> neededKeys,
}) {
  String sentence(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    final capital = t[0].toUpperCase() + t.substring(1);
    return RegExp(r'[.!?]$').hasMatch(capital) ? capital : '$capital.';
  }

  final byKey = <String, (int, String)>{
    for (final (i, q) in guidedQuestions.indexed)
      if (i < answers.length && answers[i].trim().isNotEmpty)
        q.$1: (i + 1, sentence(answers[i])),
  };
  return [
    for (final key in neededKeys)
      if (byKey[key] case (final n, final text))
        DraftSection(
          key: key,
          title: _titleCase(elementLabels[key] ?? key),
          text: text,
          status: SectionStatus.aiDraft,
          sourceQuote: text,
          changes: ['Your answer to question $n, as you gave it'],
          confidence: 'high',
          aiGenerated: false,
          readingGrade: (readingGradeOf(text, 'en') ?? 6).round(),
        )
      else
        DraftSection(
          key: key,
          title: _titleCase(elementLabels[key] ?? key),
          text: elementTemplates[key] ?? '',
          status: SectionStatus.aiDraft,
          changes: const ['Standard wording. Check it fits your study'],
          confidence: 'medium',
          aiGenerated: false,
          readingGrade: (readingGradeOf(elementTemplates[key] ?? '', 'en') ?? 6)
              .round(),
        ),
  ];
}

/// Serves the guided answers to the drafting pipeline as numbered "pages".
class AnswersExtractor implements ProposalTextExtractor {
  const AnswersExtractor(this.answers);
  final List<String> answers;

  @override
  Future<List<ProposalPage>> extract(Uint8List bytes) async => [
    for (final (i, q) in guidedQuestions.indexed)
      if (i < answers.length && answers[i].trim().isNotEmpty)
        ProposalPage(pageNumber: i + 1, text: '${q.$2}\n${answers[i].trim()}'),
  ];
}

String studyTitleFromFile(String? fileName) {
  if (fileName == null || fileName.trim().isEmpty) return 'New study';
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final words = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  return words.isEmpty ? 'New study' : words;
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _displayLanguage(String code) => switch (code) {
  'en' => 'English',
  'af' => 'Afrikaans',
  'de' => 'Deutsch',
  'hz' => 'Otjiherero',
  'naq' => 'Khoekhoegowab',
  'ktz' => "Ju/'hoansi",
  'kwn' => 'Rukwangali',
  'loz' => 'Silozi',
  'ng' => 'Oshindonga',
  'kj' => 'Oshikwanyama',
  _ => code,
};

/// Plain starting text for a required element the draft did not cover.
/// The researcher edits and approves it like any other section.
const elementTemplates = {
  'purpose':
      'We are doing this study to learn more about the topic described by the researcher.',
  'procedures': 'You will answer some questions with the researcher.',
  'duration': 'Taking part takes about 30 minutes.',
  'risks':
      'There are no big risks. Some questions may make you feel tired or uncomfortable. You can stop at any time.',
  'benefits':
      'There may be no direct benefit to you. What we learn may help others.',
  'compensation': 'You will not be paid for taking part.',
  'confidentiality':
      'Your name will not be written on your answers. Only the research team can see them.',
  'voluntary_withdrawal':
      'Taking part is your choice. You can say no or stop at any time. Nothing bad will happen if you stop.',
  'contacts_researcher':
      'If you have questions, ask the researcher now or contact them later. Their details are on the copy you keep.',
  'contacts_ethics':
      'If you are unhappy with how this study is done, you can contact the ethics committee that approved it. Their details are on the copy you keep.',
  'guardian_permission':
      'Because the participant is under 18, a parent or legal guardian must agree first.',
  'child_assent':
      'We will also ask the young person if they want to take part, in words they understand.',
  'child_dissent_respected':
      'If the young person says no, we stop, even if the guardian agreed.',
  'safeguarding_contact':
      'If anything worries you about the young person\'s safety, contact the safeguarding officer named on the copy you keep.',
};
