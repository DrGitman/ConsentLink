import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/dashboard/dashboard_components.dart';
import '../../features/preferences/accessibility_preferences.dart';
import '../theme/app_theme.dart';

/// The app's on/off switch, the same as on the Language & accessibility
/// screen: 50 × 30 track (64 × 38 with larger targets) in the institution
/// colour when on and #D5DAD8 when off, a white 24 dp knob that slides in
/// 200 ms (Figma "Toggle & button press"). Instant with Reduce motion.
class AppToggle extends ConsumerWidget {
  const AppToggle({super.key, required this.value, this.enabled = true});
  final bool value;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        width: large ? 64 : 50,
        height: large ? 38 : 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? primary : const Color(0xFFD5DAD8),
          borderRadius: BorderRadius.circular(large ? 19 : 15),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: SizedBox.square(
            dimension: large ? 32 : 24,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A full-width row with a title, optional subtitle and an [AppToggle].
/// Whole row is the tap target; no grey press overlay.
class AppToggleRow extends ConsumerWidget {
  const AppToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: title,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: large ? 72 : 56),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: dashboardText(16, weight: FontWeight.w500),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: dashboardText(13, color: AppColors.subtle),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppToggle(value: value, enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
