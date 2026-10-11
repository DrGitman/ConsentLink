import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import '../templates/template_widgets.dart' show SheetHandle;
import 'settings_data.dart';
import 'settings_widgets.dart';

/// Figma 08.3 Languages (3:3809). App language opens a picker; each consent
/// form language can be turned on/off, downloaded (Get) or reviewed.
/// Language packs aren't connected yet, so downloads are simulated (2 s).
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});
  @override
  ConsumerState<LanguageSettingsScreen> createState() =>
      _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState
    extends ConsumerState<LanguageSettingsScreen> {
  final _timers = <Timer>[];

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  Future<void> _pickAppLanguage() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
        final current = ref.watch(selectedAppLanguageProvider);
        return SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(),
              const SizedBox(height: 19),
              Text(
                'App language',
                style: dashboardText(22, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Buttons and menus. Only English is translated so far.',
                style: dashboardText(13, color: AppColors.subtle),
              ),
              const SizedBox(height: 8),
              for (final l in appLanguages)
                Semantics(
                  selected: l == current,
                  inMutuallyExclusiveGroup: true,
                  child: DashboardAction(
                    label: l,
                    radius: 16,
                    onPressed: () {
                      ref.read(selectedAppLanguageProvider.notifier).state = l;
                      Navigator.pop(context);
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
                                weight: l == current
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          RadioDot(selected: l == current),
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

  Future<void> _tap(FormLanguage l) async {
    final notifier = ref.read(formLanguagesProvider.notifier);
    switch (l.status) {
      case FormLanguageStatus.on:
        if (l.name == 'English') {
          await showProjectNotice(
            context,
            'English',
            'English is the source language of every form and stays on.',
          );
          return;
        }
        notifier.set(l.name, FormLanguageStatus.off, note: l.note);
      case FormLanguageStatus.off:
        notifier.set(l.name, FormLanguageStatus.on, note: l.note);
      case FormLanguageStatus.notDownloaded:
        notifier.set(l.name, FormLanguageStatus.downloading);
        _timers.add(
          Timer(const Duration(seconds: 2), () {
            if (!mounted) return;
            ref
                .read(formLanguagesProvider.notifier)
                .set(l.name, FormLanguageStatus.review);
          }),
        );
      case FormLanguageStatus.review:
        final ok = await showConfirmDialog(
          context,
          title: 'Review ${l.name}',
          message:
              'AI-drafted text must be checked by a fluent ${l.name} speaker '
              'before participants see it. Mark it as reviewed by you?',
          confirm: 'Mark reviewed',
          icon: 'consent/alert',
          destructive: false,
        );
        if (ok == true) {
          notifier.set(l.name, FormLanguageStatus.on, note: 'Reviewed by you');
        }
      case FormLanguageStatus.downloading:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLanguage = ref.watch(selectedAppLanguageProvider);
    final languages = ref.watch(formLanguagesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    return SettingsPage(
      title: 'Languages',
      children: [
        const SizedBox(height: 4),
        const SettingsLabel('App language'),
        const SizedBox(height: 7),
        DashboardAction(
          label: 'App language, $appLanguage',
          onPressed: _pickAppLanguage,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 18, 12),
              child: Row(
                children: [
                  DashboardIcon('form/globe', color: primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appLanguage,
                      style: dashboardText(16, weight: FontWeight.w600),
                    ),
                  ),
                  const DashboardIcon(
                    'settings/chevron_down',
                    color: AppColors.subtle,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        const SettingsLabel('Consent form languages'),
        const SizedBox(height: 3),
        Text(
          'Text is AI-drafted, then checked by a fluent reviewer.',
          style: dashboardText(12, color: AppColors.subtle),
        ),
        const SizedBox(height: 9),
        SettingsCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          children: [
            for (final l in languages)
              _LanguageRow(language: l, onTap: () => _tap(l)),
          ],
        ),
      ],
    );
  }
}

class _LanguageRow extends ConsumerWidget {
  const _LanguageRow({required this.language, required this.onTap});
  final FormLanguage language;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = language;
    final primary = Theme.of(context).colorScheme.primary;
    final warn = l.status == FormLanguageStatus.review;
    final badge = switch (l.status) {
      FormLanguageStatus.on => const ProjectBadge(
        label: 'On',
        icon: 'projects/check',
        fill: AppColors.brand50,
        ink: AppColors.brandDark,
      ),
      FormLanguageStatus.off => const ProjectBadge(
        label: 'Off',
        fill: AppColors.canvas,
        ink: AppColors.muted,
      ),
      FormLanguageStatus.review => const ProjectBadge(
        label: 'Review',
        icon: 'consent/alert',
        fill: Color(0xFFFEF4E2),
        ink: Color(0xFF9A5B00),
      ),
      FormLanguageStatus.notDownloaded => ProjectBadge(
        label: 'Get',
        icon: 'projects/download',
        fill: institutionTint(ref, context),
        ink: primary,
      ),
      FormLanguageStatus.downloading => _Downloading(color: primary),
    };
    return DashboardAction(
      label: '${l.name}, ${l.detail}',
      radius: 14,
      onPressed: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 49),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.name,
                      style: dashboardText(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.detail,
                      style: dashboardText(
                        12,
                        color: warn
                            ? const Color(0xFF9A5B00)
                            : AppColors.subtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: Duration(
                  milliseconds: reduceMotion(context) ? 150 : 250,
                ),
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween(begin: .8, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: KeyedSubtree(key: ValueKey(l.status), child: badge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2 s download bar inside a badge-sized pill.
class _Downloading extends StatelessWidget {
  const _Downloading({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Downloading',
    child: Container(
      width: 64,
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, color, .11),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 2),
          builder: (context, t, _) => LinearProgressIndicator(
            value: t,
            minHeight: 4,
            color: color,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    ),
  );
}
