import 'dart:async';

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
import 'template_widgets.dart';

/// Figma 05.2 Detected template styles (3:2571). The uploaded file is
/// scanned first ("Upload & file scan": scanning, then "Safe · macros
/// removed" pops), then the detected rules rise in one after another.
class ReadTemplateScreen extends ConsumerStatefulWidget {
  const ReadTemplateScreen({super.key});
  @override
  ConsumerState<ReadTemplateScreen> createState() => _ReadTemplateScreenState();
}

class _ReadTemplateScreenState extends ConsumerState<ReadTemplateScreen> {
  bool _scanned = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _scanned = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

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
    final result = await showSaveTemplateSheet(
      context,
      suggestedName: 'Opuwo health consent',
    );
    if (result == null || !mounted) return;
    final rules = ref.read(detectedRulesProvider);
    String value(String key) =>
        rules.where((r) => r.key == key).firstOrNull?.value ?? '—';
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
            rules: [
              TemplateRule(
                key: 'font',
                title: 'Font',
                value: value('body'),
                icon: 'form/type',
              ),
              TemplateRule(
                key: 'margins',
                title: 'Margins',
                value: value('margins'),
                icon: 'layers',
              ),
              TemplateRule(
                key: 'footer',
                title: 'Footer',
                value: value('footer'),
                icon: 'responses/file',
              ),
              const TemplateRule(
                key: 'languages',
                title: 'Languages',
                value: 'EN | AF',
                icon: 'form/globe',
              ),
            ],
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
    final rules = ref.watch(detectedRulesProvider);
    final crop = ref.watch(logoCropProvider);
    final tint = institutionTint(ref, context);
    final primary = Theme.of(context).colorScheme.primary;
    final reduced = reduceMotion(context);

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
                        _UploadedCard(scanned: _scanned),
                        const SizedBox(height: 16),
                        AnimatedOpacity(
                          opacity: _scanned ? 1 : 0,
                          duration: Duration(milliseconds: reduced ? 150 : 250),
                          child: Text(
                            'We found these rules — tap to change',
                            style: dashboardText(
                              14,
                              color: AppColors.muted,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 9),
                        if (_scanned) ...[
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
                          const SizedBox(height: 12),
                          StaggerIn(
                            index: rules.length,
                            child: DashboardAction(
                              label: 'Logo found on page 1. Adjust the crop',
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
                                                  ? 'Logo found on page 1'
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
                    onPressed: _scanned ? _save : null,
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
  const _UploadedCard({required this.scanned});
  final bool scanned;
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
            'DOCX',
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
                uploadedTemplateFile,
                style: dashboardText(14, weight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 150 : 250,
                  ),
                  child: scanned
                      ? const PopIn(
                          key: ValueKey('safe'),
                          child: ProjectBadge(
                            label: 'Safe · macros removed',
                            icon: 'projects/shield',
                            fill: AppColors.brand50,
                            ink: AppColors.brandDark,
                          ),
                        )
                      : const _Scanning(key: ValueKey('scanning')),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Scanning extends StatelessWidget {
  const _Scanning({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 12,
          child: reduceMotion(context)
              ? const DashboardIcon('sync', color: AppColors.muted, size: 12)
              : const CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: AppColors.muted,
                ),
        ),
        const SizedBox(width: 6),
        Text(
          'Scanning for macros…',
          style: dashboardText(
            12,
            color: AppColors.muted,
            weight: FontWeight.w600,
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
