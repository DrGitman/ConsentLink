import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_back_button.dart';
import '../../core/widgets/app_toast.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../responses/consent_record_screen.dart'
    show WithdrawButton, showWithdrawDialog;
import '../responses/export_sheet.dart';
import '../responses/responses_data.dart';
import '../responses/responses_widgets.dart' show showOverlayToast;
import 'minors_data.dart';

/// Figma 10.8 Minor consent record (3:7196): guardian consent, the young
/// person's own assent, the researcher's authority check and the reminder
/// to ask for their own consent at 18.
class MinorRecordScreen extends ConsumerWidget {
  const MinorRecordScreen({super.key, required this.code});
  final String code;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/insights/responses');
    }
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final ok = await showWithdrawDialog(context, firstName: 'Anonymous');
    if (ok != true || !context.mounted) return;
    final now = DateTime.now();
    ref.read(minorRecordsProvider.notifier).withdraw(code, now);
    ref.read(responsesProvider.notifier).withdraw(code, now);
    showOverlayToast(
      context,
      kind: AppToastKind.info,
      title: 'Withdrawal recorded',
      subtitle: '$code is excluded from analysis and exports',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref
        .watch(minorRecordsProvider)
        .where((e) => e.code == code)
        .firstOrNull;
    final primary = Theme.of(context).colorScheme.primary;
    final tint = institutionTint(ref, context);
    if (r == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 20, 24),
            child: Column(
              children: [
                ConsentTopBar(
                  leading: AppBackButton(onPressed: () => _back(context)),
                  title: code,
                ),
              ],
            ),
          ),
        ),
      );
    }
    final withdrawn = r.withdrawnAt != null;
    String date(DateTime d) => '${d.day} ${shortMonths[d.month - 1]} ${d.year}';
    final choiceLine = [
      for (final (key, _, short) in guardianChoices)
        '$short: ${r.choices[key] == true ? 'Yes' : 'No'}',
    ].join(' · ');

    Widget card(Widget child, {Color color = Colors.white}) => RiseIn(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: child,
      ),
    );
    final label = dashboardText(
      13,
      color: AppColors.subtle,
      weight: FontWeight.w500,
    );

    return Scaffold(
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
                          title: '${r.code} · age ${r.age}',
                          trailing: ProjectCircleButton(
                            icon: 'projects/download',
                            label: 'Export this record',
                            onPressed: () => showExportSheet(
                              context,
                              subtitle: '${r.code} · 1 record',
                              count: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: Duration(
                            milliseconds: reduceMotion(context) ? 150 : 250,
                          ),
                          child: withdrawn
                              ? ProjectBadge(
                                  key: const ValueKey('withdrawn'),
                                  label: 'Withdrawn · ${date(r.withdrawnAt!)}',
                                  icon: 'responses/logout',
                                  fill: const Color(0xFFFDECEC),
                                  ink: AppColors.error,
                                )
                              : ProjectBadge(
                                  key: const ValueKey('complete'),
                                  label:
                                      'Consent + assent complete · ${date(r.at)}',
                                  icon: 'projects/check',
                                  fill: AppColors.brand50,
                                  ink: AppColors.brandDark,
                                ),
                        ),
                        const SizedBox(height: 12),
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Guardian consent', style: label),
                              const SizedBox(height: 4),
                              Text(
                                '${r.guardianName} · ${r.relationship.label}',
                                style: dashboardText(
                                  16,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                choiceLine,
                                style: dashboardText(
                                  13,
                                  color: AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const ProjectBadge(
                                label: 'Signed',
                                icon: 'form/sign',
                                fill: AppColors.brand50,
                                ink: AppColors.brandDark,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Young person’s assent', style: label),
                              const SizedBox(height: 6),
                              Text(
                                'Said “Yes” after listening '
                                '(${r.band.label} form)',
                                style: dashboardText(
                                  15,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ProjectBadge(
                                label: 'Recorded by ${r.recordedBy}',
                                icon: 'mic',
                                fill: tint,
                                ink: primary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        card(
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DashboardIcon('projects/shield', color: primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Guardian authority confirmed',
                                      style: dashboardText(
                                        14,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.gatekeeper
                                          ? 'by researcher · school permission on file'
                                          : 'by researcher',
                                      style: dashboardText(
                                        12,
                                        color: AppColors.subtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        card(
                          color: const Color(0xFFFFF4E0),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: DashboardIcon(
                                  'form/calendar',
                                  color: Color(0xFF7A4700),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Re-consent at 18',
                                      style: dashboardText(
                                        15,
                                        color: const Color(0xFF7A4700),
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'If the study is still running on '
                                      '${r.reconsentOn.day} '
                                      '${shortMonths[r.reconsentOn.month - 1]} '
                                      '${r.reconsentOn.year}, the app reminds '
                                      'you to ask ${r.code} for their own '
                                      'consent.',
                                      style: dashboardText(
                                        12,
                                        color: const Color(0xFF7A4700),
                                      ).copyWith(height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!withdrawn)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: WithdrawButton(
                      onPressed: () => _withdraw(context, ref),
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
