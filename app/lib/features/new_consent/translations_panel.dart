import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../ai/language/review_status.dart';
import '../../ai/language/translated_form.dart';
import '../../contracts/languages.dart';
import '../../contracts/models.dart' as m;
import '../../core/data/data_revision.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/repository_providers.dart';
import '../ai_assist/on_device_assistant.dart';
import '../dashboard/dashboard_components.dart';
import '../offline/language_packs.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';
import 'review_draft_screen.dart' show sheetMotion;

/// Languages offered on Review draft (04.3): all ten. Each gets an AI draft
/// from the team dictionaries, or reviewed pack text, that a fluent speaker
/// checks. The preview shows Figma's Otjiherero.
final draftLanguagesProvider = Provider<List<String>>((ref) {
  if (ref.watch(newConsentPreviewProvider)) {
    return const ['English', 'Otjiherero'];
  }
  return [for (final l in consentLanguages) l.displayName];
});

/// The draft's saved translations in [code], by element key.
final draftTranslationsProvider =
    FutureProvider.family<Map<String, m.ConsentSection>, String>((
      ref,
      code,
    ) async {
      ref.watch(dataRevisionProvider);
      final id = ref.watch(consentDraftProvider.select((d) => d.studyId));
      if (id == null) return const {};
      final repo = await ref.watch(studyRepositoryProvider.future);
      return {
        for (final s in await repo.getSections(id))
          if (s.language == code && s.requiredElement != null)
            s.requiredElement!: s,
      };
    });

/// Saves a checked translation of [section] and records its approval. The
/// reviewer is kept in the section's change log.
Future<void> saveTranslation(
  WidgetRef ref, {
  required String code,
  required DraftSection section,
  required String text,
  String? reviewer,
  ReviewerFluency fluency = ReviewerFluency.fluent,
  String? existingId,
}) async {
  final draft = ref.read(consentDraftProvider);
  final studyId = draft.studyId;
  if (studyId == null) return;
  final repo = await ref.read(studyRepositoryProvider.future);
  final id = existingId ?? const Uuid().v4();
  await repo.saveSection(
    m.ConsentSection(
      id: id,
      studyId: studyId,
      order: draft.sections.indexWhere((s) => s.key == section.key),
      language: code,
      text: text.trim(),
      changes: [
        if (reviewer != null && reviewer.trim().isNotEmpty)
          'Translation checked by ${reviewer.trim()} '
              '(${fluency == ReviewerFluency.firstLanguage ? 'first language' : 'fluent'})'
        else
          uncheckedTranslationNote,
      ],
      requiredElement: section.key,
      status: m.SectionStatus.draft,
    ),
  );
  await repo.approveSection(id);
  ref.read(dataRevisionProvider.notifier).state++;
}

/// Change log entry of a translation no fluent speaker has checked yet
/// (allowed for now by the lecturer; revisit with reviewers later).
const uncheckedTranslationNote =
    'AI translation · not yet checked by a fluent speaker';

/// Drafts and saves every section of [language] that has no translation
/// yet. Returns how many were saved.
Future<int> translateAll(WidgetRef ref, String code) async {
  final draft = ref.read(consentDraftProvider);
  final saved = await ref.read(draftTranslationsProvider(code).future);
  final assistant = ref.read(onDeviceAssistantProvider);
  var done = 0;
  for (final section in draft.sections) {
    if (saved.containsKey(section.key)) continue;
    final t = await draftTranslation(assistant, section.text, code);
    if (t == null) continue;
    await saveTranslation(ref, code: code, section: section, text: t.text);
    done++;
  }
  return done;
}

/// 04.3 in a participant language: each section's checked translation, or
/// what is still missing. A language reaches participants only when every
/// section has one (see captureLanguagesProvider).
class TranslationPanel extends ConsumerWidget {
  const TranslationPanel({super.key, required this.language});
  final String language;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = languageCodeOf(language);
    final draft = ref.watch(consentDraftProvider);
    final saved =
        ref.watch(draftTranslationsProvider(code)).valueOrNull ?? const {};
    final pack =
        (ref.watch(installedPacksProvider).valueOrNull ?? const {})[code];
    final done = draft.sections.where((s) => saved.containsKey(s.key)).length;
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEEFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$done of ${draft.sections.length} sections are in $language. '
            'Participants are offered $language once every section is; until '
            'then they read English. AI translations show as not yet checked '
            'until a fluent speaker reviews them.',
            style: dashboardText(12, color: const Color(0xFF2E318F)),
          ),
        ),
        if (done < draft.sections.length)
          _TranslateAllButton(code: code, language: language),
        const SizedBox(height: 10),
        for (final section in draft.sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: dashboardText(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  if (saved[section.key] case final t?) ...[
                    Text(
                      t.text,
                      style: dashboardText(14).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t.changes.isEmpty ? 'Saved' : t.changes.first,
                      style: dashboardText(
                        12,
                        color: t.changes.contains(uncheckedTranslationNote)
                            ? const Color(0xFF7A4700)
                            : AppColors.brandDark,
                      ),
                    ),
                  ] else
                    Text(
                      'No $language text yet.',
                      style: dashboardText(13, color: AppColors.subtle),
                    ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _translate(
                        context,
                        ref,
                        code: code,
                        language: language,
                        section: section,
                        existing: saved[section.key],
                        packText: reviewedSection(pack, section.key),
                      ),
                      child: Text(
                        saved.containsKey(section.key)
                            ? 'Change'
                            : 'Add translation',
                        style: TextStyle(color: primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _translate(
  BuildContext context,
  WidgetRef ref, {
  required String code,
  required String language,
  required DraftSection section,
  required m.ConsentSection? existing,
  required TranslatedSection? packText,
}) async {
  final result = await showModalBottomSheet<(String, String?, ReviewerFluency)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    sheetAnimationStyle: sheetMotion(context),
    builder: (_) => _TranslationSheet(
      onDraft: () => draftTranslation(
        ref.read(onDeviceAssistantProvider),
        section.text,
        code,
      ),
      language: language,
      section: section,
      initial: existing?.text ?? packText?.text,
      fromPack: existing == null && packText != null,
      reviewer: packText?.reviewer?.name,
      fluency: packText?.reviewer?.fluency,
    ),
  );
  if (result == null) return;
  await saveTranslation(
    ref,
    code: code,
    section: section,
    text: result.$1,
    reviewer: result.$2,
    fluency: result.$3,
    existingId: existing?.id,
  );
}

class _TranslationSheet extends StatefulWidget {
  const _TranslationSheet({
    required this.onDraft,
    required this.language,
    required this.section,
    required this.initial,
    required this.fromPack,
    this.reviewer,
    this.fluency,
  });
  final Future<TranslationDraft?> Function() onDraft;
  final String language;
  final DraftSection section;
  final String? initial;
  final bool fromPack;
  final String? reviewer;
  final ReviewerFluency? fluency;

  @override
  State<_TranslationSheet> createState() => _TranslationSheetState();
}

class _TranslationSheetState extends State<_TranslationSheet> {
  late final _text = TextEditingController(text: widget.initial ?? '');
  late final _reviewer = TextEditingController(text: widget.reviewer ?? '');
  late ReviewerFluency _fluency = widget.fluency == ReviewerFluency.fluent
      ? ReviewerFluency.fluent
      : ReviewerFluency.firstLanguage;
  bool _checked = false;
  bool _drafting = false;
  String? _draftNote;

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _draftNote = null;
    });
    TranslationDraft? draft;
    try {
      draft = await widget.onDraft();
    } catch (_) {
      draft = null;
    }
    if (!mounted) return;
    setState(() {
      _drafting = false;
      if (draft == null) {
        _draftNote =
            'The AI model is not on this phone (download it in Offline pack), '
            'or its draft dropped a number. Type the translation instead.';
      } else {
        _text.text = draft.text;
        _checked = false;
        _draftNote =
            'AI draft${draft.glossary.isEmpty ? '' : ' using ${draft.glossary.length} words from your team dictionary'}. '
            'It is saved as not yet checked by a fluent speaker; add a '
            'reviewer below once one has read it.';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _reviewer.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _reviewer.dispose();
    super.dispose();
  }

  /// Saving needs the text. A reviewer is optional for now; when one is
  /// named they must have confirmed it against the English.
  bool get _ready =>
      _text.text.trim().isNotEmpty &&
      (_reviewer.text.trim().isEmpty || _checked);

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.section.title} · ${widget.language}',
              style: dashboardText(20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'English',
              style: dashboardText(
                12,
                color: AppColors.subtle,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.section.text,
              style: dashboardText(14).copyWith(height: 1.45),
            ),
            const SizedBox(height: 14),
            if (widget.fromPack)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Filled in with the reviewed standard wording from the '
                  '${widget.language} pack. Use it only if it says the same as '
                  'your English text; otherwise change it.',
                  style: dashboardText(12, color: const Color(0xFF7A4700)),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _drafting ? null : _draft,
                icon: _drafting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(
                  _drafting
                      ? 'Drafting on this phone…'
                      : 'Draft with on-device AI',
                ),
              ),
            ),
            if (_draftNote != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _draftNote!,
                  style: dashboardText(12, color: const Color(0xFF7A4700)),
                ),
              ),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(labelText: '${widget.language} text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reviewer,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Checked by (optional, full name)',
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<ReviewerFluency>(
              segments: const [
                ButtonSegment(
                  value: ReviewerFluency.firstLanguage,
                  label: Text('First language'),
                ),
                ButtonSegment(
                  value: ReviewerFluency.fluent,
                  label: Text('Fluent'),
                ),
              ],
              selected: {_fluency},
              onSelectionChanged: (v) => setState(() => _fluency = v.first),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              title: Text(
                'This person checked the ${widget.language} text against my English text.',
                style: dashboardText(13),
              ),
            ),
            const SizedBox(height: 8),
            ConsentPillButton(
              icon: 'projects/check',
              label: 'Save translation',
              height: 52,
              onPressed: _ready
                  ? () => Navigator.pop(context, (
                      _text.text,
                      _reviewer.text.trim().isEmpty ? null : _reviewer.text,
                      _fluency,
                    ))
                  : null,
            ),
          ],
        ),
      ),
    ),
  );
}

/// "Preview as participant" (04.3): the form as a participant reads it, in
/// the language shown on the review screen.
Future<void> showParticipantPreview(BuildContext context, WidgetRef ref) {
  final draft = ref.read(consentDraftProvider);
  final code = languageCodeOf(draft.language);
  final translated = code == 'en'
      ? const <String, m.ConsentSection>{}
      : ref.read(draftTranslationsProvider(code)).valueOrNull ?? const {};
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          title: Text('As a participant sees it · ${draft.language}'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final s in draft.sections) ...[
              Text(s.title, style: dashboardText(20, weight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                code == 'en'
                    ? s.text
                    : (translated[s.key]?.text ??
                          '${s.text}\n(English: no checked ${draft.language} text yet)'),
                style: dashboardText(18).copyWith(height: 1.5),
              ),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    ),
  );
}

class _TranslateAllButton extends ConsumerStatefulWidget {
  const _TranslateAllButton({required this.code, required this.language});
  final String code;
  final String language;
  @override
  ConsumerState<_TranslateAllButton> createState() =>
      _TranslateAllButtonState();
}

class _TranslateAllButtonState extends ConsumerState<_TranslateAllButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    var saved = 0;
    try {
      saved = await translateAll(ref, widget.code);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved > 0
              ? '$saved sections translated into ${widget.language}.'
              : 'Nothing was translated. Download the AI model in Offline pack, '
                    'or type the translation per section.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: ConsentPillButton(
      icon: _busy ? null : 'sparkle',
      label: _busy
          ? 'Translating on this phone…'
          : 'Translate all with on-device AI',
      filled: false,
      height: 52,
      onPressed: _busy ? null : _run,
    ),
  );
}
