import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import '../institution/researcher_details_screen.dart';
import '../preferences/accessibility_preferences.dart';
import 'dashboard_components.dart';
import 'dashboard_loading.dart';
import 'dashboard_sync_preview.dart';

final dashboardPreviewProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('DASHBOARD_PREVIEW'),
);
final dashboardLoadingPreviewProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('DASHBOARD_LOADING_PREVIEW'),
);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(dashboardPreviewProvider)) {
        _notice(
          'Dashboard design preview',
          'The name, counts, project and sync status are sample data from Figma. No real consent records are loaded or uploaded.',
        );
      }
    });
  }

  Future<void> _notice(String title, String message) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: reduceMotion ? 150 : 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: reduceMotion
              ? child
              : ScaleTransition(
                  scale: Tween<double>(begin: .92, end: 1).animate(curved),
                  child: child,
                ),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(dashboardPreviewProvider);
    final loading = preview && ref.watch(dashboardLoadingPreviewProvider);
    final institution =
        ref.watch(selectedInstitutionProvider) ?? Institution.independent;
    final large = ref.watch(largerTouchTargetsProvider);
    final draft = ref.watch(researcherDraftProvider);
    final name = preview
        ? 'Ndapewa'
        : (draft.first.trim().isEmpty ? 'Researcher' : draft.first.trim());
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now().hour;
    final greeting = preview || now < 12
        ? 'Good morning,'
        : now < 18
        ? 'Good afternoon,'
        : 'Good evening,';

    Widget circle(String icon, String label, VoidCallback callback) =>
        SizedBox.square(
          dimension: large ? 72 : 48,
          child: Center(
            child: DashboardAction(
              label: label,
              onPressed: callback,
              radius: 40,
              child: SizedBox.square(
                dimension: large ? 72 : 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    DashboardIcon(icon, size: large ? 28 : 22),
                    if (preview && icon == 'bell')
                      Positioned(
                        top: large ? 20 : 10,
                        right: large ? 20 : 7,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          key: const PageStorageKey('dashboard-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      large || MediaQuery.textScalerOf(context).scale(20) > 26;
                  final identity = Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          institution.initials,
                          textScaler: TextScaler.noScaling,
                          style: dashboardText(
                            14,
                            color: Colors.white,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: dashboardText(14, color: AppColors.subtle),
                            ),
                            Semantics(
                              header: true,
                              child: Text(
                                name,
                                key: const ValueKey('page-title-home'),
                                style: dashboardText(
                                  20,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                  final actions = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      circle(
                        'search',
                        'Search projects',
                        () => _notice(
                          'Search projects',
                          'Project search will be available when the Projects feature is connected.',
                        ),
                      ),
                      const SizedBox(width: 4),
                      circle(
                        'bell',
                        'Notifications',
                        () => _notice(
                          'Notifications',
                          'No notification service is connected yet.',
                        ),
                      ),
                    ],
                  );
                  return compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            identity,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actions,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: 8),
                            actions,
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              if (loading)
                const DashboardLoading()
              else ...[
                if (preview)
                  DashboardSyncPreview(large: large)
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Sync not connected',
                      style: dashboardText(14, color: AppColors.muted),
                    ),
                  ),
                DashboardStats(preview: preview),
                const SizedBox(height: 18),
                Text(
                  'Quick actions',
                  style: dashboardText(17, weight: FontWeight.w600),
                ),
                const SizedBox(height: 11),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale =
                        MediaQuery.textScalerOf(context).scale(14) / 14;
                    final fit = (constraints.maxWidth - 16) / 3;
                    final minimum = (large ? 140 : 100) * textScale;
                    final width = fit >= minimum ? fit : minimum;
                    final actions = [
                      ('sparkle', 'New consent', 'from your proposal'),
                      ('mic', 'Field capture', 'works offline'),
                      (
                        'layers',
                        'Templates',
                        preview && institution == Institution.nust
                            ? 'Yours + NUST'
                            : 'Your templates',
                      ),
                    ];
                    return SingleChildScrollView(
                      key: const PageStorageKey('dashboard-quick-actions'),
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final action in actions) ...[
                              if (action != actions.first)
                                const SizedBox(width: 8),
                              SizedBox(
                                width: width,
                                child: DashboardAction(
                                  label: action.$2,
                                  color: action.$1 == 'sparkle'
                                      ? primary
                                      : Colors.white,
                                  onPressed: () => action.$1 == 'mic'
                                      ? context.go('/capture')
                                      : _notice(
                                          action.$2,
                                          '${action.$2} will be connected in its feature task.',
                                        ),
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: large ? 148 : 124,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          14,
                                          6,
                                          12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: large ? 56 : 40,
                                              height: large ? 56 : 40,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: action.$1 == 'sparkle'
                                                    ? Colors.white
                                                    : institution ==
                                                          Institution.nust
                                                    ? const Color(0xFFC9D0EA)
                                                    : institution ==
                                                          Institution
                                                              .independent
                                                    ? AppColors.brand100
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .primaryContainer,
                                              ),
                                              child: Center(
                                                child: DashboardIcon(
                                                  action.$1,
                                                  color: primary,
                                                  size: large ? 28 : 22,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              action.$2,
                                              style: dashboardText(
                                                14,
                                                color: action.$1 == 'sparkle'
                                                    ? Colors.white
                                                    : AppColors.ink,
                                                weight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              action.$3,
                                              style: dashboardText(
                                                11,
                                                color: action.$1 == 'sparkle'
                                                    ? const Color(0xFFE6E9F2)
                                                    : AppColors.subtle,
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Active projects',
                        style: dashboardText(17, weight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/projects'),
                      child: Text(
                        'See all',
                        style: dashboardText(
                          14,
                          color: primary,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview
                            ? 'Water access & health in Opuwo'
                            : 'No projects yet',
                        style: dashboardText(15, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview
                            ? 'Otjiherero · 64 of 80 participants'
                            : 'Your projects will appear here once connected.',
                        style: dashboardText(12, color: AppColors.subtle),
                      ),
                      if (preview) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: .8,
                                  minHeight: 8,
                                  color: primary,
                                  backgroundColor: AppColors.line,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              '80%',
                              style: dashboardText(
                                13,
                                color: primary,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 21),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
