import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../new_consent/consent_draft_data.dart';

/// Question types offered in 04.6 "Add a question" (plus the two built-in
/// types used by the default participant-details fields).
enum FieldType {
  shortText('Short answer', 'Short text', 'form/type'),
  paragraph('Paragraph', 'Paragraph', 'form/paragraph'),
  checkboxes('Checkboxes', 'Checkbox', 'form/check'),
  multipleChoice('Multiple choice', 'Choice', 'form/choice'),
  date('Date', 'Date', 'form/calendar'),
  dropdown('Dropdown', 'Dropdown', 'form/dropdown'),
  signature('Signature', 'Signature', 'form/sign'),
  thumbprint('Thumbprint', 'Thumbprint', 'form/fingerprint'),
  audio('Audio answer', 'Audio answer', 'mic'),
  photo('Photo / ID', 'Photo', 'form/image'),
  gps('GPS location', 'Location', 'form/pin'),
  rating('Rating scale', 'Rating', 'form/star'),
  yesNo('Yes / No', 'Yes / No', 'form/calendar'),
  consentCapture('Signature or thumbprint', 'Consent capture', 'form/sign');

  const FieldType(this.pickerLabel, this.summary, this.icon);

  /// Name on the 04.6 tile.
  final String pickerLabel;

  /// Short type name under the question title in 04.5.
  final String summary;
  final String icon;

  /// The 12 tiles of 04.6, in Figma order.
  static const pickable = [
    shortText,
    paragraph,
    checkboxes,
    multipleChoice,
    date,
    dropdown,
    signature,
    thumbprint,
    audio,
    photo,
    gps,
    rating,
  ];
}

/// Matches `FormFieldDef { id, type, label, required, voiceAllowed, order,
/// options }` in the shared contract (Figma Development Diagrams, frame F).
/// [order] is the list position. [icon] overrides the type icon for the
/// sample fields that use a more specific symbol (user, globe, pin).
class FormFieldDef {
  const FormFieldDef({
    required this.id,
    required this.type,
    required this.label,
    this.required = false,
    this.voiceAllowed = true,
    this.options = const [],
    this.icon,
  });
  final String id;
  final FieldType type;
  final String label;
  final bool required;
  final bool voiceAllowed;
  final List<String> options;
  final String? icon;

  String get iconName => icon ?? type.icon;
  String get subtitle => required ? '${type.summary} · required' : type.summary;

  FormFieldDef copyWith({
    String? id,
    String? label,
    bool? required,
    bool? voiceAllowed,
  }) => FormFieldDef(
    id: id ?? this.id,
    type: type,
    label: label ?? this.label,
    required: required ?? this.required,
    voiceAllowed: voiceAllowed ?? this.voiceAllowed,
    options: options,
    icon: icon,
  );
}

/// Figma 04.5 participant-details questions (sample in preview mode).
const sampleFields = [
  FormFieldDef(
    id: 'name',
    type: FieldType.shortText,
    label: 'Name or pseudonym',
    required: true,
    icon: 'form/user',
  ),
  FormFieldDef(
    id: 'age',
    type: FieldType.yesNo,
    label: 'Age confirmation (18+)',
    required: true,
  ),
  FormFieldDef(
    id: 'language',
    type: FieldType.multipleChoice,
    label: 'Preferred language',
    required: true,
    icon: 'form/globe',
    options: ['English', 'Otjiherero'],
  ),
  FormFieldDef(
    id: 'site',
    type: FieldType.shortText,
    label: 'Village / site',
    icon: 'form/pin',
  ),
  FormFieldDef(
    id: 'audio_ok',
    type: FieldType.checkboxes,
    label: 'Audio recording OK?',
  ),
  FormFieldDef(
    id: 'consent',
    type: FieldType.consentCapture,
    label: 'Signature or thumbprint',
    required: true,
  ),
];

/// Outside preview the form still needs a way to record consent.
const defaultFields = [
  FormFieldDef(
    id: 'consent',
    type: FieldType.consentCapture,
    label: 'Signature or thumbprint',
    required: true,
  ),
];

class FormBuilderController extends StateNotifier<List<FormFieldDef>> {
  FormBuilderController(super.fields);
  int _next = 1;

  /// Adds a question of [type] and returns its id.
  String add(FieldType type) {
    final id = 'q${_next++}_${DateTime.now().microsecondsSinceEpoch}';
    state = [
      ...state,
      FormFieldDef(
        id: id,
        type: type,
        label: type.pickerLabel,
        voiceAllowed: !const {
          FieldType.signature,
          FieldType.thumbprint,
          FieldType.photo,
          FieldType.gps,
        }.contains(type),
      ),
    ];
    return id;
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    list.insert(newIndex, list.removeAt(oldIndex));
    state = list;
  }

  void update(String id, FormFieldDef Function(FormFieldDef) change) =>
      state = [for (final f in state) f.id == id ? change(f) : f];

  void remove(String id) => state = [
    for (final f in state)
      if (f.id != id) f,
  ];

  void duplicate(String id) {
    final i = state.indexWhere((f) => f.id == id);
    if (i < 0) return;
    final copy = state[i].copyWith(
      id: '${state[i].id}_copy${_next++}',
      label: '${state[i].label} (copy)',
    );
    state = [...state]..insert(i + 1, copy);
  }
}

final formFieldsProvider =
    StateNotifierProvider<FormBuilderController, List<FormFieldDef>>(
      (ref) => FormBuilderController(
        ref.watch(newConsentPreviewProvider) ? sampleFields : defaultFields,
      ),
    );

/// 04.7 template choices. `official` templates lock their style fields.
class FormTemplate {
  const FormTemplate({
    required this.id,
    required this.name,
    required this.official,
    required this.font,
    required this.lineSpacing,
    required this.margins,
    required this.logo,
  });
  final String id;
  final String name;
  final bool official;
  final String font;
  final String lineSpacing;
  final String margins;
  final String logo;
}

const sampleTemplates = [
  FormTemplate(
    id: 'health-v3',
    name: 'Health research v3',
    official: true,
    font: 'Arial · 11 pt',
    lineSpacing: '1.15',
    margins: '2.5 cm',
    logo: 'NUST crest · top left',
  ),
  FormTemplate(
    id: 'social-v2',
    name: 'Social sciences v2',
    official: false,
    font: 'Calibri · 12 pt',
    lineSpacing: '1.5',
    margins: '2 cm',
    logo: 'NUST crest · top centre',
  ),
  FormTemplate(
    id: 'minors-v1',
    name: 'Minors + guardian',
    official: true,
    font: 'Arial · 13 pt',
    lineSpacing: '1.5',
    margins: '2.5 cm',
    logo: 'NUST crest · top left',
  ),
];

final formTemplatesProvider = Provider<List<FormTemplate>>(
  (ref) => ref.watch(newConsentPreviewProvider) ? sampleTemplates : const [],
);

final selectedTemplateProvider = StateProvider<String?>(
  (ref) => ref.watch(formTemplatesProvider).firstOrNull?.id,
);
