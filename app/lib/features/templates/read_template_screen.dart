import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import 'template_data.dart';
import 'template_upload_service.dart';
import 'template_widgets.dart';

/// Figma 05.2 reviews the real style and section analysis from the service.
class ReadTemplateScreen extends ConsumerStatefulWidget {
  const ReadTemplateScreen({super.key});
  @override
  ConsumerState<ReadTemplateScreen> createState() => _ReadTemplateScreenState();
}

class _ReadTemplateScreenState extends ConsumerState<ReadTemplateScreen> {
  void _back() => context.canPop() ? context.pop() : context.go('/templates');

  Future<void> _edit(TemplateRule rule) async {
    final value = await showRuleEditor(context, rule);
    if (value == null || !mounted) return;
    ref.read(detectedRulesProvider.notifier).state = [
      for (final r in ref.read(detectedRulesProvider))
        r.key == rule.key
            ? r.copyWith(value: value, confidence: () => null)
            : r,
    ];
  }

  Future<void> _save() async {
    final analysis = ref.read(uploadedTemplateProvider);
    if (analysis == null) return;
    final result = await showSaveTemplateSheet(
      context,
      suggestedName: analysis.fileName.replaceFirst(
        RegExp(r'\.[^.]+$'),
        '',
      ),
    );
    if (result == null || !mounted) return;
    final rules = ref.read(detectedRulesProvider);
    ref
        .read(templateLibraryProvider.notifier)
        .add(
          StudioTemplate(
            id: 'upload-${DateTime.now().microsecondsSinceEpoch}',
            name: result.$1,
            owner: 'You',
            meta: 'You · edited today',
            access: result.$2,
            mine: true,
            rules: rules,
            sourceStoragePath: analysis.storagePath,
            sections: [...baseSections, ...analysis.sections],
          ),
        );
    ref.read(templateFilterProvider.notifier).state = TemplateFilter.all;
    if (!mounted) return;
    showOverlayToast(
      context,
      kind: AppToastKind.success,
      title: 'Template saved',
      subtitle: result.$2 == TemplateAccess.pending
          ? '${result.$1} · sent to the ethics office'
          : result.$1,
    );
    context.go('/templates');
  }

  @override
  Widget build(BuildContext context) {
    final analysis = ref.watch(uploadedTemplateProvider);
    if (analysis == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyCard(
                    title: 'No template analysis',
                    message:
                        'Choose a PDF or DOCX file to start template analysis.',
                  ),
                  TextButton(
                    onPressed: _back,
                    child: const Text('Back to templates'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final rules = ref.watch(detectedRulesProvider);
    final crop = ref.watch(logoCropProvider);
    final sections = analysis.sections;
    final tint = institutionTint(ref, context);
    final primary = Theme.of(context).colorScheme.primary;
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
                          title: 'Read from template',
                        ),
                        const SizedBox(height: 10),
                        _UploadedCard(analysis: analysis),
                        const SizedBox(height: 16),
                        Text(
                          'Detected style — tap to change',
                          style: dashboardText(
                            14,
                            color: AppColors.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        WhiteCard(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                          child: Column(
                            children: [
                              for (final (i, rule) in rules.indexed)
                                StaggerIn(
                                  index: i,
                                  child: _DetectedRow(
                                    rule: rule,
                                    tint: tint,
                                    onTap: () => _edit(rule),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Detected sections',
                          style: dashboardText(
                            14,
                            color: AppColors.muted,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Best-effort extraction. Review this text; required '
                          'consent elements and official wording are not verified.',
                          style: dashboardText(12, color: AppColors.subtle),
                        ),
                        const SizedBox(height: 9),
                        if (sections.isEmpty)
                          const EmptyCard(
                            title: 'No headings detected',
                            message:
                                'The file was analyzed, but no text sections '
                                'could be identified. You can add content after '
                                'saving the template.',
                          )
                        else
                          TemplateSectionsCard(
                            sections: sections,
                            collapseAfter: 3,
                            onOpen: (section) => showSectionEditor(
                              context,
                              section,
                              readOnly: true,
                            ),
                          ),
                        if (analysis.logoCandidates.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          StaggerIn(
                            index: rules.length,
                            child: DashboardAction(
                              label:
                                  'Logo candidate found on page '
                                  '${analysis.logoCandidates.first['page']}. '
                                  'Adjust the crop',
                              onPressed: () => context.push('/templates/clip'),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 72,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    18,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: primary,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'LOGO',
                                          style: dashboardText(
                                            11,
                                            color: Colors.white,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              crop == null
                                                  ? 'Logo candidate found on page '
                                                        '${analysis.logoCandidates.first['page']}'
                                                  : 'Logo clipped',
                                              style: dashboardText(
                                                15,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              crop == null
                                                  ? 'Tap to adjust the crop'
                                                  : 'Transparent PNG · tap to adjust',
                                              style: dashboardText(
                                                12,
                                                color: primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      DashboardIcon(
                                        'templates/crop',
                                        color: primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: ConsentPillButton(
                    label: 'Save template',
                      onPressed: _save,
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

class _UploadedCard extends StatelessWidget {
  const _UploadedCard({required this.analysis});
  final TemplateUploadResult analysis;
  @override
  Widget build(BuildContext context) => WhiteCard(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            analysis.detectedType == 'application/pdf' ? 'PDF' : 'DOCX',
            style: dashboardText(
              11,
              color: AppColors.info,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                analysis.fileName,
                style: dashboardText(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 150 : 250,
                  ),
                  child: const PopIn(
                    key: ValueKey('safe'),
                    child: ProjectBadge(
                      label: 'Safety scan passed',
                      icon: 'projects/shield',
                      fill: AppColors.brand50,
                      ink: AppColors.brandDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DetectedRow extends StatelessWidget {
  const _DetectedRow({
    required this.rule,
    required this.tint,
    required this.onTap,
  });
  final TemplateRule rule;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final (fill, ink, label) = switch (rule.confidence) {
      'High' => (AppColors.brand50, AppColors.brandDark, 'High'),
      'Medium' => (const Color(0xFFFEF4E2), const Color(0xFF9A5B00), 'Medium'),
      'Low' => (const Color(0xFFFDECEC), AppColors.error, 'Low'),
      _ => (AppColors.canvas, AppColors.muted, 'Edited'),
    };
    return DashboardAction(
      label: '${rule.title}, ${rule.value}, confidence $label. Tap to change',
      radius: 16,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 62),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DashboardIcon(rule.icon, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.value,
                      style: dashboardText(13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ProjectBadge(label: label, fill: fill, ink: ink),
            ],
          ),
        ),
      ),
    );
  }
}
