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

/// One consent-form section. Field names follow the agreed AI output,
/// schemas/consent_draft.schema.json (Figma Development Diagrams, frame G),
/// and the shared `Section` contract (frame F):
/// key, title, text, sourcePages, sourceQuote, changes, confidence,
/// aiGenerated, readingGrade, approvedBy, approvedAt.
/// [status] is UI state only (AI draft / approved / edited).
class DraftSection {
  const DraftSection({
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

  DraftSection copyWith({
    SectionStatus? status,
    String? text,
    bool? aiGenerated,
    String? approvedBy,
    DateTime? approvedAt,
    bool clearApproval = false,
  }) => DraftSection(
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
  });
  final UploadedFile? file;
  final UploadedFile? blocked;
  final List<DraftSection> sections;
  final String language;

  bool get canAnalyse => file?.status == UploadStatus.safe;
  int get doneCount => sections.where((s) => s.done).length;

  /// Keys from [requiredElementKeys] with no section yet (G "missing").
  List<String> get missingKeys => [
    for (final key in requiredElementKeys)
      if (!sections.any((s) => s.key == key)) key,
  ];
  bool get missingElement => missingKeys.isNotEmpty;
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

  void _update(String key, DraftSection Function(DraftSection) change) {
    state = state.copyWith(
      sections: [for (final s in state.sections) s.key == key ? change(s) : s],
    );
  }

  void approve(String key, String by) => _update(
    key,
    (s) => s.copyWith(
      status: SectionStatus.approved,
      approvedBy: by,
      approvedAt: DateTime.now(),
    ),
  );

  void undo(String key) => _update(
    key,
    (s) => s.copyWith(status: SectionStatus.aiDraft, clearApproval: true),
  );

  void edit(String key, String text, String by) => _update(
    key,
    (s) => s.copyWith(
      status: SectionStatus.edited,
      text: text,
      aiGenerated: false,
      approvedBy: by,
      approvedAt: DateTime.now(),
    ),
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
