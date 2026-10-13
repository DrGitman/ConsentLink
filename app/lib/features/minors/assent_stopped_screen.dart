import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/capture_widgets.dart';
import '../field_capture/field_capture_data.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';

/// Figma 10.7 Child said no — stop (3:7170). A kind ending (Peak-End): the
/// child's "No" overrides the guardian. Can't go back into the form.
class AssentStoppedScreen extends ConsumerWidget {
  const AssentStoppedScreen({super.key});

  void _handBack(BuildContext context, WidgetRef ref) {
    final id = ref.read(captureSessionProvider).projectId;
    context.go(id == null ? '/home' : '/projects/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    Widget bullet(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2, right: 8),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: dashboardText(
                13,
                color: AppColors.muted,
              ).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: false,
      child: CaptureScaffold(
        participant: false,
        scaleFooter: false,
        padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
        footer: ConsentPillButton(
          label: 'Back to researcher',
          onPressed: () => _handBack(context, ref),
        ),
        children: [
          Center(
            child: PopIn(
              child: Container(
                width: 100,
                height: 100,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: institutionTint(ref, context),
                  shape: BoxShape.circle,
                ),
                child: DashboardIcon('capture/hand', color: primary, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 30),
          RiseIn(
            child: Column(
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    'Thank you for telling us',
                    textAlign: TextAlign.center,
                    style: dashboardText(26, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'That’s completely OK. You won’t take part, and nothing '
                    'bad will happen.',
                    textAlign: TextAlign.center,
                    style: dashboardText(
                      17,
                      color: AppColors.muted,
                    ).copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 74),
          // Researcher-facing: keeps the phone's own text size.
          MediaQuery(
            data: MediaQuery.of(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'For the researcher',
                    style: dashboardText(
                      14,
                      color: primary,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  bullet(
                    'Participation stopped. Guardian consent is overridden '
                    'by the child’s “No”.',
                  ),
                  bullet(
                    'No answers or recordings are kept; only “declined '
                    '(assent)” is logged.',
                  ),
                  bullet('Feedback pop-up is never shown to minors.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
