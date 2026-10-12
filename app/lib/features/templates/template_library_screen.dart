import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/skeleton.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import 'template_data.dart';
import 'template_widgets.dart';

/// Figma 05.1 Template library (79:2).
class TemplateLibraryScreen extends ConsumerStatefulWidget {
  const TemplateLibraryScreen({super.key});
  @override
  ConsumerState<TemplateLibraryScreen> createState() =>
      _TemplateLibraryScreenState();
}

class _TemplateLibraryScreenState extends ConsumerState<TemplateLibraryScreen> {
  late final _search = TextEditingController(
    text: ref.read(templateSearchProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  /// Upload starts with choosing a file (sheet), then 05.2 reads it.
  Future<void> _upload() async {
    if (!ref.read(templatesPreviewProvider)) {
      await showProjectNotice(
        context,
        'Upload a template',
        'Template upload and the file scan aren\'t connected yet.',
      );
      return;
    }
    final picked = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _UploadSheet(),
    );
    if (picked != true || !mounted) return;
    ref.read(detectedRulesProvider.notifier).state = detectedRules;
    ref.read(logoCropProvider.notifier).state = null;
    context.push('/templates/read');
  }

  /// The + button: a blank template with the usual defaults, which you then
  /// edit on 05.5 (Upload and Describe are the other two ways in).
  Future<void> _newBlank() async {
    if (!ref.read(templatesPreviewProvider)) {
      await showProjectNotice(
        context,
        'New template',
        'Saving templates will be connected with template storage.',
      );
      return;
    }
    final result = await showSaveTemplateSheet(
      context,
      suggestedName: 'Untitled template',
    );
    if (result == null || !mounted) return;
    final t = ref
        .read(templateLibraryProvider.notifier)
        .add(
          StudioTemplate(
            id: 'blank-${DateTime.now().microsecondsSinceEpoch}',
            name: result.$1,
            owner: 'You',
            meta: 'You · edited today',
            access: result.$2,
            mine: true,
            rules: const [
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
                value: 'Page numbers',
                icon: 'responses/file',
              ),
              TemplateRule(
                key: 'languages',
                title: 'Languages',
                value: 'EN',
                icon: 'form/globe',
              ),
            ],
          ),
        );
    if (mounted) context.push('/templates/view/${t.id}');
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(templateLibraryProvider);
    final filter = ref.watch(templateFilterProvider);
    final query = ref.watch(templateSearchProvider).trim().toLowerCase();
    final preview = ref.watch(templatesPreviewProvider);
    final reduced = reduceMotion(context);
    final visible = [
      for (final t in all)
        if (filter.matches(t) &&
            (query.isEmpty ||
                t.name.toLowerCase().contains(query) ||
                t.owner.toLowerCase().contains(query)))
          t,
    ];

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
                    padding: const EdgeInsets.fromLTRB(0, 9, 0, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: ConsentTopBar(
                            leading: AppBackButton(onPressed: _back),
                            title: 'Templates',
                            trailing: ProjectCircleButton(
                              icon: 'projects/plus',
                              label: 'New blank template',
                              onPressed: _newBlank,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: VoiceTextField(
                            controller: _search,
                            hint: 'Search templates',
                            icon: 'search',
                            fieldLabel: 'Search templates',
                            onChanged: (v) =>
                                ref
                                        .read(templateSearchProvider.notifier)
                                        .state =
                                    v,
                          ),
                        ),
                        const SizedBox(height: 12),
                        PillChips<TemplateFilter>(
                          values: TemplateFilter.values,
                          selected: filter,
                          label: (f) => f.label,
                          onSelected: (f) =>
                              ref.read(templateFilterProvider.notifier).state =
                                  f,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          // Figma 11.6: search, filters and Upload /
                          // Describe stay usable while templates load.
                          child: PreviewLoad(
                            builder: (context, loading) => SkeletonSwitch(
                              loading: loading,
                              label: 'Loading templates',
                              skeleton: TemplatesSkeleton(
                                tint: institutionTint(ref, context),
                                ink: Color.lerp(
                                  institutionTint(ref, context),
                                  Theme.of(context).colorScheme.primary,
                                  .12,
                                )!,
                              ),
                              child: AnimatedSwitcher(
                                duration: Duration(
                                  milliseconds: reduced ? 150 : 250,
                                ),
                                layoutBuilder: (current, previous) => Stack(
                                  alignment: Alignment.topCenter,
                                  children: [...previous, ?current],
                                ),
                                child: Column(
                                  key: ValueKey('$filter-$query'),
                                  children: [
                                    if (!preview)
                                      const EmptyCard(
                                        title: 'No templates yet',
                                        message:
                                            'Your templates and your institution\'s '
                                            'official ones appear here once template '
                                            'storage is connected.',
                                      )
                                    else if (visible.isEmpty)
                                      EmptyCard(
                                        title: query.isEmpty
                                            ? 'No ${filter.label.toLowerCase()} templates'
                                            : 'No matches for “$query”',
                                        message:
                                            'Upload one or describe what you need.',
                                      )
                                    else
                                      for (final (i, t) in visible.indexed)
                                        StaggerIn(
                                          index: i,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: _TemplateCard(
                                              template: t,
                                              onOpen: () => context.push(
                                                '/templates/view/${t.id}',
                                              ),
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: ConsentPillButton(
                          label: 'Upload',
                          icon: 'consent/upload',
                          filled: false,
                          onPressed: _upload,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConsentPillButton(
                          label: 'Describe',
                          icon: 'sparkle',
                          onPressed: () => context.push('/templates/describe'),
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

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onOpen});
  final StudioTemplate template;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label: '${template.name}, ${template.meta}, ${template.access.label}',
    onPressed: onOpen,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 96),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            const TemplateThumb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: dashboardText(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.meta,
                    style: dashboardText(12, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 7),
                  TemplateBadge(template),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const DashboardIcon(
              'chevron_right',
              color: AppColors.subtle,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Choose the file to read. Phone file browsing isn't connected yet, so the
/// preview offers the sample NUST template.
class _UploadSheet extends StatelessWidget {
  const _UploadSheet();
  @override
  Widget build(BuildContext context) {
    Widget option({
      required Widget leading,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool muted = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DashboardAction(
        label: '$title. $subtitle',
        radius: 18,
        color: AppColors.canvas,
        onPressed: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: dashboardText(
                          14,
                          color: muted ? AppColors.muted : AppColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: dashboardText(12, color: AppColors.subtle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const DashboardIcon(
                  'chevron_right',
                  color: AppColors.subtle,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Widget tile(Widget child, Color fill) => Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
    return SingleChildScrollView(
      primary: false,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 19),
          Semantics(
            header: true,
            child: Text(
              'Upload a template',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Word (.docx) or PDF. It\'s scanned on this phone first and any '
            'macros are removed.',
            style: dashboardText(14, color: AppColors.subtle),
          ),
          const SizedBox(height: 16),
          option(
            leading: tile(
              Text(
                'DOCX',
                textScaler: TextScaler.noScaling,
                style: dashboardText(
                  11,
                  color: AppColors.info,
                  weight: FontWeight.w700,
                ),
              ),
              const Color(0xFFEAF1FF),
            ),
            title: uploadedTemplateFile,
            subtitle: 'Sample from the NUST ethics office · 42 KB',
            onTap: () => Navigator.pop(context, true),
          ),
          option(
            leading: tile(
              const DashboardIcon('consent/upload', color: AppColors.muted),
              Colors.white,
            ),
            title: 'Browse files on this phone',
            subtitle: 'Not connected yet',
            muted: true,
            onTap: () => showProjectNotice(
              context,
              'Browse files',
              'Picking files from the phone comes with the file service.',
            ),
          ),
        ],
      ),
    );
  }
}
