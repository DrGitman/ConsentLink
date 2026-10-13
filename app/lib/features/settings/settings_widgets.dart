import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toggle.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';

/// Full-screen settings page (08.2–08.5): back button + centred title, a
/// scrolling body and an optional pinned footer.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.footer,
    this.fallback = '/me',
  });
  final String title;
  final List<Widget> children;
  final Widget? footer;

  /// Where Back goes when there is nothing to pop (opened directly).
  final String fallback;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.canvas,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConsentTopBar(
                        leading: AppBackButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(fallback),
                        ),
                        title: title,
                      ),
                      const SizedBox(height: 10),
                      ...children,
                    ],
                  ),
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: footer,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// White group card, radius 24, rows inset 16.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 6),
  });
  final List<Widget> children;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(children: children),
  );
}

/// Section label (14 semibold muted), e.g. "How often".
class SettingsLabel extends StatelessWidget {
  const SettingsLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: dashboardText(14, color: AppColors.muted, weight: FontWeight.w600),
    ),
  );
}

/// 44 dp tinted icon tile (radius 14).
class SettingsIcon extends ConsumerWidget {
  const SettingsIcon(this.icon, {super.key});
  final String icon;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: 44,
    height: 44,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: institutionTint(ref, context),
      borderRadius: BorderRadius.circular(14),
    ),
    child: DashboardIcon(icon, color: Theme.of(context).colorScheme.primary),
  );
}

/// Figma Row/…: icon tile, title 16 medium, optional subtitle 13, chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.minHeight = 60,
  });
  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double minHeight;
  @override
  Widget build(BuildContext context) => DashboardAction(
    label: subtitle == null ? title : '$title, $subtitle',
    radius: 16,
    onPressed: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SettingsIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: _Titles(title: title, subtitle: subtitle),
            ),
            const SizedBox(width: 8),
            const DashboardIcon(
              'chevron_right',
              color: AppColors.subtle,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Row with the app toggle; the whole row toggles (no press overlay).
class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.minHeight = 58,
  });
  final String icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: title,
      hint: subtitle,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SettingsIcon(icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Titles(title: title, subtitle: subtitle),
                  ),
                  const SizedBox(width: 12),
                  AppToggle(value: value, enabled: enabled),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: dashboardText(16, weight: FontWeight.w500)),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle!, style: dashboardText(13, color: AppColors.subtle)),
      ],
    ],
  );
}

/// Radio dot (24 dp): filled institution colour with a white centre when
/// selected, grey ring otherwise. The centre pops in.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected});
  final bool selected;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final duration = reduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return AnimatedContainer(
      duration: duration,
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? primary : const Color(0xFFB9C0BD),
          width: 1.5,
        ),
      ),
      child: AnimatedScale(
        duration: duration,
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Confirm dialog in the app style (Figma 07.5 pattern): scales 92% → 100%.
Future<bool?> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  String icon = 'consent/alert',
  bool destructive = true,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel',
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    transitionDuration: Duration(milliseconds: reduced ? 150 : 250),
    pageBuilder: (context, _, _) => _ConfirmDialog(
      title: title,
      message: message,
      confirm: confirm,
      icon: icon,
      destructive: destructive,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final fade = FadeTransition(opacity: curved, child: child);
      if (reduced) return fade;
      return ScaleTransition(
        scale: Tween(begin: .92, end: 1.0).animate(curved),
        child: fade,
      );
    },
  );
}

class _ConfirmDialog extends ConsumerWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirm,
    required this.icon,
    required this.destructive,
  });
  final String title;
  final String message;
  final String confirm;
  final String icon;
  final bool destructive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final accent = destructive ? AppColors.error : primary;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: destructive
                            ? const Color(0xFFFDECEC)
                            : institutionTint(ref, context),
                        shape: BoxShape.circle,
                      ),
                      child: DashboardIcon(icon, color: accent),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: dashboardText(22, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      message,
                      style: dashboardText(
                        14,
                        color: AppColors.muted,
                      ).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ConsentPillButton(
                            label: 'Cancel',
                            filled: false,
                            height: 52,
                            onPressed: () => Navigator.pop(context, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardAction(
                            label: confirm,
                            radius: 26,
                            color: accent,
                            onPressed: () => Navigator.pop(context, true),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: large ? 64 : 52,
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    confirm,
                                    textAlign: TextAlign.center,
                                    style: dashboardText(
                                      15,
                                      color: Colors.white,
                                      weight: FontWeight.w600,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
