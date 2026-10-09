import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../dashboard/dashboard_components.dart';
import '../preferences/accessibility_preferences.dart';
import 'project_data.dart';
import 'project_widgets.dart';

/// Figma Screen Artboards 03.4 Project detail.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/projects');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref
        .watch(projectsProvider)
        .where((p) => p.id == projectId)
        .firstOrNull;
    final primary = Theme.of(context).colorScheme.primary;

    final header = Row(
      children: [
        AppBackButton(onPressed: () => _back(context)),
        const Spacer(),
        if (project != null) ...[
          ProjectCircleButton(
            icon: 'projects/download',
            label: 'Export responses',
            onPressed: () => showProjectNotice(
              context,
              'Export responses',
              'PDF, Word and CSV export will be connected in the Insights task.',
            ),
          ),
          const SizedBox(width: 4),
          ProjectCircleButton(
            icon: 'projects/dots',
            label: 'More project options',
            color: AppColors.subtle,
            onPressed: () => showProjectNotice(
              context,
              project.title,
              'Rename, duplicate and close will be connected with the project data source.',
            ),
          ),
        ],
      ],
    );

    // Edge swipe back (Figma: "back reverses it, button or swipe").
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 600) _back(context);
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            key: PageStorageKey('project-$projectId'),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: project == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 16),
                      Text(
                        'Project not found',
                        style: dashboardText(26, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'It may have been removed, or projects are not connected yet.',
                        style: dashboardText(14, color: AppColors.subtle),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      Semantics(
                        header: true,
                        child: Text(
                          project.title,
                          style: dashboardText(26, weight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (project.ethicsRef != null)
                        ProjectBadge(
                          icon: 'projects/shield',
                          label:
                              'Ethics: ${project.ethicsRef} · valid to ${project.ethicsValidTo}',
                          fill: institutionTint(ref, context),
                          ink: primary,
                        )
                      else
                        ProjectStatusBadge(project.status),
                      const SizedBox(height: 14),
                      _Stats(project: project),
                      const SizedBox(height: 18),
                      _SectionTitle('Consent form'),
                      const SizedBox(height: 10),
                      _FormCard(project: project),
                      const SizedBox(height: 18),
                      _SectionTitle('Collect consent'),
                      const SizedBox(height: 10),
                      _StartCapture(project: project),
                      const SizedBox(height: 12),
                      _OtherWays(project: project),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: dashboardText(17, weight: FontWeight.w600)),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget stat(int value, String label, Color color) => Expanded(
      child: Semantics(
        label: '$value $label',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: dashboardText(30, color: color, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(label, style: dashboardText(13, color: AppColors.subtle)),
          ],
        ),
      ),
    );
    final stats = [
      (project.consented, 'Consented', primary),
      (project.declined, 'Declined', AppColors.ink),
      (project.withdrew, 'Withdrew', AppColors.ink),
    ];
    // At large text sizes three columns would split words, so stack them.
    final stacked = MediaQuery.textScalerOf(context).scale(13) > 19;
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (value, label, color) in stats)
                  Semantics(
                    label: '$value $label',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            '$value',
                            style: dashboardText(
                              30,
                              color: color,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            label,
                            style: dashboardText(13, color: AppColors.subtle),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (value, label, color) in stats)
                  stat(value, label, color),
              ],
            ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasForm = project.formTitle != null;
    final source = project.formSource;
    return DashboardAction(
      label: hasForm ? 'Open ${project.formTitle}' : 'Create a consent form',
      onPressed: () => showProjectNotice(
        context,
        hasForm ? project.formTitle! : 'Create a consent form',
        'The form builder will be connected in the New consent (AI drafting) task.',
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormThumb(color: primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    project.formTitle ?? 'No consent form yet',
                    style: dashboardText(15, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source ?? 'Upload your proposal and the AI drafts one.',
                    style: dashboardText(12, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 10),
                  if (project.formApproved != null)
                    ProjectBadge(
                      icon: 'projects/check',
                      label: project.formApproved!,
                      fill: AppColors.brand50,
                      ink: AppColors.brandDark,
                    )
                  else if (hasForm)
                    const ProjectBadge(
                      label: 'Not approved yet',
                      fill: Color(0xFFFEF4E2),
                      ink: Color(0xFF9A5B00),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormThumb extends StatelessWidget {
  const _FormThumb({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    height: 88,
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(42, 5, color),
        for (final w in <double>[42, 30, 42, 30, 42, 30]) ...[
          const SizedBox(height: 5),
          _line(w, 4, const Color(0xFFCBD0CE)),
        ],
      ],
    ),
  );
  Widget _line(double w, double h, Color c) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
  );
}

class _StartCapture extends ConsumerWidget {
  const _StartCapture({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = project.canCollect;
    final reason = switch (project.status) {
      ProjectStatus.awaitingEthics =>
        'Available once ethics approval is added.',
      ProjectStatus.draft => 'Create and approve a consent form first.',
      ProjectStatus.closed => 'This project is closed.',
      ProjectStatus.collecting => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(
          opacity: enabled ? 1 : .45,
          child: DashboardAction(
            label: enabled
                ? 'Start field capture'
                : 'Start field capture, unavailable',
            radius: 40,
            color: primary,
            onPressed: enabled
                ? () => context.go('/capture')
                : () => showProjectNotice(
                    context,
                    'Start field capture',
                    reason ?? '',
                  ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: large ? 72 : 60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DashboardIcon('mic', color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Start field capture',
                        textAlign: TextAlign.center,
                        style: dashboardText(
                          16,
                          color: Colors.white,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (reason != null) ...[
          const SizedBox(height: 6),
          Text(reason, style: dashboardText(13, color: AppColors.muted)),
        ],
      ],
    );
  }
}

class _OtherWays extends StatelessWidget {
  const _OtherWays({required this.project});
  final Project project;
  @override
  Widget build(BuildContext context) {
    Widget row(String icon, String title, String subtitle, String message) =>
        DashboardAction(
          label: title,
          radius: 18,
          onPressed: () => showProjectNotice(context, title, message),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brand50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DashboardIcon(icon, color: AppColors.brandDark),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: dashboardText(16, weight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: dashboardText(13, color: AppColors.subtle),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const DashboardIcon(
                  'chevron_right',
                  size: 20,
                  color: AppColors.subtle,
                ),
              ],
            ),
          ),
        );
    return _Card(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        children: [
          row(
            'projects/link',
            'Share link / QR code',
            'Participant fills on their own phone',
            'Sharing links and QR codes will be connected with the sync service.',
          ),
          row(
            'projects/download',
            'Export blank form',
            'PDF or Word to print',
            'Blank form export will be connected in the Insights task.',
          ),
        ],
      ),
    );
  }
}
