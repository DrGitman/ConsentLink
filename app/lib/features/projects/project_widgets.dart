import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import '../preferences/accessibility_preferences.dart';
import 'project_data.dart';

/// Explains a feature that is not connected yet. Same dialog motion as the
/// dashboard notices: 92% → 100% scale with a fade, fade only with Reduce motion.
Future<void> showProjectNotice(
  BuildContext context,
  String title,
  String message,
) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: Duration(milliseconds: reduced ? 150 : 250),
    pageBuilder: (context, _, _) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (reduced) return fade;
      return ScaleTransition(
        scale: Tween(begin: .92, end: 1.0).animate(curved),
        child: fade,
      );
    },
  );
}

/// White 44 dp circle (72 dp with larger touch targets), as in Figma IconBtn.
class ProjectCircleButton extends ConsumerWidget {
  const ProjectCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.ink,
  });
  final String icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    return SizedBox.square(
      dimension: large ? 72 : 48,
      child: Center(
        child: DashboardAction(
          label: label,
          onPressed: onPressed,
          radius: 40,
          child: SizedBox.square(
            dimension: large ? 72 : 44,
            child: Center(
              child: DashboardIcon(icon, color: color, size: large ? 28 : 22),
            ),
          ),
        ),
      ),
    );
  }
}

class ProjectStatusBadge extends StatelessWidget {
  const ProjectStatusBadge(this.status, {super.key});
  final ProjectStatus status;
  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (status) {
      ProjectStatus.collecting => (AppColors.brand50, AppColors.brandDark),
      ProjectStatus.awaitingEthics => (
        const Color(0xFFFEF4E2),
        const Color(0xFF9A5B00),
      ),
      ProjectStatus.draft => (AppColors.canvas, AppColors.muted),
      ProjectStatus.closed => (AppColors.line, AppColors.muted),
    };
    return ProjectBadge(label: status.label, fill: fill, ink: ink);
  }
}

class ProjectBadge extends StatelessWidget {
  const ProjectBadge({
    super.key,
    required this.label,
    required this.fill,
    required this.ink,
    this.icon,
  });
  final String label;
  final Color fill;
  final Color ink;
  final String? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(icon == null ? 8 : 6, 4, 8, 4),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          DashboardIcon(icon!, color: ink, size: 15),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            label,
            style: dashboardText(12, color: ink, weight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Soft tint of the institution colour for chips and badges. NUST uses the
/// exact Figma value (#E8EBF5).
Color institutionTint(WidgetRef ref, BuildContext context) {
  final institution = ref.watch(selectedInstitutionProvider);
  if (institution == Institution.nust) return const Color(0xFFE8EBF5);
  return Color.lerp(Colors.white, Theme.of(context).colorScheme.primary, .1)!;
}

/// Figma Project card: badge, more button, title, languages, progress.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onMore,
  });
  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final count = project.target == 0
        ? '—'
        : '${project.consented}/${project.target}';
    return DashboardAction(
      label: '${project.title}, ${project.status.label}, $count',
      onPressed: onOpen,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 10, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Flexible so long badges wrap at large text instead of
                // pushing the menu button off the card.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ProjectStatusBadge(project.status),
                  ),
                ),
                const SizedBox(width: 8),
                ProjectCircleButton(
                  icon: 'projects/dots',
                  label: 'More for ${project.title}',
                  color: AppColors.subtle,
                  onPressed: onMore,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: dashboardText(16, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    project.languages,
                    style: dashboardText(13, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ProjectProgressBar(
                          value: project.progress,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40),
                        child: Text(
                          count,
                          style: dashboardText(
                            13,
                            color: primary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

/// 8 dp track; a zero value still shows the 8 dp start dot from Figma.
/// The fill grows in once (400 ms) and is instant with Reduce motion.
class ProjectProgressBar extends StatelessWidget {
  const ProjectProgressBar({
    super.key,
    required this.value,
    required this.color,
  });
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      builder: (context, v, _) => Container(
        height: 8,
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: AppColors.line,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: (constraints.maxWidth * v).clamp(8, constraints.maxWidth),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    ),
  );
}
