import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/capture_widgets.dart';
import '../field_capture/field_capture_data.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_data.dart';
import '../settings/settings_data.dart';
import 'guardian_consent_screen.dart' show recordMinorDecline;
import 'minors_data.dart';

/// Figma 10.5 Child assent 12–17 (3:7074) and 10.6 Child assent 7–11,
/// pictures + audio (3:7132). Step 3 of 3. Yes / Not sure / No, equal
/// weight. "Not sure" pauses so they can ask questions; "No" always stops,
/// even though the guardian agreed.
class AssentScreen extends ConsumerStatefulWidget {
  const AssentScreen({super.key});
  @override
  ConsumerState<AssentScreen> createState() => _AssentScreenState();
}

class _AssentScreenState extends ConsumerState<AssentScreen> {
  /// Recorded voice packs aren't connected: "Listen" plays for the length
  /// of the recording (1 minute) without sound.
  Timer? _listen;
  bool _playing = false;

  @override
  void dispose() {
    _listen?.cancel();
    super.dispose();
  }

  void _toggleListen() {
    _listen?.cancel();
    if (_playing) {
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    _listen = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture/guardian-consent');
    }
  }

  void _done() {
    final s = ref.read(minorSessionProvider);
    _listen?.cancel();
    switch (s.assent) {
      case AssentAnswer.yes:
        _saveAgreed(s);
        context.go('/field-capture/done');
      case AssentAnswer.no:
        final capture = ref.read(captureSessionProvider.notifier);
        capture.choose('take_part', false);
        capture.complete();
        recordMinorDecline(ref, guardian: false);
        context.go('/field-capture/stopped');
      case AssentAnswer.notSure || null:
        return;
    }
  }

  /// Guardian consent + assent complete (Figma 10.8). Kept on the phone;
  /// the record store (P2) isn't connected.
  void _saveAgreed(MinorSession s) {
    final capture = ref.read(captureSessionProvider.notifier);
    capture.choose('take_part', true);
    capture.complete();
    final code = minorCodeOf(ref.read(fieldCapturePreviewProvider));
    final number = int.tryParse(code.replaceFirst('P-', ''));
    if (number == null) return;
    final now = DateTime.now();
    final language = ref.read(captureSessionProvider).language;
    final settings =
        ref.read(minorsSettingsProvider)[minorsProjectId(
          ref.read(captureSessionProvider).projectId,
          ref.read(fieldCapturePreviewProvider),
        )] ??
        const MinorsSettings();
    ref
        .read(minorRecordsProvider.notifier)
        .add(
          MinorRecord(
            code: code,
            age: s.age!,
            band: s.band!,
            guardianName: s.guardianName.trim(),
            relationship: s.relationship,
            choices: {
              for (final (key, _, _) in guardianChoices)
                key: s.choices[key] ?? false,
            },
            assent: AssentAnswer.yes,
            at: now,
            recordedBy: _researcher(),
            reconsentOn: turns18(
              age: s.age!,
              birthDate: s.birthDate,
              from: now,
            ),
            gatekeeper: settings.gatekeeper,
            language: language,
          ),
        );
    ref
        .read(responsesProvider.notifier)
        .add(
          ConsentResponse(
            number: number,
            name: 'Minor (age ${s.age})',
            status: ResponseStatus.agreed,
            at: now,
            synced: false,
            language: language,
            choices: {
              'Take part': true,
              'Record voice': s.choices['record_voice'] ?? false,
              'Photos': s.choices['photos'] ?? false,
            },
            witness:
                '${s.guardianName.trim()} (${s.relationship.label.toLowerCase()})',
            audit: [
              AuditEvent(now, 'Guardian consent signed on device · encrypted'),
              AuditEvent(now, 'Young person said yes (assent) · encrypted'),
            ],
          ),
        );
  }

  String _researcher() {
    final name = ref.read(settingsPreviewProvider) ? 'N. Shikongo' : 'you';
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(minorSessionProvider);
    final language =
        s.guardianLanguage ?? ref.watch(captureSessionProvider).language;
    final young = s.band == AgeBand.child;
    final c = ref.read(minorSessionProvider.notifier);
    final footer = CaptureFooter(
      onBack: _back,
      nextLabel: 'Done',
      height: 60,
      onNext: s.assent == AssentAnswer.yes || s.assent == AssentAnswer.no
          ? _done
          : null,
    );
    return young
        ? _Young(
            playing: _playing,
            onListen: _toggleListen,
            answer: s.assent,
            onAnswer: c.setAssent,
            footer: footer,
            onBack: _back,
          )
        : _Teen(
            playing: _playing,
            onListen: _toggleListen,
            language: language,
            answer: s.assent,
            onAnswer: c.setAssent,
            footer: footer,
            onBack: _back,
          );
  }
}

/// 10.5 (12–17): simplified text, listen card, three points, three choices.
class _Teen extends ConsumerWidget {
  const _Teen({
    required this.playing,
    required this.onListen,
    required this.language,
    required this.answer,
    required this.onAnswer,
    required this.footer,
    required this.onBack,
  });
  final bool playing;
  final VoidCallback onListen;
  final String language;
  final AssentAnswer? answer;
  final ValueChanged<AssentAnswer?> onAnswer;
  final Widget footer;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    Widget point(String icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
              ),
              child: DashboardIcon(icon, color: primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: dashboardText(16, weight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );

    return CaptureScaffold(
      onBack: onBack,
      // The Figma sizes are already large for a young reader (32 / 17 / 16),
      // so the session's 150% is not applied on top of them.
      participant: false,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      footer: footer,
      children: [
        const CaptureProgress(value: 298 / 350, label: 'Assent progress'),
        const SizedBox(height: 12),
        Text(
          'Step 3 of 3 · Your choice',
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
            'It’s your choice',
            style: dashboardText(32, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Your guardian said it’s OK. But you decide too. If you say no, '
          'that’s fine — nobody will be upset and nothing bad will happen.',
          style: dashboardText(17).copyWith(height: 1.4),
        ),
        const SizedBox(height: 26),
        DashboardAction(
          label: playing
              ? 'Stop listening'
              : 'Listen to what will happen, 1 minute, $language',
          color: tint,
          onPressed: onListen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Breathe(
                  active: playing,
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: DashboardIcon(
                      playing ? 'capture/pause' : 'capture/play',
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playing ? 'Listening…' : 'Listen to what will happen',
                        style: dashboardText(
                          15,
                          color: primary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 minute · $language',
                        style: dashboardText(12, color: primary),
                      ),
                    ],
                  ),
                ),
                if (playing) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    height: 24,
                    child: Waveform(
                      color: primary,
                      count: 8,
                      minHeight: 4,
                      maxHeight: 22,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        point('mic', 'We will talk for about 20 minutes'),
        point('capture/pause', 'You can stop any time'),
        point('form/lock', 'We won’t tell anyone your name'),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(
            'Do you want to take part?',
            style: dashboardText(20, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final a in AssentAnswer.values) ...[
              if (a != AssentAnswer.values.first) const SizedBox(width: 10),
              Expanded(
                child: _Choice(
                  answer: a,
                  selected: answer == a,
                  onTap: () => onAnswer(a),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        _NotSureNote(paused: answer == AssentAnswer.notSure),
      ],
    );
  }
}

/// 110 × 96 choice (Figma A/Yes · A/Not sure · A/No).
class _Choice extends ConsumerWidget {
  const _Choice({
    required this.answer,
    required this.selected,
    required this.onTap,
  });
  final AssentAnswer answer;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final ink = selected ? Colors.white : AppColors.ink;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: DashboardAction(
        label: answer.label,
        radius: 22,
        color: Colors.transparent,
        onPressed: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: reduceMotion(context) ? 0 : 250),
          curve: Curves.easeOutCubic,
          // Fill the third of the row (Figma 110 × 96).
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 14),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? primary : const Color(0xFFC9CFCC),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              DashboardIcon(answer.icon, color: ink, size: 24),
              const SizedBox(height: 14),
              Text(
                answer.label,
                textAlign: TextAlign.center,
                style: dashboardText(15, color: ink, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Not sure" pauses: a calm note asks them to talk with the researcher.
class _NotSureNote extends StatelessWidget {
  const _NotSureNote({required this.paused});
  final bool paused;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Duration(milliseconds: reduceMotion(context) ? 150 : 250),
    child: paused
        ? Semantics(
            key: const ValueKey('paused'),
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF4E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Paused. Ask the researcher anything you want to know, then '
                'choose Yes or No. There’s no rush.',
                style: dashboardText(
                  14,
                  color: const Color(0xFF7A4700),
                  weight: FontWeight.w600,
                ),
              ),
            ),
          )
        : Text(
            key: const ValueKey('note'),
            '“Not sure” pauses so they can ask questions.',
            style: dashboardText(13, color: AppColors.subtle),
          ),
  );
}

/// 10.6 (7–11): big listen button, one question, three faces (110 × 170).
class _Young extends StatelessWidget {
  const _Young({
    required this.playing,
    required this.onListen,
    required this.answer,
    required this.onAnswer,
    required this.footer,
    required this.onBack,
  });
  final bool playing;
  final VoidCallback onListen;
  final AssentAnswer? answer;
  final ValueChanged<AssentAnswer?> onAnswer;
  final Widget footer;
  final VoidCallback onBack;

  static const _faces = [
    (AssentAnswer.yes, 'Yes!', Color(0xFF1FAF84)),
    (AssentAnswer.notSure, 'Not sure', Color(0xFFF5A524)),
    (AssentAnswer.no, 'No', Color(0xFFE5484D)),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return CaptureScaffold(
      onBack: onBack,
      participant: false,
      background: const Color(0xFFFFF9EE),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      footer: footer,
      children: [
        Center(
          child: Semantics(
            button: true,
            label: playing ? 'Stop listening' : 'Tap to listen',
            child: GestureDetector(
              onTap: onListen,
              child: Breathe(
                active: playing,
                to: 1.06,
                child: Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                  child: DashboardIcon(
                    playing ? 'capture/pause' : 'capture/volume',
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: ExcludeSemantics(
            child: Text(
              playing ? 'Listening…' : 'Tap to listen',
              style: dashboardText(16, color: primary, weight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 27),
        Semantics(
          header: true,
          child: Text(
            'Do you want to help with our questions?',
            textAlign: TextAlign.center,
            style: dashboardText(26, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 52),
        Row(
          children: [
            for (final (a, label, color) in _faces) ...[
              if (a != AssentAnswer.yes) const SizedBox(width: 8),
              Expanded(
                child: _FaceCard(
                  answer: a,
                  label: label,
                  color: color,
                  selected: answer == a,
                  dimmed: answer != null && answer != a,
                  onTap: () => onAnswer(a),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 18),
        if (answer == AssentAnswer.notSure) const _NotSureNote(paused: true),
      ],
    );
  }
}

/// Face card: white, radius 28, 3 dp coloured border; the chosen face
/// scales to 1.15 with a bounce (Figma Animations: selected face).
class _FaceCard extends StatelessWidget {
  const _FaceCard({
    required this.answer,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });
  final AssentAnswer answer;
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      label: answer.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: reduced ? 0 : 200),
            opacity: dimmed ? .55 : 1,
            child: AnimatedScale(
              scale: selected && !reduced ? 1.15 : 1,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: Duration(milliseconds: reduced ? 0 : 200),
                width: double.infinity,
                height: 170,
                decoration: BoxDecoration(
                  color: selected
                      ? Color.lerp(Colors.white, color, .12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: color, width: selected ? 4 : 3),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 18),
                    CustomPaint(
                      size: const Size.square(80),
                      painter: _FacePainter(answer, color),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: dashboardText(18, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Figma face: 80 dp circle, white eyes and a smile / straight / sad mouth.
class _FacePainter extends CustomPainter {
  _FacePainter(this.answer, this.color);
  final AssentAnswer answer;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()..color = color,
    );
    final white = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(31, 34), 4, white);
    canvas.drawCircle(const Offset(48, 34), 4, white);
    final mouth = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    final path = Path();
    switch (answer) {
      case AssentAnswer.yes:
        path
          ..moveTo(27, 46)
          ..quadraticBezierTo(40, 60, 53, 46);
      case AssentAnswer.notSure:
        path
          ..moveTo(29, 49)
          ..lineTo(51, 49);
      case AssentAnswer.no:
        path
          ..moveTo(29, 53)
          ..quadraticBezierTo(40, 41, 51, 53);
    }
    canvas.drawPath(path, mouth);
  }

  @override
  bool shouldRepaint(_FacePainter old) =>
      old.answer != answer || old.color != color;
}
