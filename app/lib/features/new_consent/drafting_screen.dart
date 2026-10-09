import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  List<String> _steps(int pages, String institution) => [
    'Reading $pages pages',
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
    }
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
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref.watch(newConsentPreviewProvider);
    final file = ref.watch(consentDraftProvider).file;
    final institution =
        ref.watch(selectedInstitutionProvider) ?? Institution.nust;
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    final steps = _steps(file?.pages ?? 18, institution.label);
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
                            if (!preview)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  'The on-device AI is not connected yet, so no draft can be made.',
                                  style: dashboardText(
                                    14,
                                    color: AppColors.muted,
                                  ),
                                ),
                              )
                            else
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
                if (preview)
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
