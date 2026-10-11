import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../field_capture/done_screen.dart' show showFeedbackPopup;
import '../new_consent/consent_widgets.dart';
import 'settings_data.dart';
import 'settings_widgets.dart';

/// Figma 08.4 Feedback pop-up settings (3:3891). Used by field capture
/// (06.6): the pop-up only shows when it is on and the form count matches.
class FeedbackSettingsScreen extends ConsumerWidget {
  const FeedbackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(feedbackSettingsProvider);
    void update(FeedbackSettings next) =>
        ref.read(feedbackSettingsProvider.notifier).state = next;
    final reduced = reduceMotion(context);

    return SettingsPage(
      title: 'Feedback pop-up',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Never shown to participants under 18.',
            style: dashboardText(
              12,
              color: const Color(0xFF9A5B00),
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ConsentPillButton(
            label: 'Preview pop-up',
            icon: 'consent/eye',
            filled: false,
            onPressed: () => showFeedbackPopup(context, preview: true),
          ),
        ],
      ),
      children: [
        Text(
          'Ask participants how the experience was, right after they '
          'finish. Always optional and never linked to consent answers.',
          style: dashboardText(
            14,
            color: AppColors.muted,
          ).copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
        SettingsCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          children: [
            SettingsToggleRow(
              icon: 'settings/smile',
              title: 'Show feedback pop-up',
              minHeight: 56,
              value: s.enabled,
              onChanged: (v) => update(s.copyWith(enabled: v)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SettingsLabel('How often'),
        const SizedBox(height: 9),
        AnimatedOpacity(
          duration: Duration(milliseconds: reduced ? 0 : 200),
          opacity: s.enabled ? 1 : .45,
          child: IgnorePointer(
            ignoring: !s.enabled,
            child: SettingsCard(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              children: [
                for (final f in FeedbackFrequency.values) ...[
                  if (f != FeedbackFrequency.values.first)
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.line,
                    ),
                  Semantics(
                    selected: s.frequency == f,
                    inMutuallyExclusiveGroup: true,
                    enabled: s.enabled,
                    child: DashboardAction(
                      label: f.label,
                      radius: 12,
                      onPressed: () => update(s.copyWith(frequency: f)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  f.label,
                                  style: dashboardText(
                                    15,
                                    weight: s.frequency == f
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            RadioDot(selected: s.frequency == f),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedOpacity(
          duration: Duration(milliseconds: reduced ? 0 : 200),
          opacity: s.enabled ? 1 : .45,
          child: SettingsCard(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            children: [
              SettingsToggleRow(
                icon: 'mic',
                title: 'Allow voice comments',
                minHeight: 56,
                value: s.voiceComments,
                onChanged: s.enabled
                    ? (v) => update(s.copyWith(voiceComments: v))
                    : null,
              ),
              SettingsToggleRow(
                icon: 'consent/eye',
                title: 'Let participant hide it',
                subtitle: '“Don’t ask me again”',
                minHeight: 56,
                value: s.allowHide,
                onChanged: s.enabled
                    ? (v) => update(s.copyWith(allowHide: v))
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
