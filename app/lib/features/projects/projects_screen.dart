import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/skeleton.dart';
import '../dashboard/dashboard_components.dart';
import '../preferences/accessibility_preferences.dart';
import 'project_actions.dart';
import 'project_data.dart';
import 'project_widgets.dart';

/// Figma Screen Artboards 03.3 Projects.
class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final filter = ref.watch(projectFilterProvider);
    final preview = ref.watch(projectsPreviewProvider);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final search = ref.watch(projectSearchProvider);
    final visible = [
      for (final project in projects)
        if (filter.matches(project) && projectMatches(project, search ?? ''))
          project,
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: CustomScrollView(
          key: const PageStorageKey('projects-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Projects',
                          key: const ValueKey('page-title-projects'),
                          style: dashboardText(32, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                    ProjectCircleButton(
                      icon: 'search',
                      label: 'Search projects',
                      onPressed: () =>
                          ref.read(projectSearchProvider.notifier).state =
                              search == null ? '' : null,
                    ),
                    const SizedBox(width: 4),
                    ProjectCircleButton(
                      icon: 'projects/plus',
                      label: 'New project',
                      // A new project starts from its consent form (04.1).
                      onPressed: () => context.push('/new-consent'),
                    ),
                  ],
                ),
              ),
            ),
            if (search != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        ref.read(projectSearchProvider.notifier).state = v,
                    style: dashboardText(16),
                    decoration: InputDecoration(
                      hintText: 'Search by name, language or ethics number',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12),
                        child: DashboardIcon('search', size: 20),
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Close search',
                        onPressed: () =>
                            ref.read(projectSearchProvider.notifier).state =
                                null,
                        icon: const Icon(Icons.close),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: _FilterChips(
                counts: {
                  for (final f in ProjectFilter.values)
                    f: projects.where(f.matches).length,
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverToBoxAdapter(
                // Figma 11.2: cards are skeletons while projects load.
                child: PreviewLoad(
                  builder: (context, loading) => SkeletonSwitch(
                    loading: loading,
                    label: 'Loading projects',
                    skeleton: const ProjectsSkeleton(),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: reduced ? 150 : 250),
                      switchInCurve: Curves.easeOutCubic,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previous, ?current],
                      ),
                      child: Column(
                        key: ValueKey(filter),
                        children: [
                          if (visible.isEmpty)
                            _EmptyState(
                              preview: preview,
                              filter: filter,
                              searching: (search ?? '').trim().isNotEmpty,
                            )
                          else
                            for (final (i, project) in visible.indexed)
                              _StaggeredIn(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: ProjectCard(
                                    project: project,
                                    onOpen: () =>
                                        context.go('/projects/${project.id}'),
                                    onMore: () =>
                                        showProjectMenu(context, ref, project),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips({required this.counts});
  final Map<ProjectFilter, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(projectFilterProvider);
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return SingleChildScrollView(
      key: const PageStorageKey('projects-filters'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Row(
        children: [
          for (final filter in ProjectFilter.values) ...[
            if (filter != ProjectFilter.values.first) const SizedBox(width: 8),
            Semantics(
              selected: filter == selected,
              child: DashboardAction(
                label: filter == ProjectFilter.all
                    ? 'All projects, ${counts[filter]}'
                    : filter.label,
                radius: 30,
                color: Colors.transparent,
                onPressed: () =>
                    ref.read(projectFilterProvider.notifier).state = filter,
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  constraints: BoxConstraints(minHeight: large ? 56 : 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: filter == selected ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: filter == selected ? primary : AppColors.line,
                    ),
                  ),
                  child: Text(
                    filter == ProjectFilter.all
                        ? 'All ${counts[filter]}'
                        : filter.label,
                    style: dashboardText(
                      14,
                      color: filter == selected
                          ? Colors.white
                          : AppColors.muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cards fade and rise in 35 ms apart (Figma "stagger" token). Static with
/// Reduce motion.
class _StaggeredIn extends StatelessWidget {
  const _StaggeredIn({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = 35 * index.clamp(0, 6);
    final total = 250 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final v = Curves.easeOutCubic.transform(
          ((t * total - delay) / 250).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.preview,
    required this.filter,
    this.searching = false,
  });
  final bool preview;
  final ProjectFilter filter;
  final bool searching;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          searching
              ? 'No matching projects'
              : filter == ProjectFilter.all
              ? 'No projects yet'
              : 'No ${filter.label.toLowerCase()} projects',
          style: dashboardText(16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          searching
              ? 'Try another name or clear the search.'
              : preview || filter != ProjectFilter.all
              ? 'Try another filter.'
              : 'Tap + to start a project from your proposal.',
          style: dashboardText(13, color: AppColors.subtle),
        ),
      ],
    ),
  );
}
