import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import 'field_capture_data.dart';

/// Page frame for 06.1–06.6: safe area, 600 dp max width, a scrolling body
/// and a pinned footer. Participant screens get the session's "Large text"
/// (150%, or more if the phone is already set larger).
class CaptureScaffold extends ConsumerWidget {
  const CaptureScaffold({
    super.key,
    required this.children,
    this.footer,
    this.background = Colors.white,
    this.participant = true,
    this.padding = const EdgeInsets.fromLTRB(20, 23, 20, 24),
    this.onBack,
    this.scaleFooter = true,
  });
  final List<Widget> children;

  /// False keeps the footer at the phone's own text size (researcher actions
  /// such as "Hand back to researcher" don't follow the participant's
  /// Large text).
  final bool scaleFooter;
  final Widget? footer;
  final Color background;
  final bool participant;
  final EdgeInsets padding;

  /// System back runs the same action as the on-screen Back button, so the
  /// participant never drops out of the flow by accident.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final largeText = ref.watch(
      captureSessionProvider.select((s) => s.largeText),
    );
    // The phone's own settings, before this session's Large text.
    final base = MediaQuery.of(context);
    Widget page = Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  ),
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: scaleFooter
                        ? footer
                        : MediaQuery(data: base, child: footer!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (onBack != null) {
      page = PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onBack!();
        },
        child: page,
      );
    }
    if (!participant || !largeText) return page;
    final scale = math.max(base.textScaler.scale(1), 1.5);
    return MediaQuery(
      data: base.copyWith(textScaler: TextScaler.linear(scale)),
      child: page,
    );
  }
}

/// 8 dp progress bar, line track, institution colour fill that slides 400 ms.
class CaptureProgress extends StatelessWidget {
  const CaptureProgress({super.key, required this.value, this.label});
  final double value;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: label,
      value: '${(value * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.line)),
              TweenAnimationBuilder<double>(
                tween: Tween(end: value.clamp(0.0, 1.0)),
                duration: reduceMotion(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                builder: (context, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
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

/// "Question 2 of 4" / title 30 / helper 16 (Figma 06.3–06.5).
class CaptureHeading extends StatelessWidget {
  const CaptureHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    this.helper,
    this.titleSize = 30,
  });
  final String eyebrow;
  final String title;
  final String? helper;
  final double titleSize;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
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
          title,
          style: dashboardText(titleSize, weight: FontWeight.w600),
        ),
      ),
      if (helper != null) ...[
        const SizedBox(height: 6),
        Text(
          helper!,
          style: dashboardText(
            16,
            color: AppColors.muted,
          ).copyWith(height: 1.2),
        ),
      ],
    ],
  );
}

/// Back (110 wide, outline) + primary action, as in every participant screen.
class CaptureFooter extends StatelessWidget {
  const CaptureFooter({
    super.key,
    required this.onBack,
    required this.nextLabel,
    required this.onNext,
    this.nextIcon,
    this.height = 56,
  });
  final VoidCallback onBack;
  final String nextLabel;
  final String? nextIcon;
  final VoidCallback? onNext;
  final double height;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 110,
        child: ConsentPillButton(
          label: 'Back',
          filled: false,
          height: height,
          onPressed: onBack,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ConsentPillButton(
          label: nextLabel,
          icon: nextIcon,
          height: height,
          onPressed: onNext,
        ),
      ),
    ],
  );
}

/// Round icon button with a fill (Figma IconBtn: 44 canvas, 40 white).
class CaptureIconButton extends ConsumerWidget {
  const CaptureIconButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.child,
    this.size = 44,
    this.fill = AppColors.canvas,
    this.iconColor = AppColors.ink,
    this.iconSize = 22,
  });
  final String label;
  final VoidCallback onPressed;
  final String? icon;
  final Widget? child;
  final double size;
  final Color fill;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final d = large ? size + 20 : size;
    return SizedBox.square(
      dimension: math.max(d, 48),
      child: Center(
        child: DashboardAction(
          label: label,
          onPressed: onPressed,
          radius: d / 2,
          color: fill,
          child: SizedBox.square(
            dimension: d,
            child: Center(
              child:
                  child ??
                  DashboardIcon(icon!, color: iconColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown instead of sample content when no session is connected.
class CaptureNotConnected extends StatelessWidget {
  const CaptureNotConnected({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No participant session',
          style: dashboardText(16, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Field capture needs an approved consent form from a project. '
          'Project sync isn\'t connected yet, so nothing can be collected.',
          style: dashboardText(
            14,
            color: AppColors.muted,
          ).copyWith(height: 1.35),
        ),
      ],
    ),
  );
}

/// Breathing scale for loops (mic, record dot). Static with Reduce motion.
class Breathe extends StatefulWidget {
  const Breathe({
    super.key,
    required this.child,
    this.active = true,
    this.period = const Duration(milliseconds: 2400),
    this.to = 1.06,
  });
  final Widget child;
  final bool active;
  final Duration period;
  final double to;
  @override
  State<Breathe> createState() => _BreatheState();
}

class _BreatheState extends State<Breathe> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  void _sync() {
    final on = widget.active && !reduceMotion(context);
    if (on && !_c.isAnimating) _c.repeat(reverse: true);
    if (!on && _c.isAnimating) _c.animateTo(0, duration: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Breathe old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.scale(
      scale: 1 + (widget.to - 1) * Curves.easeInOut.transform(_c.value),
      child: child,
    ),
    child: widget.child,
  );
}

/// Expanding, fading ring behind a button (mic halo, record dot).
class PulseRing extends StatefulWidget {
  const PulseRing({
    super.key,
    required this.size,
    required this.color,
    this.active = true,
    this.period = const Duration(milliseconds: 1200),
    this.grow = 1.35,
    this.filled = true,
  });
  final double size;
  final Color color;
  final bool active;
  final Duration period;
  final double grow;
  final bool filled;
  @override
  State<PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<PulseRing>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: widget.period);

  void _sync() {
    final on = widget.active && !reduceMotion(context);
    if (on && !_c.isAnimating) _c.repeat();
    if (!on && _c.isAnimating) _c.reset();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseRing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) {
      if (!_c.isAnimating) return SizedBox.square(dimension: widget.size);
      final t = Curves.easeOut.transform(_c.value);
      return Transform.scale(
        scale: 1 + (widget.grow - 1) * t,
        child: Opacity(
          opacity: (1 - t) * .8,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.filled ? widget.color : null,
              border: widget.filled
                  ? null
                  : Border.all(color: widget.color, width: 2),
            ),
          ),
        ),
      );
    },
  );
}

/// Bars 5 wide, 10 apart, radius 3 (Figma waveform). [level] 0–1 drives the
/// heights; [animate] adds a gentle travelling wave so the bars feel alive
/// between level updates. Static with Reduce motion.
class Waveform extends StatefulWidget {
  const Waveform({
    super.key,
    required this.color,
    this.level = .6,
    this.animate = true,
    this.count = 28,
    this.minHeight = 8,
    this.maxHeight = 34,
  });
  final Color color;
  final double level;
  final bool animate;
  final int count;
  final double minHeight;
  final double maxHeight;
  @override
  State<Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<Waveform>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  // Figma's resting pattern, as a fraction of the max height.
  static const _pattern = [
    .2, .8, .45, .6, .7, .3, .85, .38, .68, .65, .42, .85, .2, .75, //
    .55, .55, .75, .2, .85, .42, .65, .68, .38, .85, .3, .7, .6, .45,
  ];

  void _sync() {
    final on = widget.animate && !reduceMotion(context);
    if (on && !_c.isAnimating) _c.repeat();
    if (!on && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Waveform old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: widget.maxHeight,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.count; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 5,
                height: _height(i),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  double _height(int i) {
    final base = _pattern[i % _pattern.length];
    final wave = _c.isAnimating
        ? .65 + .35 * math.sin((_c.value * 2 * math.pi) + i * .7)
        : 1.0;
    final level = widget.level.clamp(.15, 1.0);
    final f = (base * wave * level).clamp(0.0, 1.0);
    return widget.minHeight + (widget.maxHeight - widget.minHeight) * f;
  }
}
