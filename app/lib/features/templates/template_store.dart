import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'template_data.dart';

/// Your templates are kept on this phone (no template storage on the server
/// yet). Saved after every change; read back when the library first opens.
const _key = 'consentlink.templates.v1';

Future<List<StudioTemplate>> loadTemplates() async {
  try {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const [];
    return [
      for (final t in jsonDecode(raw) as List)
        templateFromJson(t as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}

Future<void> saveTemplates(List<StudioTemplate> templates) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final t in templates) templateToJson(t)]),
    );
  } catch (_) {}
}

Map<String, dynamic> templateToJson(StudioTemplate t) => {
  'id': t.id,
  'name': t.name,
  'owner': t.owner,
  'meta': t.meta,
  'access': t.access.name,
  'mine': t.mine,
  'formId': t.formId,
  'verified': t.verified,
  'customisedFrom': t.customisedFrom,
  'sourceStoragePath': t.sourceStoragePath,
  'rules': [
    for (final r in t.rules)
      {
        'key': r.key,
        'title': r.title,
        'value': r.value,
        'icon': r.icon,
        'confidence': r.confidence,
        'edited': r.edited,
      },
  ],
  'sections': [
    for (final s in t.sections)
      {
        'key': s.key,
        'title': s.title,
        'text': s.text,
        'required': s.required,
        'included': s.included,
        'locked': s.locked,
      },
  ],
};

StudioTemplate templateFromJson(Map<String, dynamic> j) => StudioTemplate(
  id: j['id'] as String,
  name: j['name'] as String,
  owner: j['owner'] as String,
  meta: j['meta'] as String,
  access: TemplateAccess.values.byName(j['access'] as String),
  mine: j['mine'] as bool? ?? true,
  formId: j['formId'] as String?,
  verified: j['verified'] as String?,
  customisedFrom: j['customisedFrom'] as String?,
  sourceStoragePath: j['sourceStoragePath'] as String?,
  rules: [
    for (final r in j['rules'] as List)
      TemplateRule(
        key: r['key'] as String,
        title: r['title'] as String,
        value: r['value'] as String,
        icon: r['icon'] as String,
        confidence: r['confidence'] as String?,
        edited: r['edited'] as bool? ?? false,
      ),
  ],
  sections: [
    for (final s in j['sections'] as List)
      TemplateSection(
        key: s['key'] as String,
        title: s['title'] as String,
        text: s['text'] as String,
        required: s['required'] as bool? ?? false,
        included: s['included'] as bool? ?? true,
        locked: s['locked'] as bool? ?? false,
      ),
  ],
);
