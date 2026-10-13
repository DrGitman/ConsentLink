import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// Figma row 11 skeleton rules:
/// - same layout as the loaded screen (nothing jumps when data arrives);
/// - header, back button and tab bar stay real and usable;
/// - shown only after 300 ms; content fades in over 200 ms when ready;
/// - after 3 s a short message says why it is taking long;
/// - blocks #E4E8E6 on white cards, #EEF1EF for secondary lines;
/// - shimmer 1.3 s, left → right; static with Reduce motion;
/// - screen readers hear "Loading …" once, not every block.

/// Data on this phone loads instantly, so skeletons only appear when
/// something is slow. LOADING_PREVIEW=true makes every screen pretend to
/// load for LOADING_MS (default 2000 ms) so the states can be checked.
final loadingPreviewProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('LOADING_PREVIEW'),
);
final loadingPreviewDurationProvider = Provider<Duration>(
  (ref) => const Duration(
    milliseconds: int.fromEnvironment('LOADING_MS', defaultValue: 2000),
  ),
);

const boneColor = Color(0xFFE4E8E6);
const boneSoft = Color(0xFFEEF1EF);

/// One grey block. Radius defaults to half the height (pill), like Figma.
class Bone extends StatelessWidget {
  const Bone(
    this.width,
    this.height, {
    super.key,
    this.radius,
    this.soft = false,
    this.circle = false,
    this.color,
  });
  final double? width;
  final double height;
  final double? radius;
  final bool soft;
  final bool circle;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color ?? (soft ? boneSoft : boneColor),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius ?? height / 2),
    ),
  );
}

enum BoneAnchor { left, right, scale }

/// A bone placed with Figma coordinates inside a 350 dp wide card.
/// left: fixed x; right: kept the same distance from the right edge;
/// scale: x scaled with the card width (chart bars, columns).
class B {
  const B(
    this.x,
    this.y,
    this.w,
    this.h, {
    this.r,
    this.soft = false,
    this.circle = false,
    this.color,
    this.anchor = BoneAnchor.left,
  });
  final double x, y, w, h;
  final double? r;
  final bool soft, circle;
  final Color? color;
  final BoneAnchor anchor;
}

/// White card (radius 24) with bones at Figma positions. Figma cards are
/// 350 wide; other widths keep the same look.
class BoneCard extends StatelessWidget {
  const BoneCard({
    super.key,
    required this.height,
    required this.bones,
    this.color = Colors.white,
    this.radius = 24,
    this.figmaWidth = 350,
  });
  final double height;
  final List<B> bones;
  final Color color;
  final double radius;
  final double figmaWidth;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          children: [
            for (final b in bones)
              () {
                final x = switch (b.anchor) {
                  BoneAnchor.left => b.x,
                  BoneAnchor.right => w - (figmaWidth - b.x),
                  BoneAnchor.scale => b.x * w / figmaWidth,
                };
                final width = math.max(0.0, math.min(b.w, w - x - 12));
                return Positioned(
                  left: x,
                  top: b.y,
                  child: Bone(
                    b.circle ? b.w : width,
                    b.h,
                    radius: b.r,
                    soft: b.soft,
                    circle: b.circle,
                    color: b.color,
                  ),
                );
              }(),
          ],
        );
      },
    ),
  );
}

/// Figma shimmer: a soft white band, 140 dp wide and tilted 12°, sweeps
/// left → right every 1.3 s over the grey blocks only.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});
  final Widget child;
  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        // srcATop: the band only lightens what is painted (blocks, cards).
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final x = -180 + (bounds.width + 220) * _controller.value;
          return const LinearGradient(
            colors: [Color(0x00FFFFFF), Color(0xB3FFFFFF), Color(0x00FFFFFF)],
            transform: GradientRotation(-12 * math.pi / 180),
          ).createShader(Rect.fromLTWH(x, 0, 140, bounds.height));
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Pretend loading for LOADING_PREVIEW. `hold` keeps it loading (design
/// checks). Real data can pass its own `loading` to [SkeletonSwitch].
class PreviewLoad extends ConsumerStatefulWidget {
  const PreviewLoad({super.key, required this.builder, this.hold = false});
  final Widget Function(BuildContext context, bool loading) builder;
  final bool hold;
  @override
  ConsumerState<PreviewLoad> createState() => _PreviewLoadState();
}

class _PreviewLoadState extends ConsumerState<PreviewLoad> {
  late bool _loading = widget.hold || ref.read(loadingPreviewProvider);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_loading && !widget.hold) {
      _timer = Timer(ref.read(loadingPreviewDurationProvider), () {
        if (mounted) setState(() => _loading = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _loading || widget.hold);
}

/// Shows [skeleton] while [loading] (after 300 ms), a short reason after
/// 3 s, then fades [child] in over 200 ms.
class SkeletonSwitch extends StatefulWidget {
  const SkeletonSwitch({
    super.key,
    required this.loading,
    required this.label,
    required this.skeleton,
    required this.child,
    this.slowMessage = 'Decrypting records on this phone…',
  });
  final bool loading;

  /// Read once by screen readers, e.g. "Loading projects".
  final String label;
  final Widget skeleton;
  final Widget child;
  final String slowMessage;

  @override
  State<SkeletonSwitch> createState() => _SkeletonSwitchState();
}

class _SkeletonSwitchState extends State<SkeletonSwitch> {
  bool _visible = false;
  bool _slow = false;
  Timer? _show;
  Timer? _late;

  @override
  void initState() {
    super.initState();
    if (widget.loading) _start();
  }

  @override
  void didUpdateWidget(SkeletonSwitch old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) _start();
    if (!widget.loading && old.loading) _stop();
  }

  void _start() {
    _show = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
    _late = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  void _stop() {
    _show?.cancel();
    _late?.cancel();
    _visible = false;
    _slow = false;
  }

  @override
  void dispose() {
    _show?.cancel();
    _late?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final Widget current;
    if (!widget.loading) {
      current = KeyedSubtree(key: const ValueKey('ready'), child: widget.child);
    } else if (!_visible) {
      // Under 300 ms: show nothing rather than flash a skeleton.
      current = const SizedBox(key: ValueKey('wait'), width: double.infinity);
    } else {
      current = KeyedSubtree(
        key: const ValueKey('skeleton'),
        child: Stack(
          children: [
            Semantics(
              liveRegion: true,
              label: widget.label,
              child: ExcludeSemantics(
                child: SkeletonShimmer(child: widget.skeleton),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _SlowNote(text: widget.slowMessage, shown: _slow),
            ),
          ],
        ),
      );
    }
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduced ? 0 : 200),
      switchInCurve: Curves.easeOut,
      // Keep the "Loading …" label readable from the first frame of the fade:
      // a plain FadeTransition drops semantics while the opacity is still 0.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        alwaysIncludeSemantics: true,
        child: child,
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [...previous, ?current],
      ),
      // Full width, so content lays out exactly as without the switch.
      child: SizedBox(key: current.key, width: double.infinity, child: current),
    );
  }
}

/// After 3 s: why it is slow, in a small pill over the skeleton (no layout
/// shift).
class _SlowNote extends StatelessWidget {
  const _SlowNote({required this.text, required this.shown});
  final String text;
  final bool shown;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      excluding: !shown,
      child: Semantics(
        liveRegion: true,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
          ),
          child: Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.line),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
