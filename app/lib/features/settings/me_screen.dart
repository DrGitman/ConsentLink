import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/skeleton.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart';
import '../templates/template_widgets.dart' show SheetHandle;
import 'profile_widgets.dart';
import 'settings_data.dart';
import 'settings_widgets.dart';

/// Figma 08.1 Me / settings (3:3635), the Me tab.
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  /// "Large text, read-aloud" from the real accessibility settings.
  static String accessibilitySummary(WidgetRef ref) {
    final parts = [
      if (ref.watch(appTextScaleProvider) > 1.01) 'large text',
      if (ref.watch(readScreensAloudProvider)) 'read-aloud',
      if (ref.watch(highContrastProvider)) 'high contrast',
      if (ref.watch(reduceMotionPreferenceProvider)) 'reduce motion',
    ];
    if (parts.isEmpty) return 'Default';
    final text = parts.join(', ');
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _appearance(BuildContext context, WidgetRef ref) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        useRootNavigator: true,
        backgroundColor: Colors.white,
        barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
        sheetAnimationStyle: sheetMotion(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            final current = ref.watch(appearanceProvider);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetHandle(),
                  const SizedBox(height: 19),
                  Text(
                    'Appearance',
                    style: dashboardText(22, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The dark theme is still being designed, so the app '
                    'stays light for now.',
                    style: dashboardText(13, color: AppColors.subtle),
                  ),
                  const SizedBox(height: 10),
                  for (final a in Appearance.values)
                    Semantics(
                      selected: a == current,
                      inMutuallyExclusiveGroup: true,
                      child: DashboardAction(
                        label: a.label,
                        radius: 16,
                        onPressed: () {
                          ref.read(appearanceProvider.notifier).state = a;
                          Navigator.pop(context);
                        },
                        child: SizedBox(
                          height: 56,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.label,
                                  style: dashboardText(
                                    16,
                                    weight: a == current
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              RadioDot(selected: a == current),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(settingsPreviewProvider);
    final languages = ref.watch(formLanguagesProvider);
    final formsOn = languages
        .where((l) => l.status == FormLanguageStatus.on)
        .length;
    final (:name, role: roleLine, initials: _) = profileIdentity(ref);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          key: const PageStorageKey('me-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          // Figma 11.8: the tab bar stays real; the page is a skeleton.
          child: PreviewLoad(
            builder: (context, loading) => SkeletonSwitch(
              loading: loading,
              label: 'Loading settings',
              skeleton: const MeSkeleton(),
              child: Column(
                children: [
                  RiseIn(
                    child: DashboardAction(
                      label: '$name, $roleLine. Account',
                      onPressed: () => context.push('/settings/account'),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 96),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 12, 18),
                          child: Row(
                            children: [
                              const ProfileAvatar(),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Semantics(
                                      header: true,
                                      child: Text(
                                        name,
                                        key: const ValueKey('page-title-me'),
                                        style: dashboardText(
                                          17,
                                          weight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      roleLine,
                                      style: dashboardText(
                                        13,
                                        color: AppColors.subtle,
                                      ),
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
                  ),
                  const SizedBox(height: 16),
                  StaggerIn(
                    index: 1,
                    child: SettingsCard(
                      children: [
                        SettingsRow(
                          icon: 'form/globe',
                          title: 'Language',
                          subtitle:
                              '${ref.watch(selectedAppLanguageProvider)} · forms: $formsOn',
                          onTap: () => context.push('/settings/languages'),
                        ),
                        SettingsRow(
                          icon: 'settings/access',
                          title: 'Accessibility',
                          subtitle: accessibilitySummary(ref),
                          onTap: () => context.push('/settings/accessibility'),
                        ),
                        SettingsRow(
                          icon: 'settings/moon',
                          title: 'Appearance',
                          subtitle: ref.watch(appearanceProvider).label,
                          onTap: () => _appearance(context, ref),
                        ),
                        SettingsRow(
                          icon: 'settings/smile',
                          title: 'Feedback pop-up',
                          subtitle: ref.watch(feedbackSettingsProvider).summary,
                          onTap: () => context.push('/settings/feedback'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  StaggerIn(
                    index: 2,
                    child: SettingsCard(
                      children: [
                        SettingsRow(
                          icon: 'sparkle',
                          title: 'AI model',
                          subtitle: preview
                              ? 'Gemma 4 E2B · 1.3 GB'
                              : 'Not downloaded',
                          onTap: () => context.push('/offline-pack'),
                        ),
                        SettingsRow(
                          icon: 'sync',
                          title: 'Sync',
                          subtitle: preview
                              ? '3 pending · Wi-Fi only'
                              : 'Not connected',
                          onTap: () => showProjectNotice(
                            context,
                            'Sync',
                            preview
                                ? '3 records are waiting on this phone. They sync '
                                      'over Wi-Fi once project storage is connected.'
                                : 'Sync with project storage isn\'t connected yet. '
                                      'Everything stays encrypted on this phone.',
                          ),
                        ),
                        SettingsRow(
                          icon: 'projects/shield',
                          title: 'Privacy & data',
                          subtitle: 'Encryption, records, download',
                          onTap: () => context.push('/settings/privacy'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
