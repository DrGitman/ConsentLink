import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution_preferences.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import 'template_data.dart';
import 'template_detail_screen.dart' show TemplatePagePreview;
import 'template_widgets.dart';

/// Figma 13.3 Customise a shared template. Lecturer feedback (15 Oct 2026):
/// a shared template can be copied and changed instead of only used as it
/// is. The copy is private, keeps a link to the original, and the original
/// is never touched.
class CustomiseTemplateScreen extends ConsumerStatefulWidget {
  const CustomiseTemplateScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<CustomiseTemplateScreen> createState() =>
      _CustomiseTemplateScreenState();
}

class _CustomiseTemplateScreenState
    extends ConsumerState<CustomiseTemplateScreen> {
  late final StudioTemplate? _source = ref
      .read(templateLibraryProvider)
      .where((t) => t.id == widget.id)
      .firstOrNull;
  late final TextEditingController _name = TextEditingController(
    text: _source == null ? '' : 'My ${_source.name}',
  );
  late List<TemplateRule> _rules = [...?_source?.rules];
  late List<TemplateSection> _sections = [...?_source?.sections];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/templates');

  Future<void> _editRule(TemplateRule rule) async {
    final value = await showRuleEditor(context, rule);
    if (value == null) return;
    setState(() {
      _rules = [
        for (final r in _rules)
          r.key == rule.key ? r.copyWith(value: value) : r,
      ];
    });
  }

  /// Figma 13.6: reword a section of your copy. Official wording stays
  /// locked, so the sheet opens read-only for those.
  Future<void> _editSection(TemplateSection section) async {
    final edited = await showSectionEditor(context, section);
    if (edited == null) return;
    setState(() {
      _sections = [for (final s in _sections) s.key == edited.key ? edited : s];
    });
  }

  Future<void> _addSection() async {
    final added = await showSectionEditor(
      context,
      TemplateSection(
        key: 'extra-${DateTime.now().microsecondsSinceEpoch}',
        title: '',
        text: '',
      ),
    );
    if (added == null) return;
    setState(() => _sections = [..._sections, added]);
  }

  void _save(StudioTemplate source) {
    final copy = ref
        .read(templateLibraryProvider.notifier)
        .customise(
          source,
          name: _name.text,
          rules: _rules,
          sections: _sections,
        );
    showOverlayToast(
      context,
      kind: AppToastKind.success,
      title: 'Saved to your templates',
      subtitle: '${copy.name} · private copy',
    );
    context.pushReplacement('/templates/view/${copy.id}');
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final tint = institutionTint(ref, context);
    final primary = Theme.of(context).colorScheme.primary;
    final initials = ref.watch(selectedInstitutionProvider)?.initials ?? 'NU';

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsentTopBar(
                          leading: AppBackButton(onPressed: _back),
                          title: 'Customise copy',
                        ),
                        const SizedBox(height: 10),
                        if (source == null)
                          const EmptyCard(
                            title: 'Template not found',
                            message:
                                'It may have been deleted, or template storage '
                                'isn\'t connected yet.',
                          )
                        else ...[
                          RiseIn(
                            child: WhiteCard(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: TemplatePagePreview(
                                  initials: initials,
                                  primary: primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Name of your copy',
                            style: dashboardText(
                              13,
                              color: AppColors.muted,
                              weight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          VoiceTextField(
                            controller: _name,
                            hint: 'My ${source.name}',
                            icon: 'responses/file',
                            fieldLabel: 'Name of your copy',
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          ProjectBadge(
                            label: 'Copy of “${source.name}”',
                            icon: 'templates/copy',
                            fill: tint,
                            ink: primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Private copy · the original stays with '
                            '${source.owner}',
                            style: dashboardText(13, color: AppColors.subtle),
                          ),
                          const SizedBox(height: 14),
                          TemplateSectionsCard(
                            sections: _sections,
                            onOpen: _editSection,
                            onAdd: _addSection,
                            onToggle: (s, included) => setState(() {
                              _sections = [
                                for (final x in _sections)
                                  x.key == s.key
                                      ? x.copyWith(included: included)
                                      : x,
                              ];
                            }),
                          ),
                          const SizedBox(height: 12),
                          WhiteCard(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                            child: Column(
                              children: [
                                for (final rule in _rules)
                                  RuleRow(
                                    rule: rule,
                                    tint: tint,
                                    onTap: () => _editRule(rule),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            constraints: const BoxConstraints(minHeight: 56),
                            decoration: BoxDecoration(
                              color: Color.lerp(Colors.white, primary, .08),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                DashboardIcon('templates/copy', color: primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Your copy keeps a link to the original. '
                                    'Change the name, font, margins and '
                                    'languages freely — the shared original '
                                    'is not affected.',
                                    style: dashboardText(12, color: primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (source != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ConsentPillButton(
                            label: 'Cancel',
                            filled: false,
                            onPressed: _back,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ConsentPillButton(
                            label: 'Save as my template',
                            onPressed: _name.text.trim().isEmpty
                                ? null
                                : () => _save(source),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
