import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/capture_widgets.dart';
import '../field_capture/field_capture_data.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import 'minors_data.dart';

/// Figma 10.2 Age check (3:6928). Researcher-facing, before the phone is
/// handed over. Under 18 needs a guardian first; the band must be covered
/// by the project's ethics approval (10.1).
class AgeCheckScreen extends ConsumerWidget {
  const AgeCheckScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture');
    }
  }

  Future<void> _pickBirthDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 14, now.month, now.day),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked != null) {
      ref.read(minorSessionProvider.notifier).setBirthDate(picked, now);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(minorSessionProvider);
    final settings = minorsFor(
      ref,
      minorsProjectId(
        ref.watch(captureSessionProvider).projectId,
        ref.watch(fieldCapturePreviewProvider),
      ),
    );
    final controller = ref.read(minorSessionProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    final age = session.age;
    final band = session.band;
    final allowed = band != null && settings.allows(band);
    final minor = session.isMinor;

    final (String label, String? icon, VoidCallback? next) = switch (age) {
      null => ('Continue', null, null),
      _ when !allowed => ('Continue', null, null),
      _ when minor => (
        'Continue with guardian',
        'capture/users',
        () => context.push('/field-capture/guardian'),
      ),
      _ => ('Continue', null, () => context.push('/field-capture/read')),
    };

    return CaptureScaffold(
      participant: false,
      onBack: () => _back(context),
      padding: const EdgeInsets.fromLTRB(20, 46, 20, 24),
      footer: ConsentPillButton(label: label, icon: icon, onPressed: next),
      children: [
        Text(
          'Before we start',
          style: dashboardText(
            13,
            color: AppColors.subtle,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        Semantics(
          header: true,
          child: Text(
            'How old is the participant?',
            style: dashboardText(30, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        _AgeStepper(age: age, onChanged: controller.setAge),
        const SizedBox(height: 4),
        TextButton(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 44),
            overlayColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          onPressed: () => _pickBirthDate(context, ref),
          child: Text(
            session.birthDate == null
                ? 'Or enter date of birth'
                : 'Born ${formatCaptureDate(session.birthDate!)} · change',
            style: dashboardText(14, color: primary, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduceMotion(context) ? 150 : 250),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(a),
              child: child,
            ),
          ),
          child: switch (age) {
            null => const SizedBox(key: ValueKey('none')),
            final int a when !allowed => _NotCovered(
              key: ValueKey('blocked-$band'),
              age: a,
              band: band,
              settings: settings,
            ),
            _ when minor => const _UnderEighteen(key: ValueKey('minor')),
            _ => const _Adult(key: ValueKey('adult')),
          },
        ),
      ],
    );
  }
}

/// Age with − / + (Figma Age card: canvas, radius 24, 96 tall).
class _AgeStepper extends StatelessWidget {
  const _AgeStepper({required this.age, required this.onChanged});
  final int? age;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Age',
    value: age == null ? 'Not set' : '$age',
    increasedValue: '${(age ?? 17) + 1}',
    decreasedValue: '${(age ?? 19) - 1}',
    onIncrease: () => onChanged((age ?? 17) + 1),
    onDecrease: () => onChanged((age ?? 19) - 1),
    child: Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.fromLTRB(20, 14, 24, 14),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Age',
                    style: dashboardText(
                      13,
                      color: AppColors.subtle,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: reduceMotion(context) ? 0 : 150,
                    ),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(
                        scale: Tween(begin: .85, end: 1.0).animate(a),
                        child: child,
                      ),
                    ),
                    child: Text(
                      age == null ? '—' : '$age',
                      key: ValueKey(age),
                      style: dashboardText(36, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ExcludeSemantics(
            child: ProjectCircleButton(
              icon: 'form/minus',
              label: 'Younger',
              onPressed: () => onChanged((age ?? 19) - 1),
            ),
          ),
          const SizedBox(width: 12),
          ExcludeSemantics(
            child: ProjectCircleButton(
              icon: 'projects/plus',
              label: 'Older',
              onPressed: () => onChanged((age ?? 17) + 1),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "Under 18 — two steps needed" (Figma tint card).
class _UnderEighteen extends ConsumerWidget {
  const _UnderEighteen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    TextStyle body([bool strong = false]) => dashboardText(
      14,
      color: strong ? primary : AppColors.muted,
      weight: strong ? FontWeight.w600 : FontWeight.w400,
    ).copyWith(height: 1.35);
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: institutionTint(ref, context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardIcon('capture/users', color: primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Under 18 — two steps needed',
                    style: dashboardText(
                      16,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '1. A parent or legal guardian gives consent',
                    style: body(),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    '2. The young person decides for themselves (assent)',
                    style: body(),
                  ),
                  const SizedBox(height: 0),
                  Text(
                    'If they say no, we stop — even if the guardian agreed',
                    style: body(true),
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

class _Adult extends StatelessWidget {
  const _Adult({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const DashboardIcon(
            'projects/check',
            color: AppColors.brandDark,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '18 or over · standard consent form',
              style: dashboardText(
                14,
                color: AppColors.brandDark,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Age not covered by the ethics approval / project settings.
class _NotCovered extends StatelessWidget {
  const _NotCovered({
    super.key,
    required this.age,
    required this.band,
    required this.settings,
  });
  final int age;
  final AgeBand? band;
  final MinorsSettings settings;
  @override
  Widget build(BuildContext context) {
    final text = band == null
        ? 'Children under 7 can’t take part in ConsentLink studies.'
        : !settings.includesMinors
        ? 'This project doesn’t include under-18s. Turn it on in the '
              'project’s Participants settings if the ethics approval '
              'covers minors.'
        : 'Ages ${band!.label} aren’t switched on for this project.';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF4E2),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardIcon(
              'consent/alert',
              color: Color(0xFF9A5B00),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: dashboardText(
                  14,
                  color: const Color(0xFF7A4700),
                  weight: FontWeight.w600,
                ).copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
