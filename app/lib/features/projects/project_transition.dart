import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Figma Animations "Navigation — push & back" (03.3 → 03.4 → back):
/// the new screen slides in from the right while the screen underneath
/// shifts 25% left and dims. Back reverses it. 350 ms easeOutCubic, the same
/// timing as the other pushed screens. With Reduce motion it is a 150 ms fade.
CustomTransitionPage<void> projectPushPage({
  required LocalKey key,
  required Widget child,
}) => CustomTransitionPage<void>(
  key: key,
  transitionDuration: const Duration(milliseconds: 350),
  reverseTransitionDuration: const Duration(milliseconds: 350),
  child: child,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 150 / 350, curve: Curves.easeOut),
        ),
        child: child,
      );
    }
    final incoming = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(-.25, 0),
        end: Offset.zero,
      ).animate(ReverseAnimation(outgoing)),
      child: AnimatedBuilder(
        animation: outgoing,
        builder: (context, child) => ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: .12 * outgoing.value),
            BlendMode.srcATop,
          ),
          child: child,
        ),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(incoming),
          child: DecoratedBox(
            // Opaque page so the screen underneath doesn't show through.
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  },
);
