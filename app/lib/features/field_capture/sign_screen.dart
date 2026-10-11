import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../new_consent/review_draft_screen.dart' show sheetMotion;
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'capture_widgets.dart';
import 'field_capture_data.dart';

/// Figma 06.5 Sign, thumbprint or verbal (3:3129) with "Consent capture"
/// (4:19275): ink follows the finger and Clear fades it; the thumbprint scan
/// line sweeps and "Captured" pops; "Say it" pulses a record dot with a
/// timer and waveform.
///
/// Thumbprint and audio capture aren't connected to hardware yet: holding the
/// frame for 1.2 s counts as a capture, and "Say it" times the recording
/// without saving audio.
class SignScreen extends ConsumerStatefulWidget {
  const SignScreen({super.key});
  @override
  ConsumerState<SignScreen> createState() => _SignScreenState();
}

class _SignScreenState extends ConsumerState<SignScreen> {
  final _strokes = <List<Offset>>[];

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/field-capture/choices');
    }
  }

  void _finish() {
    ref.read(captureSessionProvider.notifier).complete();
    context.go('/field-capture/done');
  }

  Future<void> _addWitness() async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      sheetAnimationStyle: sheetMotion(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const _WitnessSheet(),
    );
    if (name != null && mounted) {
      ref.read(captureSessionProvider.notifier).setWitness(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(captureSessionProvider);
    final participant = ref.watch(captureParticipantProvider);
    final controller = ref.read(captureSessionProvider.notifier);
    if (participant == null) {
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
    final reduced = reduceMotion(context);
    final panel = switch (session.method) {
      ConsentMethod.sign => SignaturePad(
        key: const ValueKey('sign'),
        strokes: _strokes,
        onChanged: controller.setSigned,
      ),
      ConsentMethod.thumbprint => _ThumbPanel(
        key: const ValueKey('thumb'),
        captured: session.thumbCaptured,
        onCaptured: controller.setThumbCaptured,
      ),
      ConsentMethod.verbal => _VerbalPanel(
        key: const ValueKey('verbal'),
        seconds: session.verbalSeconds,
        onRecorded: controller.setVerbalSeconds,
      ),
    };

    return CaptureScaffold(
      onBack: _back,
      footer: CaptureFooter(
        onBack: _back,
        nextLabel: 'Finish',
        nextIcon: 'projects/check',
        onNext: session.canFinish ? _finish : null,
      ),
      children: [
        const CaptureProgress(value: 1, label: 'Consent progress'),
        const SizedBox(height: 12),
        const CaptureHeading(
          eyebrow: 'Last step',
          title: 'How would you like to give consent?',
          titleSize: 26,
        ),
        const SizedBox(height: 12),
        _Segmented(value: session.method, onChanged: controller.setMethod),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: Duration(milliseconds: reduced ? 150 : 250),
          switchInCurve: Curves.easeOutCubic,
          child: panel,
        ),
        const SizedBox(height: 12),
        Text(
          '${participant.name} · ${formatCaptureDate(DateTime.now())} · ${participant.site}',
          style: dashboardText(
            13,
            color: AppColors.subtle,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        _WitnessCard(
          witness: session.witness,
          required: session.method.needsWitness,
          onAdd: _addWitness,
          onRemove: () => controller.setWitness(null),
        ),
      ],
    );
  }
}

class _Segmented extends ConsumerWidget {
  const _Segmented({required this.value, required this.onChanged});
  final ConsentMethod value;
  final ValueChanged<ConsentMethod> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final index = ConsentMethod.values.indexOf(value);
    final h = large ? 64.0 : 52.0;
    return Container(
      height: h,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(h / 2),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: reduceMotion(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + index.toDouble(), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(h / 2 - 4),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final method in ConsentMethod.values)
                Expanded(
                  child: Semantics(
                    selected: method == value,
                    inMutuallyExclusiveGroup: true,
                    child: DashboardAction(
                      label: method.label,
                      radius: h / 2 - 4,
                      color: Colors.transparent,
                      onPressed: () => onChanged(method),
                      child: SizedBox.expand(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DashboardIcon(
                                  method.icon,
                                  color: method == value
                                      ? primary
                                      : AppColors.muted,
                                  size: 22,
                                ),
                                const SizedBox(width: 4),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: dashboardText(
                                    13.5,
                                    color: method == value
                                        ? primary
                                        : AppColors.muted,
                                    weight: FontWeight.w600,
                                  ),
                                  child: Text(method.label),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wins the gesture arena straight away so drawing never scrolls the page.
class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Signature pad (Figma 350 × 220, #FAFBFD, 1.5 line border, "×" baseline).
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.onChanged,
    this.height = 220,
    this.strokes,
  });
  final ValueChanged<bool> onChanged;
  final double height;

  /// Pass a list to keep the ink when the pad is rebuilt (switching methods).
  final List<List<Offset>>? strokes;
  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late final List<List<Offset>> _strokes = widget.strokes ?? [];
  bool _clearing = false;

  bool get _hasInk => _strokes.fold<int>(0, (sum, s) => sum + s.length) > 6;

  Future<void> _clear() async {
    if (_strokes.isEmpty) return;
    setState(() => _clearing = true);
    await Future<void>.delayed(
      Duration(milliseconds: reduceMotion(context) ? 0 : 250),
    );
    if (!mounted) return;
    setState(() {
      _strokes.clear();
      _clearing = false;
    });
    widget.onChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Signature pad. Sign with your finger.',
      value: _hasInk ? 'Signed' : 'Empty',
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFD),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              Positioned(
                left: 30,
                right: 30,
                top: widget.height - 44,
                child: const Divider(height: 1, color: AppColors.line),
              ),
              Positioned(
                left: 30,
                top: widget.height - 70,
                child: Text(
                  '×',
                  style: dashboardText(20, color: AppColors.subtle),
                ),
              ),
              if (_strokes.isEmpty)
                Positioned.fill(
                  bottom: 44,
                  child: Center(
                    child: Text(
                      'Sign here with your finger',
                      style: dashboardText(14, color: AppColors.subtle),
                    ),
                  ),
                ),
              // Keyed: the hint above leaves the Stack on the first point,
              // and without a key this layer would be rebuilt in a new slot,
              // dropping the gesture mid-stroke.
              Positioned.fill(
                key: const ValueKey('ink'),
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
                      _EagerPan.new,
                      (r) => r
                        ..onStart = (d) {
                          if (_clearing) return;
                          setState(() => _strokes.add([d.localPosition]));
                        }
                        ..onUpdate = (d) {
                          if (_clearing || _strokes.isEmpty) return;
                          setState(() => _strokes.last.add(d.localPosition));
                        }
                        ..onEnd = (_) => widget.onChanged(_hasInk),
                    ),
                  },
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _clearing ? 0 : 1,
                    child: CustomPaint(
                      painter: _InkPainter(_strokes, primary),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 6,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    overlayColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    foregroundColor: primary,
                  ),
                  onPressed: _strokes.isEmpty ? null : _clear,
                  child: Text(
                    'Clear',
                    style: dashboardText(
                      13,
                      color: _strokes.isEmpty
                          ? primary.withValues(alpha: .4)
                          : primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  _InkPainter(this.strokes, this.color);
  final List<List<Offset>> strokes;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final s in strokes) {
      if (s.length == 1) {
        canvas.drawCircle(s.first, 1.75, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(s.first.dx, s.first.dy);
      for (var i = 1; i < s.length - 1; i++) {
        final mid = Offset.lerp(s[i], s[i + 1], .5)!;
        path.quadraticBezierTo(s[i].dx, s[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.last.dx, s.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  // Strokes are mutated in place, so always repaint.
  @override
  bool shouldRepaint(_InkPainter old) => true;
}

class _ThumbPanel extends StatefulWidget {
  const _ThumbPanel({
    super.key,
    required this.captured,
    required this.onCaptured,
  });
  final bool captured;
  final ValueChanged<bool> onCaptured;
  @override
  State<_ThumbPanel> createState() => _ThumbPanelState();
}

class _ThumbPanelState extends State<_ThumbPanel>
    with SingleTickerProviderStateMixin {
  static const _mint = Color(0xFF9FE3C9);
  late final _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    _scan.dispose();
    super.dispose();
  }

  void _start() {
    if (widget.captured) widget.onCaptured(false);
    _scan.repeat();
    _hold?.cancel();
    _hold = Timer(const Duration(milliseconds: 1200), _done);
    setState(() {});
  }

  void _cancel() {
    if (!mounted) return;
    _hold?.cancel();
    if (_scan.isAnimating) {
      _scan.reset();
      setState(() {});
    }
  }

  void _done() {
    if (!mounted) return;
    _scan.reset();
    HapticFeedback.mediumImpact();
    widget.onCaptured(true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _scan.isAnimating;
    final hint = widget.captured
        ? 'Hold again to retake'
        : scanning
        ? 'Scanning… keep holding'
        : 'Hold thumb inside the frame';
    return Semantics(
      button: true,
      label: widget.captured ? 'Thumbprint captured' : 'Capture thumbprint',
      hint: hint,
      onTap: _done,
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _cancel(),
        onPointerCancel: (_) => _cancel(),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF10151A),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 24,
                child: SizedBox(
                  width: 140,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(
                        child: CustomPaint(painter: _DashedFrame(_mint)),
                      ),
                      const DashboardIcon(
                        'form/fingerprint',
                        color: _mint,
                        size: 80,
                      ),
                      AnimatedBuilder(
                        animation: _scan,
                        builder: (context, _) => scanning
                            ? Positioned(
                                top: 156 * _scan.value,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: _mint,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (widget.captured)
                        // The pill may be wider than the 140 dp frame with
                        // large text, so let it overflow the frame instead.
                        OverflowBox(
                          maxWidth: double.infinity,
                          child: PopIn(
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const DashboardIcon(
                                    'projects/check',
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Captured',
                                    style: dashboardText(
                                      14,
                                      color: Colors.white,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: dashboardText(
                    13,
                    color: const Color(0xFFCDEFE2),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedFrame extends CustomPainter {
  const _DashedFrame(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(70),
    ).deflate(1);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 14) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 8, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) => old.color != color;
}

class _VerbalPanel extends StatefulWidget {
  const _VerbalPanel({
    super.key,
    required this.seconds,
    required this.onRecorded,
  });
  final int seconds;
  final ValueChanged<int> onRecorded;
  @override
  State<_VerbalPanel> createState() => _VerbalPanelState();
}

class _VerbalPanelState extends State<_VerbalPanel> {
  static const _red = AppColors.error;
  Timer? _timer;
  int _elapsed = 0;

  bool get _recording => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_recording) {
      _timer!.cancel();
      _timer = null;
      widget.onRecorded(math.max(_elapsed, 1));
      setState(() {});
      return;
    }
    widget.onRecorded(0);
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final recorded = !_recording && widget.seconds > 0;
    final status = _recording
        ? 'Recording… ${formatClock(Duration(seconds: _elapsed))}'
        : recorded
        ? 'Recorded ${formatClock(Duration(seconds: widget.seconds))} · tap to redo'
        : 'Tap and say “I agree”';
    // The whole panel toggles recording, as the status text says "Tap…".
    // The button below keeps the semantics. 220 dp at default text size;
    // grows when large text wraps the status.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _toggle,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 36),
            Semantics(
              button: true,
              label: _recording ? 'Stop recording' : 'Record verbal consent',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: _toggle,
                child: SizedBox.square(
                  dimension: 68,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      PulseRing(
                        size: 68,
                        color: _red,
                        active: _recording,
                        filled: false,
                        grow: 1.4,
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: _red,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: _recording
                              ? Container(
                                  key: const ValueKey('stop'),
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                )
                              : const DashboardIcon(
                                  'mic',
                                  key: ValueKey('mic'),
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: dashboardText(15, color: _red, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _recording ? .6 : .25,
              child: Waveform(
                color: _red,
                count: 26,
                maxHeight: 30,
                level: _recording ? .9 : .2,
                animate: _recording,
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
      ),
    );
  }
}

class _WitnessCard extends ConsumerWidget {
  const _WitnessCard({
    required this.witness,
    required this.required,
    required this.onAdd,
    required this.onRemove,
  });
  final String? witness;
  final bool required;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final large = ref.watch(largerTouchTargetsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Witness',
                style: dashboardText(15, weight: FontWeight.w600),
              ),
              ProjectBadge(
                label: 'Required for thumbprint & verbal',
                fill: institutionTint(ref, context),
                ink: primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'An impartial person confirms the form was read and understood.',
            style: dashboardText(13, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduceMotion(context) ? 150 : 250),
            child: witness == null
                ? DashboardAction(
                    key: const ValueKey('add'),
                    label: 'Add witness signature',
                    radius: 22,
                    onPressed: onAdd,
                    child: SizedBox(
                      height: large ? 56 : 44,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DashboardIcon('projects/plus', color: primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Add witness signature',
                              style: dashboardText(
                                14,
                                color: primary,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Container(
                    key: const ValueKey('done'),
                    constraints: BoxConstraints(minHeight: large ? 56 : 44),
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        const DrawnCheck(size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Witnessed by $witness',
                            style: dashboardText(14, weight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 44),
                            overlayColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                          ),
                          onPressed: onRemove,
                          child: Text(
                            'Remove',
                            style: dashboardText(
                              13,
                              color: primary,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (required && witness == null) ...[
            const SizedBox(height: 8),
            Text(
              'Add a witness to finish.',
              style: dashboardText(
                12,
                color: const Color(0xFF9A5B00),
                weight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WitnessSheet extends StatefulWidget {
  const _WitnessSheet();
  @override
  State<_WitnessSheet> createState() => _WitnessSheetState();
}

class _WitnessSheetState extends State<_WitnessSheet> {
  final _name = TextEditingController();
  bool _signed = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _name.text.trim().isNotEmpty && _signed;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        12 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Witness signature',
              style: dashboardText(20, weight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'I saw the form read and understood, and consent given freely.',
              style: dashboardText(14, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Witness full name',
                filled: true,
                fillColor: AppColors.canvas,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SignaturePad(
              height: 180,
              onChanged: (v) => setState(() => _signed = v),
            ),
            const SizedBox(height: 16),
            ConsentPillButton(
              label: 'Save witness',
              icon: 'projects/check',
              height: 56,
              onPressed: ready
                  ? () => Navigator.pop(context, _name.text.trim())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
