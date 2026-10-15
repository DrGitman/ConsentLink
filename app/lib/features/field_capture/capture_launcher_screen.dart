import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../minors/minors_data.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_data.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart' show EmptyCard, StaggerIn;
import '../settings/settings_widgets.dart' show RadioDot;
import '../templates/template_widgets.dart' show SheetHandle, VoiceTextField;
import 'field_capture_data.dart';

/// Figma 13.7 Capture tab. Field capture itself (06.1–06.6) is full screen
/// and needs a project, so the tab lists the projects that are collecting
/// and starts the flow for the one you pick.
class CaptureLauncherScreen extends ConsumerStatefulWidget {
  const CaptureLauncherScreen({super.key});
  @override
  ConsumerState<CaptureLauncherScreen> createState() =>
      _CaptureLauncherScreenState();
}

class _CaptureLauncherScreenState extends ConsumerState<CaptureLauncherScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _language = 'All languages';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _start(Project project) =>
      context.push('/field-capture?project=${project.id}');

  Future<void> _filter(List<Project> collecting) async {
    final languages = [
      'All languages',
      ...{for (final p in collecting) p.languages},
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 19),
            Text(
              'Filter by language',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'The language the consent form is collected in.',
              style: dashboardText(13, color: AppColors.subtle),
            ),
            const SizedBox(height: 8),
            for (final l in languages)
              Semantics(
                selected: l == _language,
                inMutuallyExclusiveGroup: true,
                child: DashboardAction(
                  label: l,
                  radius: 16,
                  onPressed: () {
                    setState(() => _language = l);
                    Navigator.pop(sheet);
                  },
                  child: SizedBox(
                    height: 52,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l,
                            style: dashboardText(
                              16,
                              weight: l == _language
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        RadioDot(selected: l == _language),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(fieldCapturePreviewProvider);
    final query = _search.text.trim().toLowerCase();
    final collecting = [
      for (final p in ref.watch(projectsProvider))
        if (p.canCollect) p,
    ];
    final visible = [
      for (final p in collecting)
        if ((_language == 'All languages' || p.languages == _language) &&
            (query.isEmpty ||
                p.title.toLowerCase().contains(query) ||
                p.languages.toLowerCase().contains(query)))
          p,
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          key: const PageStorageKey('capture-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Field capture',
                        key: const ValueKey('page-title-capture'),
                        style: dashboardText(32, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                  ProjectCircleButton(
                    icon: 'search',
                    label: _searching ? 'Close search' : 'Search projects',
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _search.clear();
                    }),
                  ),
                  const SizedBox(width: 4),
                  ProjectCircleButton(
                    icon: 'responses/filter',
                    label: 'Filter by language',
                    onPressed: () => _filter(collecting),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Pick the project you are collecting for, then hand the phone '
                'to the participant.',
                style: dashboardText(
                  14,
                  color: AppColors.muted,
                ).copyWith(height: 1.35),
              ),
              if (_searching) ...[
                const SizedBox(height: 12),
                VoiceTextField(
                  controller: _search,
                  hint: 'Search projects',
                  icon: 'search',
                  fieldLabel: 'Search projects',
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 14),
              const ProjectBadge(
                label: 'Offline · saving on this phone',
                icon: 'wifi_off',
                fill: Color(0xFFFEF4E2),
                ink: Color(0xFF9A5B00),
              ),
              if (_language != 'All languages') ...[
                const SizedBox(height: 8),
                _FilterChip(
                  label: _language,
                  onClear: () => setState(() => _language = 'All languages'),
                ),
              ],
              const SizedBox(height: 14),
              if (visible.isEmpty)
                EmptyCard(
                  title: preview
                      ? 'No projects match'
                      : 'No projects are collecting',
                  message: preview
                      ? 'Try another language or clear the search.'
                      : 'A project can collect consent once its ethics '
                            'approval is on file and its form is approved.',
                )
              else
                for (final (i, project) in visible.indexed)
                  StaggerIn(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CaptureCard(
                        project: project,
                        minors:
                            ref
                                .watch(minorsSettingsProvider)[project.id]
                                ?.includesMinors ??
                            false,
                        onStart: () => _start(project),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Figma 13.7 card: project, languages and progress, then Start.
class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.project,
    required this.minors,
    required this.onStart,
  });
  final Project project;
  final bool minors;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(project.title, style: dashboardText(16, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          '${project.languages} · ${project.consented} of ${project.target} '
          'participants',
          style: dashboardText(13, color: AppColors.subtle),
        ),
        if (minors) ...[
          const SizedBox(height: 8),
          const ProjectBadge(
            label: 'Guardian + assent needed',
            icon: 'capture/users',
            fill: AppColors.canvas,
            ink: AppColors.muted,
          ),
        ],
        const SizedBox(height: 12),
        ConsentPillButton(
          label: 'Start field capture',
          icon: 'capture/play',
          height: 48,
          onPressed: onStart,
        ),
      ],
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label: '$label filter, clear',
    radius: 19,
    color: Colors.transparent,
    onPressed: onClear,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: dashboardText(
              13,
              color: AppColors.muted,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          const DashboardIcon('consent/x', color: AppColors.subtle, size: 16),
        ],
      ),
    ),
  );
}
