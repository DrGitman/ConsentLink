import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../preferences/accessibility_preferences.dart';

bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// Top bar used by 04.1–04.4: a circle button, a centred title, an optional
/// trailing circle button. Keeps the title centred whatever is on the sides.
class ConsentTopBar extends StatelessWidget {
  const ConsentTopBar({
    super.key,
    required this.leading,
    required this.title,
    this.trailing,
  });
  final Widget leading;
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      leading,
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: dashboardText(17, weight: FontWeight.w600),
          ),
        ),
      ),
      // Balance the leading button so the title stays centred.
      trailing ?? Opacity(opacity: 0, child: ExcludeSemantics(child: leading)),
    ],
  );
}

/// Large pill button (Figma Button/…): 60 dp tall, primary fill, icon + label.
/// Disabled = primary at 35% (04.3 footer). Colour change is 250 ms.
class ConsentPillButton extends ConsumerWidget {
  const ConsentPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = true,
    this.height = 60,
    this.expand = true,
  });
  final String label;
  final String? icon;
  final VoidCallback? onPressed;
  final bool filled;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null;
    final fill = !filled
        ? Colors.white
        : enabled
        ? primary
        : primary.withValues(alpha: .35);
    final ink = filled ? Colors.white : AppColors.ink;
    final content = AnimatedContainer(
      duration: reduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: large ? height + 12 : height),
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(40),
        border: filled ? null : Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            DashboardIcon(icon!, color: filled ? Colors.white : primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: dashboardText(16, color: ink, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (!enabled) {
      return Semantics(
        button: true,
        enabled: false,
        label: label,
        child: ExcludeSemantics(child: content),
      );
    }
    return DashboardAction(
      label: label,
      radius: 40,
      color: Colors.transparent,
      onPressed: onPressed!,
      child: content,
    );
  }
}

/// Scale 0.6 → 1 with easeOutBack (Figma "emphasis" pop). Static with
/// Reduce motion.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .6, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: child,
    );
  }
}

/// Slides up 12 dp and fades in once (list items appearing). Fade only with
/// Reduce motion.
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: reduced ? 150 : 300),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, reduced ? 0 : 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// One horizontal shake (blocked file). Nothing with Reduce motion.
class ShakeOnce extends StatelessWidget {
  const ShakeOnce({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 4) * 8 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// A check mark drawn stroke by stroke inside a filled circle.
class DrawnCheck extends StatelessWidget {
  const DrawnCheck({super.key, this.size = 28, this.color = AppColors.brand});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final reduced = reduceMotion(context);
    return PopIn(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: reduced ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _CheckPainter(progress: t, color: color),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});
  final double progress;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    canvas.drawCircle(Offset(r, r), r, Paint()..color = color);
    final s = size.width / 28;
    final path = Path()
      ..moveTo(9 * s, 14.5 * s)
      ..lineTo(12.5 * s, 18 * s)
      ..lineTo(19.5 * s, 10.5 * s);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Soft institution tint (#E8EBF5 for NUST).
Color softPrimary(BuildContext context) =>
    Color.lerp(Colors.white, Theme.of(context).colorScheme.primary, .11)!;
