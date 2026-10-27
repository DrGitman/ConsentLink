import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../new_consent/consent_draft_data.dart';

/// Sample templates appear only with TEMPLATES_PREVIEW=true or the existing
/// preview flags. Template uploads use the P4 document service; the template
/// assistant remains simulated until its P3 model and P2 storage are connected.
final templatesPreviewProvider = Provider<bool>(
  (ref) =>
      const bool.fromEnvironment('TEMPLATES_PREVIEW') ||
      ref.watch(newConsentPreviewProvider),
);

enum TemplateAccess {
  private('Private', 'form/lock'),
  shared('Shared', 'capture/users'),
  official('Official', 'projects/shield'),
  pending('Official requested', 'projects/shield');

  const TemplateAccess(this.label, this.icon);
  final String label;
  final String icon;
}

enum TemplateFilter {
  all('All'),
  mine('Mine'),
  shared('Shared'),
  official('Official');

  const TemplateFilter(this.label);
  final String label;

  bool matches(StudioTemplate t) => switch (this) {
    TemplateFilter.all => true,
    TemplateFilter.mine => t.mine,
    TemplateFilter.shared => t.access == TemplateAccess.shared,
    TemplateFilter.official => t.access == TemplateAccess.official,
  };
}

class TemplateRule {
  const TemplateRule({
    required this.key,
    required this.title,
    required this.value,
    required this.icon,
    this.confidence,
    this.edited = false,
  });
  final String key;
  final String title;
  final String value;
  final String icon;

  /// 'High' / 'Medium' / 'Low' when the scan detected this rule.
  /// Null when the scan had nothing to report for it, e.g. a rule the
  /// researcher still has to set after review.
  final String? confidence;

  /// True once the researcher has changed the value by hand. Kept separate
  /// from [confidence] so an undetected rule is never shown as edited.
  final bool edited;

  TemplateRule copyWith({
    String? value,
    String? Function()? confidence,
    bool? edited,
  }) => TemplateRule(
    key: key,
    title: title,
    value: value ?? this.value,
    icon: icon,
    confidence: confidence != null ? confidence() : this.confidence,
    edited: edited ?? this.edited,
  );
}

/// One block of consent text inside a template (lecturer feedback,
/// 15 Oct 2026): the structure and wording, not just the styling.
class TemplateSection {
  const TemplateSection({
    required this.key,
    required this.title,
    required this.text,
    this.required = false,
    this.included = true,
    this.locked = false,
  });
  final String key;
  final String title;
  final String text;

  /// One of the 10 required consent elements (G): can't be switched off.
  final bool required;

  /// Optional sections can be left out of your own copy.
  final bool included;

  /// Official wording that a copy may read but not reword.
  final bool locked;

  /// First line for the list, shortened.
  String get preview {
    final one = text.replaceAll('\n', ' ').trim();
    return one.length <= 60 ? one : '${one.substring(0, 57)}…';
  }

  TemplateSection copyWith({String? title, String? text, bool? included}) =>
      TemplateSection(
        key: key,
        title: title ?? this.title,
        text: text ?? this.text,
        required: required,
        included: included ?? this.included,
        locked: locked,
      );
}

/// The sections every consent form starts from: the 10 required elements
/// (G) in plain language, plus two optional ones.
const baseSections = [
  TemplateSection(
    key: 'purpose',
    title: 'Purpose of the study',
    text:
        'We want to learn how families get clean water and how this '
        'affects their health.',
    required: true,
  ),
  TemplateSection(
    key: 'procedures',
    title: 'What you will do',
    text: 'You will answer questions in one interview with the researcher.',
    required: true,
  ),
  TemplateSection(
    key: 'duration',
    title: 'How long it takes',
    text: 'The interview takes about 40 minutes.',
    required: true,
  ),
  TemplateSection(
    key: 'risks',
    title: 'Risks and discomforts',
    text:
        'You may feel tired during the interview. You can rest or stop at '
        'any time. Stopping will not cause you any problem.',
    required: true,
  ),
  TemplateSection(
    key: 'benefits',
    title: 'Possible benefits',
    text: 'Your answers may help improve water services in your area.',
    required: true,
  ),
  TemplateSection(
    key: 'compensation',
    title: 'Payment',
    text: 'You will not be paid for taking part.',
    required: true,
  ),
  TemplateSection(
    key: 'confidentiality',
    title: 'Who will see my answers',
    text:
        'Only the research team. Your name is never written next to your '
        'answers.',
    required: true,
  ),
  TemplateSection(
    key: 'voluntary_withdrawal',
    title: 'Your choice',
    text:
        'Taking part is your choice. You can say no now or stop later '
        'without giving a reason.',
    required: true,
  ),
  TemplateSection(
    key: 'contacts_researcher',
    title: 'Who to contact',
    text: 'You can ask the researcher any question at any time.',
    required: true,
  ),
  TemplateSection(
    key: 'contacts_ethics',
    title: 'Complaints',
    text:
        'You can call the NUST ethics office. The number is on the paper '
        'copy you will get.',
    required: true,
  ),
  TemplateSection(
    key: 'recording',
    title: 'Audio recording',
    text:
        'We record the interview only if you say yes. Recordings are '
        'deleted after the study.',
  ),
  TemplateSection(
    key: 'photos',
    title: 'Photographs',
    text:
        'We take photographs only if you say yes. Faces are blurred '
        'before anything is shared.',
    included: false,
  ),
];

/// Official templates keep their key wording (Figma 05.5 "locked").
List<TemplateSection> lockedSections() => [
  for (final s in baseSections)
    TemplateSection(
      key: s.key,
      title: s.title,
      text: s.text,
      required: s.required,
      included: s.included,
      locked: s.required,
    ),
];

class StudioTemplate {
  const StudioTemplate({
    required this.id,
    required this.name,
    required this.owner,
    required this.meta,
    required this.access,
    required this.rules,
    this.mine = false,
    this.formId,
    this.verified,
    this.customisedFrom,
    this.sourceStoragePath,
    this.sections = baseSections,
  });
  final String id;
  final String name;
  final String owner;

  /// Second line in the library, e.g. "You · edited today".
  final String meta;
  final TemplateAccess access;
  final List<TemplateRule> rules;
  final bool mine;

  /// Matching Form builder template (04.7), when there is one.
  final String? formId;

  /// "Verified with NUST ethics office · v3 · 2 Oct 2026".
  final String? verified;

  /// Name of the shared or official template this copy was customised
  /// from (lecturer feedback, Figma 13.2–13.3). Null for originals.
  final String? customisedFrom;

  /// Storage object created by the template upload service, when available.
  final String? sourceStoragePath;

  /// The consent text inside the template (Figma 13.2 "What's inside").
  final List<TemplateSection> sections;

  /// Sections that end up in the form.
  List<TemplateSection> get usedSections => [
    for (final s in sections)
      if (s.included) s,
  ];

  bool get locked => access == TemplateAccess.official;

  String badge(String institution) => switch (access) {
    TemplateAccess.private => 'Private',
    TemplateAccess.shared => 'Shared · $institution',
    TemplateAccess.official => 'Official · $institution',
    TemplateAccess.pending => 'Official requested',
  };

  String rule(String key) =>
      rules.where((r) => r.key == key).firstOrNull?.value ?? '—';

  StudioTemplate copyWith({
    String? id,
    String? name,
    String? owner,
    String? meta,
    TemplateAccess? access,
    List<TemplateRule>? rules,
    bool? mine,
    String? Function()? verified,
    String? customisedFrom,
    String? Function()? sourceStoragePath,
    List<TemplateSection>? sections,
  }) => StudioTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    owner: owner ?? this.owner,
    meta: meta ?? this.meta,
    access: access ?? this.access,
    rules: rules ?? this.rules,
    mine: mine ?? this.mine,
    formId: formId,
    verified: verified != null ? verified() : this.verified,
    customisedFrom: customisedFrom ?? this.customisedFrom,
    sourceStoragePath: sourceStoragePath != null
        ? sourceStoragePath()
        : this.sourceStoragePath,
    sections: sections ?? this.sections,
  );
}

const _standardRules = [
  TemplateRule(
    key: 'font',
    title: 'Font',
    value: 'Arial 11 pt',
    icon: 'form/type',
  ),
  TemplateRule(
    key: 'margins',
    title: 'Margins',
    value: '2.5 cm',
    icon: 'layers',
  ),
  TemplateRule(
    key: 'footer',
    title: 'Footer',
    value: 'REC no. + page',
    icon: 'responses/file',
  ),
  TemplateRule(
    key: 'languages',
    title: 'Languages',
    value: 'EN | AF',
    icon: 'form/globe',
  ),
];

/// Figma 05.1 rows.
/// Official sample templates keep their wording locked.
final officialSections = lockedSections();

final sampleStudioTemplates = [
  StudioTemplate(
    id: 'my-opuwo',
    name: 'My Opuwo health consent',
    owner: 'You',
    meta: 'You · edited today',
    access: TemplateAccess.private,
    mine: true,
    rules: [
      TemplateRule(
        key: 'font',
        title: 'Font',
        value: 'Arial 11 pt',
        icon: 'form/type',
      ),
      TemplateRule(
        key: 'margins',
        title: 'Margins',
        value: '2.5 cm',
        icon: 'layers',
      ),
      TemplateRule(
        key: 'footer',
        title: 'Footer',
        value: 'Page x of y',
        icon: 'responses/file',
      ),
      TemplateRule(
        key: 'languages',
        title: 'Languages',
        value: 'EN | OTJ',
        icon: 'form/globe',
      ),
    ],
  ),
  StudioTemplate(
    id: 'health-v3',
    name: 'Health research v3',
    owner: 'NUST ethics office',
    meta: 'NUST ethics office · v3',
    access: TemplateAccess.official,
    formId: 'health-v3',
    verified: 'Verified with NUST ethics office · v3 · 2 Oct 2026',
    rules: _standardRules,
    sections: officialSections,
  ),
  StudioTemplate(
    id: 'interview-audio',
    name: 'Interview + audio consent',
    owner: 'J. Kavari',
    meta: 'J. Kavari · used by 12',
    access: TemplateAccess.shared,
    rules: [
      TemplateRule(
        key: 'font',
        title: 'Font',
        value: 'Calibri 12 pt',
        icon: 'form/type',
      ),
      TemplateRule(
        key: 'margins',
        title: 'Margins',
        value: '2 cm',
        icon: 'layers',
      ),
      TemplateRule(
        key: 'footer',
        title: 'Footer',
        value: 'REC no. + page',
        icon: 'responses/file',
      ),
      TemplateRule(
        key: 'languages',
        title: 'Languages',
        value: 'EN | OTJ',
        icon: 'form/globe',
      ),
    ],
  ),
  StudioTemplate(
    id: 'minors-v2',
    name: 'Minors + guardian',
    owner: 'NUST ethics office',
    meta: 'NUST ethics office · v2',
    access: TemplateAccess.official,
    formId: 'minors-v1',
    verified: 'Verified with NUST ethics office · v2 · 14 Aug 2026',
    sections: officialSections,
    rules: [
      TemplateRule(
        key: 'font',
        title: 'Font',
        value: 'Arial 13 pt',
        icon: 'form/type',
      ),
      TemplateRule(
        key: 'margins',
        title: 'Margins',
        value: '2.5 cm',
        icon: 'layers',
      ),
      TemplateRule(
        key: 'footer',
        title: 'Footer',
        value: 'REC no. + page',
        icon: 'responses/file',
      ),
      TemplateRule(
        key: 'languages',
        title: 'Languages',
        value: 'EN | AF',
        icon: 'form/globe',
      ),
    ],
  ),
];

/// Figma 05.2: what the scan read from NUST_HREC_consent_2026.docx.
const detectedRules = [
  TemplateRule(
    key: 'body',
    title: 'Body font',
    value: 'Arial 11 pt',
    icon: 'form/type',
    confidence: 'High',
  ),
  TemplateRule(
    key: 'headings',
    title: 'Headings',
    value: 'Arial Bold 13 pt',
    icon: 'form/type',
    confidence: 'High',
  ),
  TemplateRule(
    key: 'spacing',
    title: 'Line spacing',
    value: '1.15',
    icon: 'form/textsize',
    confidence: 'High',
  ),
  TemplateRule(
    key: 'margins',
    title: 'Margins',
    value: '2.5 cm all sides',
    icon: 'layers',
    confidence: 'Medium',
  ),
  TemplateRule(
    key: 'footer',
    title: 'Footer',
    value: 'REC no. + page x of y',
    icon: 'responses/file',
    confidence: 'Medium',
  ),
];

class TemplateLibrary extends StateNotifier<List<StudioTemplate>> {
  TemplateLibrary(super.state);

  StudioTemplate add(StudioTemplate t) {
    state = [t, ...state];
    return t;
  }

  StudioTemplate duplicate(StudioTemplate t) => add(
    t.copyWith(
      id: '${t.id}-copy-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Copy of ${t.name}',
      owner: 'You',
      meta: 'You · edited today',
      access: TemplateAccess.private,
      mine: true,
      verified: () => null,
    ),
  );

  /// Figma 13.2–13.3: an editable private copy of a shared or official
  /// template, with a link back to where it came from.
  StudioTemplate customise(
    StudioTemplate source, {
    required String name,
    required List<TemplateRule> rules,
    List<TemplateSection>? sections,
  }) => add(
    source.copyWith(
      id: '${source.id}-mine-${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'My ${source.name}' : name.trim(),
      owner: 'You',
      meta: 'You · customised today',
      access: TemplateAccess.private,
      mine: true,
      rules: rules,
      sections: sections ?? source.sections,
      verified: () => null,
      customisedFrom: source.name,
    ),
  );

  /// Replaces the sections of your own template (13.3 / 05.5).
  void updateSections(String id, List<TemplateSection> sections) => state = [
    for (final t in state)
      t.id == id
          ? t.copyWith(meta: 'You · edited today', sections: sections)
          : t,
  ];

  void updateRule(String id, String key, String value) => state = [
    for (final t in state)
      t.id == id
          ? t.copyWith(
              meta: 'You · edited today',
              rules: [
                for (final r in t.rules)
                  r.key == key ? r.copyWith(value: value) : r,
              ],
            )
          : t,
  ];

  void rename(String id, String name) =>
      state = [for (final t in state) t.id == id ? t.copyWith(name: name) : t];

  void remove(String id) => state = [
    for (final t in state)
      if (t.id != id) t,
  ];
}

final templateLibraryProvider =
    StateNotifierProvider<TemplateLibrary, List<StudioTemplate>>(
      (ref) => TemplateLibrary(
        ref.watch(templatesPreviewProvider) ? sampleStudioTemplates : const [],
      ),
    );

final templateFilterProvider = StateProvider<TemplateFilter>(
  (ref) => TemplateFilter.all,
);

final templateSearchProvider = StateProvider<String>((ref) => '');

/// The rules being edited on 05.2 (detected from an upload).
final detectedRulesProvider = StateProvider<List<TemplateRule>>(
  (ref) => detectedRules,
);

/// Logo crop on 05.3, as fractions of the page (left, top, right, bottom).
class LogoCrop {
  const LogoCrop(this.left, this.top, this.right, this.bottom);
  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Figma 05.3: the box hugs the logo (54,152 110×64 on a 330×430 page) with a
/// little margin.
const detectedLogoCrop = LogoCrop(18 / 330, 16 / 430, 144 / 330, 96 / 430);

final logoCropProvider = StateProvider<LogoCrop?>((ref) => null);
