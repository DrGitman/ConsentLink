import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../new_consent/consent_draft_data.dart';

/// Sample templates appear only with TEMPLATES_PREVIEW=true or the existing
/// preview flags. Upload, scanning, logo clipping and the template assistant
/// are simulated: the scan service (P4), the on-device model (P3) and template
/// storage (P2) aren't connected yet.
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
  });
  final String key;
  final String title;
  final String value;
  final String icon;

  /// 'High' / 'Medium' when detected from an upload, null when set by hand.
  final String? confidence;

  TemplateRule copyWith({String? value, String? Function()? confidence}) =>
      TemplateRule(
        key: key,
        title: title,
        value: value ?? this.value,
        icon: icon,
        confidence: confidence != null ? confidence() : this.confidence,
      );
}

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
const sampleStudioTemplates = [
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

const uploadedTemplateFile = 'NUST_HREC_consent_2026.docx';

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
