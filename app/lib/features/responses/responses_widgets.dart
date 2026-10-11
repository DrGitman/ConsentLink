import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'responses_data.dart';

bool _reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// White card, radius 24 (Figma cards on 07.1–07.3).
class WhiteCard extends StatelessWidget {
  const WhiteCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: child,
  );
}

/// Row of 38 dp pill chips (Figma Chip): selected = institution colour,
/// others white with a line border. Scrolls sideways when it doesn't fit.
class PillChips<T> extends ConsumerWidget {
  const PillChips({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.semanticLabel,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final String Function(T)? semanticLabel;
  final ValueChanged<T> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final duration = _reduced(context)
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final value in values) ...[
            if (value != values.first) const SizedBox(width: 6),
            Semantics(
              selected: value == selected,
              child: DashboardAction(
                label: (semanticLabel ?? label)(value),
                radius: 30,
                color: Colors.transparent,
                onPressed: () => onSelected(value),
                child: AnimatedContainer(
                  duration: duration,
                  curve: Curves.easeOut,
                  constraints: BoxConstraints(minHeight: large ? 56 : 38),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? primary : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: value == selected ? primary : AppColors.line,
                    ),
                  ),
                  child: Text(
                    label(value),
                    style: dashboardText(
                      14,
                      color: value == selected ? Colors.white : AppColors.muted,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge colours per status (Figma Badge/Agreed, Declined, Withdrew).
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key, this.label, this.icon});
  final ResponseStatus status;
  final String? label;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final (fill, ink) = statusColors(status);
    return ProjectBadge(
      label: label ?? status.label,
      fill: fill,
      ink: ink,
      icon: icon,
    );
  }
}

(Color, Color) statusColors(ResponseStatus status) => switch (status) {
  ResponseStatus.agreed => (AppColors.brand50, AppColors.brandDark),
  ResponseStatus.declined => (const Color(0xFFFDECEC), AppColors.error),
  ResponseStatus.withdrew => (AppColors.canvas, AppColors.muted),
};

/// Fades and rises in, 35 ms apart (Figma stagger token). Static with
/// Reduce motion.
class StaggerIn extends StatelessWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (_reduced(context)) return child;
    final delay = 35 * index.clamp(0, 8);
    final total = 250 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      builder: (context, t, child) {
        final v = Curves.easeOutCubic.transform(
          ((t * total - delay) / 250).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// The app toast (Figma "Toast") shown over everything for 3 s, for screens
/// that don't host one themselves.
void showOverlayToast(
  BuildContext context, {
  required AppToastKind kind,
  required String title,
  String? subtitle,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastHost(
      kind: kind,
      title: title,
      subtitle: subtitle,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.onDone,
  });
  final AppToastKind kind;
  final String title;
  final String? subtitle;
  final VoidCallback onDone;
  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 20,
    right: 20,
    bottom: 96 + MediaQuery.paddingOf(context).bottom,
    child: SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: appToastTransition(
            context,
            Material(
              type: MaterialType.transparency,
              child: Semantics(
                liveRegion: true,
                child: AppToast(
                  kind: widget.kind,
                  title: widget.title,
                  subtitle: widget.subtitle,
                ),
              ),
            ),
            CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
          ),
        ),
      ),
    ),
  );
}

/// Empty / not-connected card.
class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => WhiteCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: dashboardText(16, weight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
          message,
          style: dashboardText(
            14,
            color: AppColors.muted,
          ).copyWith(height: 1.35),
        ),
      ],
    ),
  );
}
