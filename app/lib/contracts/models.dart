// contracts/models.dart
// Shared data shapes. Agreed between P1 (UI), P2 (data), P3 (AI).
// Change only by agreement of all three.
//
// Conventions
// - IDs are UUID strings generated on the device, so records can be created offline.
// - createdAt / signedAt are DEVICE time (can be wrong). receivedAt is SERVER time,
//   set by Supabase on arrival. The app never sets receivedAt.
// - actor_id and institution_id on audit entries are set by the server from the
//   logged-in user. Anything the app sends for them is ignored.
// - language is a CODE from contracts/languages.dart and the languages table
//   (en, af, de, hz, naq, ktz, ...), never a display name. Display names and
//   spelling such as Juǀ'hoansi (U+01C0) live in languages.dart only.
// - The server writes the audit entries for study created, section approved, form
//   published, consent signed and consent withdrawn. The app only records exports.
// - JSON keys are snake_case and match the database columns and /schemas.

enum ConsentDecision { yes, no }

enum ConsentMethod { signature, thumbprint, verbal }

enum SectionStatus { draft, edited, approved }

enum Confidence { low, medium, high }

enum StudyStatus { draft, approved, active, closed }

enum SignatureKind { signature, thumbprint, witness, audio }

enum SyncStatus { offline, syncing, synced, error }

enum ResearcherRole { researcher, admin }

enum AuditAction {
  studyCreated,
  sectionApproved,
  formPublished,
  consentSigned,
  consentExported,
  consentWithdrawn,
}

// ---- JSON helpers -------------------------------------------------------

String _snake(String s) =>
    s.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

String _enumToJson(Enum e) => _snake(e.name);

T _enumFromJson<T extends Enum>(List<T> values, Object? v) {
  for (final e in values) {
    if (_snake(e.name) == v) return e;
  }
  throw FormatException('Unknown $T value: $v');
}

String _dt(DateTime d) => d.toUtc().toIso8601String();

DateTime? _dtOrNull(Object? v) =>
    v == null ? null : DateTime.parse(v as String);

// ---- Models -------------------------------------------------------------

class Institution {
  final String id;
  final String name;
  final String? colourHex;
  final String? logoUrl;
  final String? templateUrl;
  const Institution({
    required this.id,
    required this.name,
    this.colourHex,
    this.logoUrl,
    this.templateUrl,
  });

  factory Institution.fromJson(Map<String, dynamic> j) => Institution(
    id: j['id'] as String,
    name: j['name'] as String,
    colourHex: j['colour_hex'] as String?,
    logoUrl: j['logo_url'] as String?,
    templateUrl: j['template_url'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colour_hex': colourHex,
    'logo_url': logoUrl,
    'template_url': templateUrl,
  };
}

class Researcher {
  final String id;
  final String institutionId;
  final String name;
  final String email;
  final ResearcherRole role;
  const Researcher({
    required this.id,
    required this.institutionId,
    required this.name,
    required this.email,
    this.role = ResearcherRole.researcher,
  });

  factory Researcher.fromJson(Map<String, dynamic> j) => Researcher(
    id: j['id'] as String,
    institutionId: j['institution_id'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    role: j['role'] == null
        ? ResearcherRole.researcher
        : _enumFromJson(ResearcherRole.values, j['role']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'institution_id': institutionId,
    'name': name,
    'email': email,
    'role': _enumToJson(role),
  };
}

class Study {
  final String id;
  final String institutionId;
  final String researcherId;
  final String title;
  final bool involvesMinors;
  final StudyStatus status;

  /// 0 = form not published yet. Goes up by 1 each time publishForm() runs.
  final int formVersion;

  /// SHA-256 fingerprint of the published form (see form_hash.dart).
  final String? formHash;
  const Study({
    required this.id,
    required this.institutionId,
    required this.researcherId,
    required this.title,
    required this.involvesMinors,
    required this.status,
    this.formVersion = 0,
    this.formHash,
  });

  factory Study.fromJson(Map<String, dynamic> j) => Study(
    id: j['id'] as String,
    institutionId: j['institution_id'] as String,
    researcherId: j['researcher_id'] as String,
    title: j['title'] as String,
    involvesMinors: j['involves_minors'] as bool,
    status: _enumFromJson(StudyStatus.values, j['status']),
    formVersion: (j['form_version'] as int?) ?? 0,
    formHash: j['form_hash'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'institution_id': institutionId,
    'researcher_id': researcherId,
    'title': title,
    'involves_minors': involvesMinors,
    'status': _enumToJson(status),
    'form_version': formVersion,
    'form_hash': formHash,
  };
}

class StudyDraft {
  final String title;
  final bool involvesMinors;
  const StudyDraft({required this.title, required this.involvesMinors});
}

class ConsentSection {
  final String id;
  final String studyId;
  final int order;
  final String language; // code from languages.dart: 'en', 'hz', 'naq', 'ktz', ...
  final String text;
  final int? sourcePage; // page of the proposal the AI took this from
  final String?
  sourceQuote; // exact text in the proposal (shown on "Why?" sheet)
  final List<String> changes; // what the AI changed, one entry per change
  final Confidence? confidence;
  final String?
  requiredElement; // which required consent element this covers, e.g. 'purpose', 'risks'
  final SectionStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  const ConsentSection({
    required this.id,
    required this.studyId,
    required this.order,
    required this.language,
    required this.text,
    this.sourcePage,
    this.sourceQuote,
    this.changes = const [],
    this.confidence,
    this.requiredElement,
    required this.status,
    this.approvedBy,
    this.approvedAt,
  });

  factory ConsentSection.fromJson(Map<String, dynamic> j) => ConsentSection(
    id: j['id'] as String,
    studyId: j['study_id'] as String,
    order: j['order'] as int,
    language: j['language'] as String,
    text: j['text'] as String,
    sourcePage: j['source_page'] as int?,
    sourceQuote: j['source_quote'] as String?,
    changes: ((j['changes'] as List?) ?? const []).cast<String>(),
    confidence: j['confidence'] == null
        ? null
        : _enumFromJson(Confidence.values, j['confidence']),
    requiredElement: j['required_element'] as String?,
    status: _enumFromJson(SectionStatus.values, j['status']),
    approvedBy: j['approved_by'] as String?,
    approvedAt: _dtOrNull(j['approved_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'study_id': studyId,
    'order': order,
    'language': language,
    'text': text,
    'source_page': sourcePage,
    'source_quote': sourceQuote,
    'changes': changes,
    'confidence': confidence == null ? null : _enumToJson(confidence!),
    'required_element': requiredElement,
    'status': _enumToJson(status),
    'approved_by': approvedBy,
    'approved_at': approvedAt == null ? null : _dt(approvedAt!),
  };
}

class Participant {
  final String id;
  final String studyId;
  final String language;
  final bool isMinor;
  const Participant({
    required this.id,
    required this.studyId,
    required this.language,
    required this.isMinor,
  });

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
    id: j['id'] as String,
    studyId: j['study_id'] as String,
    language: j['language'] as String,
    isMinor: j['is_minor'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'study_id': studyId,
    'language': language,
    'is_minor': isMinor,
  };
}

class ParticipantDraft {
  final String studyId;
  final String language;
  final bool isMinor;
  const ParticipantDraft({
    required this.studyId,
    required this.language,
    required this.isMinor,
  });
}

class Consent {
  final String id;
  final String studyId;
  final String participantId;
  final String language;
  final ConsentDecision decision;
  final ConsentMethod method;
  final String? witnessName;
  final String? interpreterName;
  final bool? guardianConsent; // minors only
  final bool? childAssent; // minors only; a "no" always stops participation

  /// Exactly which version of the form the participant saw and answered.
  final int formVersion;
  final String formHash;

  final DateTime signedAt; // device time
  final DateTime? receivedAt; // server time, null until synced
  final DateTime? withdrawnAt;
  final String? withdrawalReason;
  const Consent({
    required this.id,
    required this.studyId,
    required this.participantId,
    required this.language,
    required this.decision,
    required this.method,
    this.witnessName,
    this.interpreterName,
    this.guardianConsent,
    this.childAssent,
    required this.formVersion,
    required this.formHash,
    required this.signedAt,
    this.receivedAt,
    this.withdrawnAt,
    this.withdrawalReason,
  });

  factory Consent.fromJson(Map<String, dynamic> j) => Consent(
    id: j['id'] as String,
    studyId: j['study_id'] as String,
    participantId: j['participant_id'] as String,
    language: j['language'] as String,
    decision: _enumFromJson(ConsentDecision.values, j['decision']),
    method: _enumFromJson(ConsentMethod.values, j['method']),
    witnessName: j['witness_name'] as String?,
    interpreterName: j['interpreter_name'] as String?,
    guardianConsent: j['guardian_consent'] as bool?,
    childAssent: j['child_assent'] as bool?,
    formVersion: j['form_version'] as int,
    formHash: j['form_hash'] as String,
    signedAt: DateTime.parse(j['signed_at'] as String),
    receivedAt: _dtOrNull(j['received_at']),
    withdrawnAt: _dtOrNull(j['withdrawn_at']),
    withdrawalReason: j['withdrawal_reason'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'study_id': studyId,
    'participant_id': participantId,
    'language': language,
    'decision': _enumToJson(decision),
    'method': _enumToJson(method),
    'witness_name': witnessName,
    'interpreter_name': interpreterName,
    'guardian_consent': guardianConsent,
    'child_assent': childAssent,
    'form_version': formVersion,
    'form_hash': formHash,
    'signed_at': _dt(signedAt),
    'received_at': receivedAt == null ? null : _dt(receivedAt!),
    'withdrawn_at': withdrawnAt == null ? null : _dt(withdrawnAt!),
    'withdrawal_reason': withdrawalReason,
  };
}

class ConsentDraft {
  final String studyId;
  final String participantId;
  final String language;
  final ConsentDecision decision;
  final ConsentMethod method;
  final String? witnessName;
  final String? interpreterName;
  final bool? guardianConsent;
  final bool? childAssent;

  /// Copied from the Study the participant was shown (Study.formVersion / formHash).
  final int formVersion;
  final String formHash;
  const ConsentDraft({
    required this.studyId,
    required this.participantId,
    required this.language,
    required this.decision,
    required this.method,
    this.witnessName,
    this.interpreterName,
    this.guardianConsent,
    this.childAssent,
    required this.formVersion,
    required this.formHash,
  });
}

class AuditEntry {
  final String id;
  final String institutionId; // set by server
  final String studyId; // lets forStudy() filter
  final String actorId; // set by server from the logged-in user
  final AuditAction action;
  final String entityId;
  final DateTime createdAt; // device time
  final DateTime? receivedAt; // server time, null until synced
  const AuditEntry({
    required this.id,
    required this.institutionId,
    required this.studyId,
    required this.actorId,
    required this.action,
    required this.entityId,
    required this.createdAt,
    this.receivedAt,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'] as String,
    institutionId: j['institution_id'] as String,
    studyId: j['study_id'] as String,
    actorId: j['actor_id'] as String,
    action: _enumFromJson(AuditAction.values, j['action']),
    entityId: j['entity_id'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    receivedAt: _dtOrNull(j['received_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'institution_id': institutionId,
    'study_id': studyId,
    'actor_id': actorId,
    'action': _enumToJson(action),
    'entity_id': entityId,
    'created_at': _dt(createdAt),
    'received_at': receivedAt == null ? null : _dt(receivedAt!),
  };
}
