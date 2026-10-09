import 'package:flutter/material.dart';

import '../../features/dashboard/dashboard_components.dart';
import '../theme/app_theme.dart';

/// Figma component "Toast" (Screen Artboards, beside row 04): in-app
/// notification used instead of system snackbars.
///
/// 350 × 64 white card, radius 20, 1 dp line border, soft shadow; a 36 dp
/// tinted icon tile, title (14 semibold) + subtitle (12 regular), an optional
/// action pill (32 dp tall inside a 48 dp target) and, for Success with an
/// action, a brand-green countdown line along the bottom.
enum AppToastKind { success, info, offline, error }

class AppToast extends StatelessWidget {
  const AppToast({
    super.key,
    required this.kind,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.countdown,
  });

  final AppToastKind kind;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a line that shrinks over this duration (e.g. 5 s Undo window).
  final Duration? countdown;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tint = Color.lerp(Colors.white, primary, .11)!;
    final (String icon, Color tileFill, Color ink) = switch (kind) {
      AppToastKind.success => (
        'projects/check',
        AppColors.brand50,
        AppColors.brandDark,
      ),
      AppToastKind.info => ('consent/info', tint, primary),
      AppToastKind.offline => (
        'consent/cloud',
        const Color(0xFFFEF4E2),
        const Color(0xFF9A5B00),
      ),
      AppToastKind.error => (
        'consent/alert',
        const Color(0xFFFDECEC),
        AppColors.error,
      ),
    };
    final isError = kind == AppToastKind.error;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A111614),
              offset: Offset(0, 8),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                actionLabel == null ? 14 : 8,
                actionLabel == null ? 14 : 6,
                actionLabel == null ? 14 : 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tileFill,
                      shape: BoxShape.circle,
                    ),
                    child: DashboardIcon(icon, color: ink, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: dashboardText(14, weight: FontWeight.w600),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: dashboardText(12, color: AppColors.subtle),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: Center(
                        child: DashboardAction(
                          label: actionLabel!,
                          radius: 16,
                          color: isError ? const Color(0xFFFDECEC) : tint,
                          onPressed: onAction ?? () {},
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 32),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              child: Text(
                                actionLabel!,
                                style: dashboardText(
                                  13,
                                  color: isError ? AppColors.error : primary,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (countdown != null && !reduced)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1, end: 0),
                  duration: countdown!,
                  builder: (context, v, _) => Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: v,
                      child: Container(height: 3, color: AppColors.brand),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Toast entrance used wherever an [AppToast] appears: slides up 16 dp and
/// fades in (250 ms easeOutCubic); fade only with Reduce motion.
Widget appToastTransition(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  final fade = FadeTransition(opacity: animation, child: child);
  if (MediaQuery.disableAnimationsOf(context)) return fade;
  return SlideTransition(
    position: Tween(
      begin: const Offset(0, .25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
    child: fade,
  );
}
