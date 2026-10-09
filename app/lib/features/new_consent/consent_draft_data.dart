import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class DraftSection {
  const DraftSection({
    required this.id,
    required this.title,
    required this.readingLevel,
    required this.status,
    required this.body,
    required this.source,
    this.sourceQuote,
    this.changes = const [],
    this.confidence = 'High',
    this.confidenceNote = '',
    this.log,
  });
  final String id;
  final String title;
  final String readingLevel;
  final SectionStatus status;
  final String body;

  /// Where the text came from, e.g. "From proposal p.6 · §3.4".
  final String source;
  final String? sourceQuote;
  final List<String> changes;
  final String confidence;
  final String confidenceNote;

  /// Audit line, e.g. "Logged: approved by Ndapewa, 9 Oct 14:12".
  final String? log;

  bool get done => status != SectionStatus.aiDraft;

  DraftSection copyWith({SectionStatus? status, String? body, String? log}) =>
      DraftSection(
        id: id,
        title: title,
        readingLevel: readingLevel,
        status: status ?? this.status,
        body: body ?? this.body,
        source: source,
        sourceQuote: sourceQuote,
        changes: changes,
        confidence: confidence,
        confidenceNote: confidenceNote,
        log: log ?? this.log,
      );
}

/// Required consent elements. The tenth one is missing until it is added.
const requiredElementCount = 10;

class ConsentDraftState {
  const ConsentDraftState({
    this.file,
    this.blocked,
    this.sections = const [],
    this.language = 'English',
  });
  final UploadedFile? file;
  final UploadedFile? blocked;
  final List<DraftSection> sections;
  final String language;

  bool get canAnalyse => file?.status == UploadStatus.safe;
  int get doneCount => sections.where((s) => s.done).length;
  bool get missingElement => sections.length < requiredElementCount;
  bool get allApproved => !missingElement && doneCount == requiredElementCount;

  ConsentDraftState copyWith({
    UploadedFile? file,
    UploadedFile? blocked,
    bool clearBlocked = false,
    List<DraftSection>? sections,
    String? language,
  }) => ConsentDraftState(
    file: file ?? this.file,
    blocked: clearBlocked ? null : (blocked ?? this.blocked),
    sections: sections ?? this.sections,
    language: language ?? this.language,
  );
}

class ConsentDraftController extends StateNotifier<ConsentDraftState> {
  ConsentDraftController() : super(const ConsentDraftState());
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
    state = state.copyWith(sections: [...state.sections, complaintsSection]);
  }

  void _update(String id, DraftSection Function(DraftSection) change) {
    state = state.copyWith(
      sections: [for (final s in state.sections) s.id == id ? change(s) : s],
    );
  }

  void approve(String id, String log) =>
      _update(id, (s) => s.copyWith(status: SectionStatus.approved, log: log));

  void undo(String id) =>
      _update(id, (s) => s.copyWith(status: SectionStatus.aiDraft));

  void edit(String id, String body, String log) => _update(
    id,
    (s) => s.copyWith(status: SectionStatus.edited, body: body, log: log),
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
      (ref) => ConsentDraftController(),
    );

/// Figma 04.3 sample. 9 of 10 required elements; 7 approved or edited.
const sampleSections = [
  DraftSection(
    id: 'purpose',
    title: 'Purpose of the study',
    readingLevel: 'Grade 6',
    status: SectionStatus.approved,
    body:
        'We want to learn how families in Opuwo get clean water and how this affects their health.',
    source: 'From proposal p.2 · §1.1',
    sourceQuote:
        '“This study investigates household water access and associated health outcomes in Opuwo.”',
    changes: ['Reading level: university → Grade 6'],
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'procedures',
    title: 'What you will do',
    readingLevel: 'Grade 5',
    status: SectionStatus.approved,
    body:
        'You will answer questions in one interview. It takes about 40 minutes.',
    source: 'From proposal p.5 · §3.1',
    sourceQuote:
        '“Data will be collected through a single semi-structured interview of approximately 40 minutes.”',
    changes: ['Replaced “semi-structured interview” with “interview”'],
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'risks',
    title: 'Risks & discomforts',
    readingLevel: 'Grade 6',
    status: SectionStatus.aiDraft,
    body:
        'You may feel tired during the 40-minute interview. You can rest or stop at any time without any problem.',
    source: 'From proposal p.6 · §3.4',
    sourceQuote:
        '“Participants may experience mild fatigue owing to the duration of the semi-structured interview (approx. 40 min).”',
    changes: [
      'Replaced “semi-structured interview” with “interview”',
      'Added that stopping has no penalty (required element)',
      'Reading level: university → Grade 6',
    ],
    confidenceNote:
        'Matches source closely. Translation to Otjiherero needs a human reviewer.',
  ),
  DraftSection(
    id: 'rights',
    title: 'Your rights & withdrawing',
    readingLevel: 'Grade 6',
    status: SectionStatus.edited,
    body:
        'Taking part is your choice. You can say no, skip any question, or stop at any time. Nothing bad will happen if you stop.',
    source: 'You edited this',
    log: 'Logged: edited by you',
  ),
  DraftSection(
    id: 'benefits',
    title: 'Possible benefits',
    readingLevel: 'Grade 6',
    status: SectionStatus.approved,
    body:
        'There is no direct benefit to you. What we learn may help improve water services in your area.',
    source: 'From proposal p.6 · §3.5',
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'privacy',
    title: 'Keeping your information private',
    readingLevel: 'Grade 6',
    status: SectionStatus.approved,
    body:
        'Your name will not be written on your answers. Only the research team can see them.',
    source: 'From proposal p.7 · §4.2',
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'compensation',
    title: 'Payment',
    readingLevel: 'Grade 5',
    status: SectionStatus.approved,
    body: 'You will not be paid. We will give you water and a snack.',
    source: 'From proposal p.7 · §4.4',
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'storage',
    title: 'How long we keep your answers',
    readingLevel: 'Grade 6',
    status: SectionStatus.approved,
    body: 'We keep your answers safely for 5 years. Then we delete them.',
    source: 'From proposal p.8 · §4.5',
    log: 'Logged: approved by you',
  ),
  DraftSection(
    id: 'contact',
    title: 'Questions about the study',
    readingLevel: 'Grade 6',
    status: SectionStatus.aiDraft,
    body:
        'If you have questions, you can ask the researcher now or contact them later. Their details are on the copy you keep.',
    source: 'From proposal p.9 · §5.1',
    sourceQuote:
        '“Participants will receive the principal investigator’s contact details.”',
    changes: ['Reading level: university → Grade 6'],
    confidenceNote: 'Matches source closely.',
  ),
];

const complaintsSection = DraftSection(
  id: 'complaints',
  title: 'If you have a complaint',
  readingLevel: 'Grade 6',
  status: SectionStatus.aiDraft,
  body:
      'If you are unhappy with how this study is done, you can contact the ethics committee that approved it. Their contact details are on the copy you keep.',
  source: 'Added from your institution template',
  changes: ['Added because it is a required consent element'],
  confidence: 'Medium',
  confidenceNote:
      'Not in your proposal. Check that the committee contact on the printed copy is correct.',
);
