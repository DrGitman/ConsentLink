import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../minors/minors_data.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'capture_widgets.dart';
import 'field_capture_data.dart';

/// Figma 06.1 Hand over to participant (3:2870). The researcher sets the
/// participant's language and session aids, then hands the phone over.
class HandOverScreen extends ConsumerStatefulWidget {
  const HandOverScreen({super.key, this.projectId});
  final String? projectId;
  @override
  ConsumerState<HandOverScreen> createState() => _HandOverScreenState();
}

class _HandOverScreenState extends ConsumerState<HandOverScreen> {
  @override
  void initState() {
    super.initState();
    // A fresh session every time the hand-over screen opens. When a later
    // screen is opened directly, this one is only built underneath it and
    // must not wipe that session.
    Future.microtask(() {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      ref
          .read(captureSessionProvider.notifier)
          .start(projectId: widget.projectId);
      ref.read(minorSessionProvider.notifier).clear();
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        widget.projectId == null ? '/home' : '/projects/${widget.projectId}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final participant = ref.watch(captureParticipantProvider);
    final session = ref.watch(captureSessionProvider);
    final controller = ref.read(captureSessionProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final minors = minorsFor(ref, widget.projectId);

    return CaptureScaffold(
      participant: false,
      background: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
      footer: ConsentPillButton(
        label: 'Start for participant',
        icon: 'capture/play',
        onPressed: participant == null
            ? null
            : () {
                // Projects with minors (10.1) check the age first (10.2).
                if (minors.includesMinors) {
                  ref.read(minorSessionProvider.notifier).start();
                  context.push('/field-capture/age');
                } else {
                  context.push('/field-capture/read');
                }
              },
      ),
      children: [
        ConsentTopBar(
          leading: AppBackButton(onPressed: _back),
          title: 'Field capture',
        ),
        const SizedBox(height: 10),
        const ProjectBadge(
          label: 'Offline · saving on this phone',
          icon: 'wifi_off',
          fill: Color(0xFFFEF4E2),
          ink: Color(0xFF9A5B00),
        ),
        const SizedBox(height: 14),
        if (participant == null)
          const CaptureNotConnected()
        else
          RiseIn(child: _ParticipantCard(participant: participant)),
        const SizedBox(height: 14),
        Text(
          'Participant’s language',
          style: dashboardText(
            14,
            color: AppColors.muted,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final language in captureLanguages) ...[
                if (language != captureLanguages.first)
                  const SizedBox(width: 8),
                _LanguageChip(
                  label: language,
                  selected: session.language == language,
                  onTap: () => controller.setLanguage(language),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              _SettingRow(
                icon: 'capture/volume',
                tint: tint,
                title: 'Read everything aloud',
                subtitle: 'Recorded ${session.language} voice',
                value: session.readAloud,
                onChanged: controller.setReadAloud,
              ),
              const SizedBox(height: 2),
              _SettingRow(
                icon: 'form/textsize',
                tint: tint,
                title: 'Large text',
                subtitle: '150% for this session',
                value: session.largeText,
                onChanged: controller.setLargeText,
              ),
              const SizedBox(height: 2),
              _SettingRow(
                icon: 'capture/users',
                tint: tint,
                title: 'Interpreter present',
                subtitle: 'Recorded on the consent record',
                value: session.interpreter,
                onChanged: controller.setInterpreter,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardIcon('capture/hand', color: primary, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hand the phone to the participant, or read it together.',
                      style: dashboardText(
                        14,
                        color: primary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Researcher view locks until they finish.',
                      style: dashboardText(12, color: primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({required this.participant});
  final CaptureParticipant participant;
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
        Text(
          'Participant',
          style: dashboardText(
            13,
            color: AppColors.subtle,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          participant.code,
          style: dashboardText(
            26,
            color: Theme.of(context).colorScheme.primary,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          '${participant.project} · ${participant.site} site',
          style: dashboardText(12, color: AppColors.subtle),
        ),
      ],
    ),
  );
}

class _LanguageChip extends ConsumerWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final ink = selected ? Colors.white : AppColors.muted;
    return Semantics(
      selected: selected,
      child: DashboardAction(
        label: label,
        radius: 19,
        color: Colors.transparent,
        onPressed: onTap,
        child: SizedBox(
          height: large ? 56 : 48,
          child: Center(
            child: AnimatedContainer(
              duration: reduceMotion(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              constraints: BoxConstraints(minHeight: large ? 48 : 38),
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 8),
              decoration: BoxDecoration(
                color: selected ? primary : Colors.white,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: selected ? primary : AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DashboardIcon('form/globe', color: ink, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: dashboardText(
                      14,
                      color: ink,
                      weight: FontWeight.w500,
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

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String icon;
  final Color tint;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: title,
    hint: subtitle,
    onTap: () => onChanged(!value),
    child: ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 62),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: DashboardIcon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                  ),
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
                const SizedBox(width: 12),
                AppToggle(value: value),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
