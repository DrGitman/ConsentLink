import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/skeleton.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../preferences/accessibility_preferences.dart';
import '../projects/project_widgets.dart';
import 'export_sheet.dart';
import 'responses_data.dart';
import 'responses_widgets.dart';

/// Figma 07.2 Consent record (3:3384) and 07.5 Withdraw confirmation
/// (4:18913). "Navigation — sheet & dialog": the export sheet rises with a
/// slight overshoot; the dialog scales 92% → 100% over a fading scrim.
class ConsentRecordScreen extends ConsumerWidget {
  const ConsentRecordScreen({super.key, required this.code});
  final String code;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/insights/responses');
    }
  }

  Future<void> _withdraw(
    BuildContext context,
    WidgetRef ref,
    ConsentResponse r,
  ) async {
    final ok = await showWithdrawDialog(context, firstName: r.name);
    if (ok != true || !context.mounted) return;
    ref.read(responsesProvider.notifier).withdraw(r.code, DateTime.now());
    showOverlayToast(
      context,
      kind: AppToastKind.info,
      title: 'Withdrawal recorded',
      subtitle: '${r.code} is excluded from analysis and exports',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(responsesProvider)
        .where((e) => e.code == code)
        .firstOrNull;
    final title = r == null ? code : '${r.code} · ${r.name}';

    // Figma 11.7: back and export stay real; the record is a skeleton
    // while it is decrypted.
    return PreviewLoad(
      builder: (context, loading) => Scaffold(
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
                              onPressed: () => _back(context),
                            ),
                            title: title,
                            trailing: r == null
                                ? null
                                : ProjectCircleButton(
                                    icon: 'projects/download',
                                    label: 'Export this record',
                                    onPressed: () => showExportSheet(
                                      context,
                                      subtitle: '${r.code} · 1 record',
                                      count: 1,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 10),
                          if (r == null)
                            const EmptyCard(
                              title: 'Record not found',
                              message:
                                  'It may not be on this phone. Sync isn\'t connected yet.',
                            )
                          else
                            SkeletonSwitch(
                              loading: loading,
                              label: 'Loading consent record',
                              skeleton: const ConsentRecordSkeleton(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StatusLine(response: r),
                                  const SizedBox(height: 12),
                                  RiseIn(child: _Answers(response: r)),
                                  const SizedBox(height: 12),
                                  RiseIn(child: _Signature(response: r)),
                                  const SizedBox(height: 12),
                                  RiseIn(child: _AuditTrail(response: r)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (r != null && !loading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      child: AnimatedSwitcher(
                        duration: Duration(
                          milliseconds: reduceMotion(context) ? 150 : 250,
                        ),
                        child: r.status == ResponseStatus.agreed
                            ? _WithdrawButton(
                                key: const ValueKey('withdraw'),
                                onPressed: () => _withdraw(context, ref, r),
                              )
                            : const SizedBox(key: ValueKey('none')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.response});
  final ConsentResponse response;
  @override
  Widget build(BuildContext context) {
    final r = response;
    final when = r.status == ResponseStatus.withdrew && r.withdrawnAt != null
        ? r.withdrawnAt!
        : r.at;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion(context) ? 150 : 250),
        child: StatusBadge(
          r.status,
          key: ValueKey(r.status),
          icon: r.status == ResponseStatus.agreed ? 'projects/check' : null,
          label: '${r.status.label} · ${longDate(when)} · ${r.site}',
        ),
      ),
    );
  }
}

class _Answers extends StatelessWidget {
  const _Answers({required this.response});
  final ConsentResponse response;
  @override
  Widget build(BuildContext context) {
    final rows = response.choices.entries.toList();
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, e) in rows.indexed) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: dashboardText(14, color: AppColors.muted),
                    ),
                  ),
                  Text(
                    e.value ? 'Yes' : 'No',
                    style: dashboardText(
                      14,
                      color: e.value ? AppColors.brandDark : AppColors.error,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 7),
          Text(
            'Language: ${response.language} · read aloud: ${response.readAloud ? 'on' : 'off'}',
            style: dashboardText(12, color: AppColors.subtle),
          ),
        ],
      ),
    );
  }
}

class _Signature extends StatelessWidget {
  const _Signature({required this.response});
  final ConsentResponse response;
  @override
  Widget build(BuildContext context) {
    final r = response;
    final primary = Theme.of(context).colorScheme.primary;
    final declined = r.status == ResponseStatus.declined;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: declined
          ? Text(
              'Declined before signing. No signature was taken.',
              style: dashboardText(13, color: AppColors.muted),
            )
          : Wrap(
              spacing: 44,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  label: 'Signature of ${r.name}',
                  image: true,
                  child: SizedBox(
                    width: 140,
                    height: 50,
                    child: CustomPaint(painter: _SignaturePainter(primary)),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Witness',
                      style: dashboardText(
                        12,
                        color: AppColors.subtle,
                        weight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      r.witness ?? 'None (signed)',
                      style: dashboardText(13, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// The signature drawn in Figma 07.2, as a stored stroke.
class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 25.6)
      ..cubicTo(10.77, -1.32, 18.85, -1.32, 21.54, 17.53)
      ..cubicTo(24.23, 36.37, 32.31, 39.07, 40.38, 14.84)
      ..cubicTo(48.46, -9.4, 51.15, -1.32, 56.54, 20.22)
      ..cubicTo(59.23, 30.99, 64.62, 30.99, 70, 17.53)
      ..cubicTo(75.38, 6.76, 80.77, 9.45, 83.46, 20.22)
      ..cubicTo(86.15, 28.3, 94.23, 25.6, 102.31, 14.84)
      ..cubicTo(107.69, 8.37, 115.77, 9.45, 129.23, 12.14);
    canvas.translate(5.38, 7.47);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => old.color != color;
}

class _AuditTrail extends StatelessWidget {
  const _AuditTrail({required this.response});
  final ConsentResponse response;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Audit trail',
              style: dashboardText(15, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, e) in response.audit.indexed) ...[
            if (i > 0) const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 4, right: 8),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    clock(e.time),
                    style: dashboardText(
                      12,
                      color: AppColors.muted,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.text,
                    style: dashboardText(12, color: AppColors.subtle),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WithdrawButton extends ConsumerWidget {
  const _WithdrawButton({super.key, required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    return DashboardAction(
      label: 'Record withdrawal',
      radius: 30,
      color: const Color(0xFFFDECEC),
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: large ? 72 : 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const DashboardIcon('responses/logout', color: AppColors.error),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Record withdrawal',
                  textAlign: TextAlign.center,
                  style: dashboardText(
                    16,
                    color: AppColors.error,
                    weight: FontWeight.w600,
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

/// Figma 07.5: 330 wide, radius 28, alert circle, Cancel + red Withdraw.
Future<bool?> showWithdrawDialog(
  BuildContext context, {
  required String firstName,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  final who = firstName == 'Anonymous'
      ? 'This participant’s'
      : '${firstName.split(' ').first}’s';
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cancel',
    barrierColor: const Color(0xFF0B100E).withValues(alpha: .45),
    transitionDuration: Duration(milliseconds: reduced ? 150 : 250),
    pageBuilder: (context, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDECEC),
                        shape: BoxShape.circle,
                      ),
                      child: const DashboardIcon(
                        'consent/alert',
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text(
                        'Record withdrawal?',
                        style: dashboardText(22, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '$who answers stay in the audit trail but are excluded '
                      'from analysis and exports. This can’t be undone.',
                      style: dashboardText(
                        14,
                        color: AppColors.muted,
                      ).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 40),
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
                          child: _RedButton(
                            label: 'Withdraw',
                            onPressed: () => Navigator.pop(context, true),
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

class _RedButton extends ConsumerWidget {
  const _RedButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final large = ref.watch(largerTouchTargetsProvider);
    return DashboardAction(
      label: label,
      radius: 26,
      color: AppColors.error,
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: large ? 64 : 52),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
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
    );
  }
}
