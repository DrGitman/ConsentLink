import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../contracts/consent_ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../institution/institution.dart';
import '../institution/institution_preferences.dart';
import '../projects/project_widgets.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';

/// Figma Screen Artboards 04.2 AI analysing + Animations "AI drafting —
/// progress": the orb breathes, steps tick off with a popping drawn check,
/// the bar fills. Reduce motion: steps tick, no breathing.
///
/// Preview only: no model runs. Each step takes 0.7 s, then the sample draft
/// opens. The real on-device model (P3) will drive the same steps.
class DraftingScreen extends ConsumerStatefulWidget {
  const DraftingScreen({super.key});
  @override
  ConsumerState<DraftingScreen> createState() => _DraftingScreenState();
}

class _DraftingScreenState extends ConsumerState<DraftingScreen>
    with SingleTickerProviderStateMixin {
  static const _stepMs = 700;
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  Timer? _timer;
  int _done = 0;
  bool _stopped = false;

  List<String> _steps(int pages, String institution, {bool answers = false}) =>
      [
        answers ? 'Reading your answers' : 'Reading $pages pages',
        'Purpose, procedures & duration',
        'Risks, benefits & compensation',
        'Checking $requiredElementCount required consent elements',
        'Rewriting at plain-language level (Grade 6)',
        'Applying $institution template & logo',
      ];

  @override
  void initState() {
    super.initState();
    if (ref.read(newConsentPreviewProvider)) {
      _timer = Timer.periodic(const Duration(milliseconds: _stepMs), (t) {
        if (!mounted || _stopped) return;
        setState(() => _done++);
        if (_done >= 6) {
          t.cancel();
          Timer(const Duration(milliseconds: 500), () {
            if (!mounted || _stopped) return;
            ref.read(consentDraftProvider.notifier).loadSampleDraft();
            context.pushReplacement('/new-consent/review');
          });
        }
      });
    } else {
      // Live: the on-device model drafts the uploaded proposal.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLive());
    }
  }

  StreamSubscription<AiDraftingEvent>? _live;

  void _startLive() {
    if (!mounted) return;
    _live = ref
        .read(consentDraftProvider.notifier)
        .draft()
        .listen(
          (event) {
            if (event is AiStepCompleted && mounted && !_stopped) {
              setState(() => _done = event.step.index + 1);
            }
          },
          onError: (Object error) {
            if (!mounted || _stopped) return;
            _failed(error);
          },
          onDone: () {
            if (!mounted || _stopped) return;
            setState(() => _done = 6);
            Timer(const Duration(milliseconds: 400), () {
              if (mounted && !_stopped) {
                context.pushReplacement('/new-consent/review');
              }
            });
          },
        );
  }

  Future<void> _failed(Object error) async {
    final message = switch (error) {
      AiDraftingException(failure: AiDraftingFailure.encryptedPdf) =>
        'The PDF is password protected. Upload a copy without a password.',
      AiDraftingException(failure: AiDraftingFailure.scannedPdf) =>
        'This PDF is a scan, so its text can\'t be read. Upload a PDF with selectable text.',
      AiDraftingException(failure: AiDraftingFailure.corruptedPdf) =>
        'The file is not a readable PDF.',
      AiDraftingException(failure: AiDraftingFailure.proposalTooLarge) =>
        'The proposal is too large. Upload a smaller PDF.',
      AiDraftingException(failure: AiDraftingFailure.tooManyPages) =>
        'The proposal has too many pages. Upload only the parts participants need.',
      AiDraftingException(failure: AiDraftingFailure.modelUnavailable) =>
        'The on-device AI is not available on this phone.',
      _ => 'Drafting stopped because of a problem on this phone. Try again.',
    };
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drafting stopped'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
      _breath.value = 0;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _live?.cancel();
    _timer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    final stop = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: Duration(
        milliseconds: reduceMotion(context) ? 150 : 250,
      ),
      pageBuilder: (context, _, _) => AlertDialog(
        title: const Text('Stop drafting?'),
        content: const Text(
          'Your uploaded proposal is kept. You can start drafting again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Stop'),
          ),
        ],
      ),
      transitionBuilder: (context, a, _, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        final fade = FadeTransition(opacity: c, child: child);
        if (reduceMotion(context)) return fade;
        return ScaleTransition(
          scale: Tween(begin: .92, end: 1.0).animate(c),
          child: fade,
        );
      },
    );
    if (stop == true && mounted) {
      _stopped = true;
      _timer?.cancel();
      _live?.cancel();
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = ref.watch(consentDraftProvider).file;
    final fromAnswers = ref.watch(consentDraftProvider).answers != null;
    final institution =
        ref.watch(selectedInstitutionProvider) ?? Institution.nust;
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final steps = _steps(
      file?.pages ?? 18,
      institution.label,
      answers: fromAnswers,
    );
    final remainingSeconds = ((6 - _done) * _stepMs / 1000).ceil();

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ProjectCircleButton(
                      icon: 'consent/x',
                      label: 'Stop drafting',
                      onPressed: _close,
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Phones shorter than the 844 dp Figma frame get a
                      // smaller orb and tighter gaps so the progress bar
                      // below stays on screen.
                      final compact = constraints.maxHeight < 660;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: Column(
                          children: [
                            SizedBox(height: compact ? 4 : 22),
                            _Orb(
                              breath: _breath,
                              primary: primary,
                              tint: tint,
                              halo: compact ? 92 : 120,
                              core: compact ? 56 : 70,
                            ),
                            SizedBox(height: compact ? 10 : 20),
                            Semantics(
                              header: true,
                              child: Text(
                                'Drafting your consent form',
                                textAlign: TextAlign.center,
                                style: dashboardText(
                                  compact ? 22 : 24,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Runs on this phone. Your proposal is not uploaded anywhere.',
                              textAlign: TextAlign.center,
                              style: dashboardText(14, color: AppColors.subtle),
                            ),
                            SizedBox(height: compact ? 14 : 24),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                16,
                                compact ? 4 : 8,
                                24,
                                compact ? 8 : 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                children: [
                                  for (final (i, label) in steps.indexed)
                                    _StepRow(
                                      label: label,
                                      compact: compact,
                                      state: i < _done
                                          ? _StepState.done
                                          : i == _done
                                          ? _StepState.active
                                          : _StepState.pending,
                                      primary: primary,
                                      tint: tint,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Progress stays pinned at the bottom, always in view.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: _done / 6),
                        duration: reduceMotion(context)
                            ? Duration.zero
                            : const Duration(milliseconds: _stepMs),
                        curve: Curves.linear,
                        builder: (context, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            color: primary,
                            backgroundColor: AppColors.line,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _done >= 6
                              ? 'Done'
                              : 'About $remainingSeconds '
                                    '${remainingSeconds == 1 ? 'second' : 'seconds'} left',
                          style: dashboardText(
                            13,
                            color: AppColors.subtle,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// AI orb: the halo breathes, a soft ring ripples outward and the sparkle
/// twinkles while the model works. Static with Reduce motion.
class _Orb extends StatefulWidget {
  const _Orb({
    required this.breath,
    required this.primary,
    required this.tint,
    required this.halo,
    required this.core,
  });
  final AnimationController breath;
  final Color primary;
  final Color tint;
  final double halo;
  final double core;
  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _ripple.stop();
    } else if (!_ripple.isAnimating) {
      _ripple.repeat();
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    final box = widget.halo * 1.3;
    final breath = CurvedAnimation(
      parent: widget.breath,
      curve: Curves.easeInOut,
    );
    return Semantics(
      label: 'AI is drafting',
      child: SizedBox.square(
        dimension: box,
        child: AnimatedBuilder(
          animation: Listenable.merge([widget.breath, _ripple]),
          builder: (context, _) {
            final b = reduced ? 0.0 : breath.value;
            final r = reduced ? 1.0 : _ripple.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Ripple ring
                if (!reduced)
                  Opacity(
                    opacity: (1 - r) * .7,
                    child: Container(
                      width: widget.halo * (1 + .3 * r),
                      height: widget.halo * (1 + .3 * r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.tint, width: 3),
                      ),
                    ),
                  ),
                // Breathing halo
                Container(
                  width: widget.halo * (1 + .08 * b),
                  height: widget.halo * (1 + .08 * b),
                  decoration: BoxDecoration(
                    color: widget.tint,
                    shape: BoxShape.circle,
                  ),
                ),
                // Core with twinkling sparkle
                Container(
                  width: widget.core,
                  height: widget.core,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: (b - .5) * .25,
                    child: Transform.scale(
                      scale: .92 + .16 * b,
                      child: DashboardIcon(
                        'sparkle',
                        color: Colors.white,
                        size: widget.core * .43,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _StepState { done, active, pending }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    this.compact = false,
    required this.state,
    required this.primary,
    required this.tint,
  });
  final String label;
  final bool compact;
  final _StepState state;
  final Color primary;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    final Widget marker = switch (state) {
      _StepState.done => const DrawnCheck(key: ValueKey('done')),
      _StepState.active => Container(
        key: const ValueKey('active'),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
        ),
      ),
      _StepState.pending => Container(
        key: const ValueKey('pending'),
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.canvas,
          shape: BoxShape.circle,
        ),
      ),
    };
    return Semantics(
      label:
          '$label, ${state == _StepState.done
              ? 'done'
              : state == _StepState.active
              ? 'in progress'
              : 'waiting'}',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: AnimatedSwitcher(
                duration: Duration(
                  milliseconds: reduceMotion(context) ? 0 : 150,
                ),
                child: marker,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedDefaultTextStyle(
                duration: Duration(
                  milliseconds: reduceMotion(context) ? 0 : 250,
                ),
                style: dashboardText(
                  14,
                  color: state == _StepState.pending
                      ? AppColors.subtle
                      : AppColors.ink,
                  weight: state == _StepState.pending
                      ? FontWeight.w400
                      : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
