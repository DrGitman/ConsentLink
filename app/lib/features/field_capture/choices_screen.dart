import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import 'capture_widgets.dart';
import 'field_capture_data.dart';

/// Figma 06.4 Consent choices (3:3057). Every choice needs a Yes or No before
/// Continue. Saying No to taking part ends the session without signing.
class ChoicesScreen extends ConsumerStatefulWidget {
  const ChoicesScreen({super.key});
  @override
  ConsumerState<ChoicesScreen> createState() => _ChoicesScreenState();
}

class _ChoicesScreenState extends ConsumerState<ChoicesScreen> {
  String? _reading;
  Timer? _readTimer;

  @override
  void dispose() {
    _readTimer?.cancel();
    super.dispose();
  }

  /// Voice packs aren't connected: the button shows it's "speaking" for the
  /// length of the sentence.
  void _readAloud(ConsentChoice choice) {
    _readTimer?.cancel();
    setState(() => _reading = choice.key);
    _readTimer = Timer(
      Duration(milliseconds: 420 * choice.label.split(' ').length + 400),
      () {
        if (mounted) setState(() => _reading = null);
      },
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture/answer');
    }
  }

  void _continue() {
    final session = ref.read(captureSessionProvider);
    if (session.declined) {
      ref.read(captureSessionProvider.notifier).complete();
      context.go('/field-capture/done');
    } else {
      context.push('/field-capture/sign');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final preview = ref.watch(fieldCapturePreviewProvider);
    if (!preview) {
      return CaptureScaffold(
        onBack: _back,
        footer: ConsentPillButton(
          label: 'Back',
          filled: false,
          onPressed: _back,
        ),
        children: const [CaptureNotConnected()],
      );
    }
    return CaptureScaffold(
      onBack: _back,
      footer: CaptureFooter(
        onBack: _back,
        nextLabel: session.declined ? 'Finish' : 'Continue',
        onNext: session.allChosen ? _continue : null,
      ),
      children: [
        const CaptureProgress(value: 306 / 350, label: 'Consent progress'),
        const SizedBox(height: 12),
        const CaptureHeading(
          eyebrow: 'Almost done',
          title: 'Your choices',
          helper:
              'Saying no to any of these is OK. It will not change how you are treated.',
        ),
        const SizedBox(height: 18),
        for (final choice in consentChoices) ...[
          if (choice != consentChoices.first) const SizedBox(height: 10),
          _ChoiceCard(
            choice: choice,
            value: session.choices[choice.key],
            reading: _reading == choice.key,
            onRead: () => _readAloud(choice),
            onChanged: (value) => ref
                .read(captureSessionProvider.notifier)
                .choose(choice.key, value),
          ),
        ],
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.choice,
    required this.value,
    required this.reading,
    required this.onRead,
    required this.onChanged,
  });
  final ConsentChoice choice;
  final bool? value;
  final bool reading;
  final VoidCallback onRead;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: choice.label,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: ExcludeSemantics(
                    child: Text(
                      choice.label,
                      style: dashboardText(16, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              Breathe(
                active: reading,
                period: const Duration(milliseconds: 600),
                to: 1.1,
                child: CaptureIconButton(
                  label: 'Read aloud: ${choice.label}',
                  icon: 'capture/volume',
                  size: 40,
                  fill: reading
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  iconColor: reading
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                  onPressed: onRead,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                Expanded(
                  child: CaptureYesNo(
                    yes: true,
                    selected: value == true,
                    onTap: () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CaptureYesNo(
                    yes: false,
                    selected: value == false,
                    onTap: () => onChanged(false),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Equal-weight Yes / No pill (no nudging). Also used by guardian consent
/// (10.4).
class CaptureYesNo extends ConsumerWidget {
  const CaptureYesNo({
    super.key,
    required this.yes,
    required this.selected,
    required this.onTap,
  });
  final bool yes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final ink = selected ? Colors.white : AppColors.ink;
    final label = yes ? 'Yes' : 'No';
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DashboardAction(
        label: label,
        radius: 23,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(minHeight: large ? 60 : 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(large ? 30 : 23),
            border: Border.all(
              color: selected ? primary : const Color(0xFFC9CFCC),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DashboardIcon(
                yes ? 'projects/check' : 'consent/x',
                color: ink,
                size: 22,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: dashboardText(16, color: ink, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
