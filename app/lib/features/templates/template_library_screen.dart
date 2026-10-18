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
import 'template_upload_service.dart';
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
  bool _uploading = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _back() => context.canPop() ? context.pop() : context.go('/home');

  /// Selects a template file and loads its service analysis for review.
  Future<void> _upload() async {
    final file = await showModalBottomSheet<TemplateUploadFile>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _UploadSheet(
        pickFile: ref.read(templateFilePickerProvider),
      ),
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final analysis = await ref.read(templateUploadProvider)(file);
      if (!mounted) return;
      ref.read(uploadedTemplateProvider.notifier).state = analysis;
      ref.read(detectedRulesProvider.notifier).state = analysis.rules;
      ref.read(logoCropProvider.notifier).state = null;
      context.push('/templates/read');
    } on TemplateUploadException catch (error) {
      if (mounted) {
        await showProjectNotice(context, 'Template upload failed', error.message);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
                          label: _uploading ? 'Uploading…' : 'Upload',
                          icon: 'consent/upload',
                          filled: false,
                          onPressed: _uploading ? null : _upload,
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

/// Lets the user select a PDF or DOCX for service analysis.
class _UploadSheet extends StatelessWidget {
  const _UploadSheet({required this.pickFile});

  final TemplateFilePicker pickFile;

  @override
  Widget build(BuildContext context) {
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
            'Choose a PDF or DOCX. The service checks the file and extracts '
            'style information and text sections.',
            style: dashboardText(14, color: AppColors.subtle),
          ),
          const SizedBox(height: 16),
          DashboardAction(
            label: 'Browse files on this phone. PDF or DOCX, maximum 25 MB.',
            radius: 18,
            color: AppColors.canvas,
            onPressed: () async {
              try {
                final file = await pickFile();
                if (context.mounted && file != null) {
                  Navigator.pop(context, file);
                }
              } on TemplateUploadException catch (error) {
                if (context.mounted) {
                  await showProjectNotice(
                    context,
                    'Could not select file',
                    error.message,
                  );
                }
              }
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const DashboardIcon(
                        'consent/upload',
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Browse files on this phone',
                            style: dashboardText(14, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'PDF or DOCX · maximum 25 MB',
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
        ],
      ),
    );
  }
}
