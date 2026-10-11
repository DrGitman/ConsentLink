import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../projects/project_widgets.dart';
import 'consent_draft_data.dart';
import 'consent_widgets.dart';
import 'review_draft_screen.dart';

/// Figma Screen Artboards 04.4 "Why did AI write this?" bottom sheet.
/// Rises with a slight overshoot over a fading scrim (Animations
/// "Navigation — sheet & dialog"); 150 ms with Reduce motion.
Future<void> showWhySheet(
  BuildContext context, {
  required String sectionKey,
  required VoidCallback onApprove,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  barrierColor: Colors.black.withValues(alpha: .45),
  sheetAnimationStyle: sheetMotion(context),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (context) => _WhySheet(sectionKey: sectionKey, onApprove: onApprove),
);

class _WhySheet extends ConsumerWidget {
  const _WhySheet({required this.sectionKey, required this.onApprove});
  final String sectionKey;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref
        .watch(consentDraftProvider)
        .sections
        .firstWhere((s) => s.key == sectionKey);
    final primary = Theme.of(context).colorScheme.primary;
    final approved = section.done;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Why this text?',
                  style: dashboardText(22, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.title,
                style: dashboardText(14, color: AppColors.subtle),
              ),
              const SizedBox(height: 16),
              _Panel(
                fill: AppColors.canvas,
                children: [
                  Text(
                    section.sourcePages.isEmpty
                        ? section.sourceLabel.toUpperCase()
                        : 'FROM YOUR PROPOSAL · p.${section.sourcePages.join(', ')}',
                    style: dashboardText(
                      11,
                      color: AppColors.subtle,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.sourceQuote ??
                        'No quote: this text was not taken from your proposal.',
                    style: dashboardText(14).copyWith(height: 1.45),
                  ),
                  if (section.sourceQuote != null) ...[
                    const SizedBox(height: 12),
                    _OpenPage(pages: section.sourcePages, primary: primary),
                  ],
                ],
              ),
              if (section.changes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Panel(
                  fill: const Color(0xFFEDEEFF),
                  children: [
                    Text(
                      'WHAT THE AI CHANGED',
                      style: dashboardText(
                        11,
                        color: const Color(0xFF4B4FD8),
                        weight: FontWeight.w700,
                      ),
                    ),
                    for (final change in section.changes) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashboardIcon(
                            'projects/check',
                            size: 18,
                            color: Color(0xFF4B4FD8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              change,
                              style: dashboardText(
                                13,
                                color: const Color(0xFF2E318F),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confidence: ${section.confidenceLabel}',
                      style: dashboardText(14, weight: FontWeight.w600),
                    ),
                    ...[
                      const SizedBox(height: 4),
                      Text(
                        _confidenceNote(section),
                        style: dashboardText(12, color: AppColors.subtle),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ConsentPillButton(
                      icon: 'sparkle',
                      label: 'Simplify',
                      filled: false,
                      height: 52,
                      onPressed: () => showProjectNotice(
                        context,
                        'Simplify',
                        'Rewording runs on the on-device AI, which is not connected yet.',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ConsentPillButton(
                      icon: 'projects/check',
                      label: approved ? 'Approved' : 'Approve',
                      height: 52,
                      onPressed: approved
                          ? null
                          : () {
                              Navigator.pop(context);
                              onApprove();
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  section.log ??
                      'Your approval is logged with your name and the time.',
                  textAlign: TextAlign.center,
                  style: dashboardText(
                    12,
                    color: AppColors.subtle,
                    weight: FontWeight.w500,
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

class _Panel extends StatelessWidget {
  const _Panel({required this.fill, required this.children});
  final Color fill;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _OpenPage extends StatelessWidget {
  const _OpenPage({required this.pages, required this.primary});
  final List<int> pages;
  final Color primary;
  @override
  Widget build(BuildContext context) {
    final page = pages.isEmpty ? null : pages.first;
    final label = page == null ? 'Open proposal' : 'Open page $page';
    // 24 dp badge inside a 48 dp touch target.
    return SizedBox(
      height: 48,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DashboardAction(
          label: label,
          radius: 12,
          onPressed: () => showProjectNotice(
            context,
            label,
            'The document viewer will be connected with file upload.',
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DashboardIcon('consent/file', size: 15, color: primary),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: dashboardText(
                    12,
                    color: primary,
                    weight: FontWeight.w600,
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

/// Explains the confidence level (not part of the AI output, derived here).
String _confidenceNote(DraftSection section) {
  final base = section.sourcePages.isEmpty
      ? 'Not in your proposal. Check it carefully before approving.'
      : switch (section.confidence) {
          'high' => 'Matches source closely.',
          'medium' =>
            'Partly matches the source. Check it against your proposal.',
          _ => 'Weak match with the source. Rewrite or check it carefully.',
        };
  return '$base Translation to Otjiherero needs a human reviewer.';
}
