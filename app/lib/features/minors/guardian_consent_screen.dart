import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/capture_widgets.dart';
import '../field_capture/choices_screen.dart' show CaptureYesNo;
import '../field_capture/field_capture_data.dart';
import '../field_capture/sign_screen.dart' show SignaturePad;
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../projects/project_widgets.dart';
import '../responses/responses_data.dart';
import '../templates/template_widgets.dart' show SheetHandle;
import 'minors_data.dart';

/// Figma 10.4 Guardian consent (3:7029), step 2 of 3. Three equal-weight
/// Yes/No choices and the guardian's signature. If the guardian says no,
/// the child is never asked.
class GuardianConsentScreen extends ConsumerWidget {
  const GuardianConsentScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture/guardian');
    }
  }

  void _next(BuildContext context, WidgetRef ref) {
    final s = ref.read(minorSessionProvider);
    ref.read(minorSessionProvider.notifier).setGuardianReading(false);
    if (s.guardianDeclined) {
      // Guardian said no: finish without asking the child.
      final capture = ref.read(captureSessionProvider.notifier);
      capture.choose('take_part', false);
      capture.complete();
      recordMinorDecline(ref, guardian: true);
      context.go('/field-capture/done');
    } else {
      context.push('/field-capture/assent');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(minorSessionProvider);
    final capture = ref.watch(captureSessionProvider);
    final c = ref.read(minorSessionProvider.notifier);
    final first = s.guardianName.trim().split(' ').first;
    final language = s.guardianLanguage ?? capture.language;

    return CaptureScaffold(
      onBack: () => _back(context),
      // Figma 10.4 is already sized for reading (28 / 15 / 16).
      participant: false,
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 24),
      footer: ConsentPillButton(
        label: s.guardianDeclined ? 'Finish' : 'Now ask the young person',
        onPressed: s.allChosen && (s.guardianDeclined || s.signed)
            ? () => _next(context, ref)
            : null,
      ),
      children: [
        CaptureHeading(
          eyebrow: 'Step 2 of 3 · Guardian',
          title: 'Do you allow your child to take part?',
          titleSize: 28,
        ),
        const SizedBox(height: 8),
        Text(
          '${first.isEmpty ? 'The guardian' : first} read the full consent '
          'form with read-aloud in $language.',
          style: dashboardText(
            15,
            color: AppColors.muted,
          ).copyWith(height: 1.4),
        ),
        const SizedBox(height: 10),
        for (final (key, label, _) in guardianChoices) ...[
          if (key != guardianChoices.first.$1) const SizedBox(height: 10),
          RiseIn(
            child: Semantics(
              container: true,
              label: label,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.canvas,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        label,
                        style: dashboardText(16, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CaptureYesNo(
                            yes: true,
                            selected: s.choices[key] == true,
                            onTap: () => c.choose(key, true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: CaptureYesNo(
                            yes: false,
                            selected: s.choices[key] == false,
                            onTap: () => c.choose(key, false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        AnimatedOpacity(
          duration: Duration(milliseconds: reduceMotion(context) ? 0 : 200),
          opacity: s.guardianDeclined ? .45 : 1,
          child: IgnorePointer(
            ignoring: s.guardianDeclined,
            child: _SignatureCard(
              strokes: s.strokes,
              signed: s.signed,
              onTap: () => _sign(context, ref),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sign(BuildContext context, WidgetRef ref) async {
    final strokes = [
      for (final s in ref.read(minorSessionProvider).strokes) [...s],
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.white,
      barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const SizedBox(height: 19),
            Text(
              'Guardian signature',
              style: dashboardText(22, weight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign with your finger to give consent for your child.',
              style: dashboardText(13, color: AppColors.subtle),
            ),
            const SizedBox(height: 14),
            SignaturePad(strokes: strokes, onChanged: (_) {}),
            const SizedBox(height: 14),
            ConsentPillButton(
              label: 'Done',
              height: 56,
              onPressed: () => Navigator.pop(sheet),
            ),
          ],
        ),
      ),
    );
    ref.read(minorSessionProvider.notifier).setStrokes(strokes);
  }
}

/// Figma "Guardian signature" card: a small copy of the ink + Signed badge.
class _SignatureCard extends StatelessWidget {
  const _SignatureCard({
    required this.strokes,
    required this.signed,
    required this.onTap,
  });
  final List<List<Offset>> strokes;
  final bool signed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DashboardAction(
      label: signed
          ? 'Guardian signature, signed. Sign again'
          : 'Guardian signs here',
      color: AppColors.canvas,
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Guardian signature',
              style: dashboardText(
                13,
                color: AppColors.subtle,
                weight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 150,
                  height: 44,
                  color: Colors.white,
                  alignment: Alignment.center,
                  child: signed
                      ? CustomPaint(
                          size: const Size(150, 44),
                          painter: _Thumbnail(strokes, primary),
                        )
                      : Text(
                          'Tap to sign',
                          style: dashboardText(13, color: AppColors.subtle),
                        ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: Duration(
                    milliseconds: reduceMotion(context) ? 150 : 250,
                  ),
                  transitionBuilder: (child, a) => ScaleTransition(
                    scale: Tween(begin: .8, end: 1.0).animate(a),
                    child: FadeTransition(opacity: a, child: child),
                  ),
                  child: signed
                      ? const ProjectBadge(
                          key: ValueKey('signed'),
                          label: 'Signed',
                          icon: 'projects/check',
                          fill: AppColors.brand50,
                          ink: AppColors.brandDark,
                        )
                      : const SizedBox(key: ValueKey('none')),
                ),
                const SizedBox(width: 9),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends CustomPainter {
  _Thumbnail(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final points = strokes.expand((s) => s).toList();
    if (points.isEmpty) return;
    var bounds = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      bounds = bounds.expandToInclude(Rect.fromPoints(p, p));
    }
    final box = Rect.fromLTWH(16, 6, size.width - 32, size.height - 12);
    final scale = math.min(
      box.width / math.max(bounds.width, 1),
      box.height / math.max(bounds.height, 1),
    );
    final dx = box.left + (box.width - bounds.width * scale) / 2;
    final dy = box.top + (box.height - bounds.height * scale) / 2;
    Offset map(Offset p) => Offset(
      dx + (p.dx - bounds.left) * scale,
      dy + (p.dy - bounds.top) * scale,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length < 2) continue;
      final path = Path()..moveTo(map(s.first).dx, map(s.first).dy);
      for (final p in s.skip(1)) {
        path.lineTo(map(p).dx, map(p).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Thumbnail old) => old.strokes != strokes;
}

/// Logs a minor's decline. Only "declined (assent)" or "declined
/// (guardian)" is kept: no answers or recordings.
void recordMinorDecline(WidgetRef ref, {required bool guardian}) {
  final code = minorCodeOf(ref.read(fieldCapturePreviewProvider));
  final number = int.tryParse(code.replaceFirst('P-', ''));
  if (number == null) return; // Normal mode: no record store connected.
  final now = DateTime.now();
  ref
      .read(responsesProvider.notifier)
      .add(
        ConsentResponse(
          number: number,
          name: 'Minor (age ${ref.read(minorSessionProvider).age})',
          status: ResponseStatus.declined,
          at: now,
          synced: false,
          language: ref.read(captureSessionProvider).language,
          choices: const {'Take part': false},
          audit: [
            AuditEvent(
              now,
              guardian
                  ? 'Declined (guardian) · child not asked'
                  : 'Declined (assent) · guardian consent overridden',
            ),
          ],
        ),
      );
}
