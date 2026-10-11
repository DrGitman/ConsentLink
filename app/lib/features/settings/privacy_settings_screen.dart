import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../projects/project_widgets.dart';
import '../responses/export_sheet.dart';
import '../responses/responses_data.dart';
import '../responses/responses_widgets.dart' show StaggerIn;
import 'settings_widgets.dart';

/// Privacy & data (from the Me "Privacy & data" row): how records are
/// protected and kept, downloading everything, and help.
class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(responsesProvider).length;
    void notice(String title, String text) =>
        showProjectNotice(context, title, text);

    return SettingsPage(
      title: 'Privacy & data',
      children: [
        Text(
          'How participant records are protected on this phone and how long '
          'they are kept.',
          style: dashboardText(
            14,
            color: AppColors.muted,
          ).copyWith(height: 1.5),
        ),
        const SizedBox(height: 14),
        StaggerIn(
          index: 0,
          child: SettingsCard(
            children: [
              SettingsRow(
                icon: 'form/lock',
                title: 'On-device encryption',
                subtitle: 'AES-256 · key in secure enclave',
                onTap: () => notice(
                  'On-device encryption',
                  'Records are encrypted before they are saved. The key never '
                      'leaves this phone\'s secure hardware.',
                ),
              ),
              SettingsRow(
                icon: 'settings/history',
                title: 'Keep records for',
                subtitle: '5 years (NUST policy)',
                onTap: () => notice(
                  'Keep records for',
                  'Set by your institution\'s policy: 5 years after the study '
                      'ends, then deleted.',
                ),
              ),
              SettingsRow(
                icon: 'projects/download',
                title: 'Download all my data',
                subtitle: 'ZIP of forms & records',
                onTap: () => showExportSheet(
                  context,
                  subtitle: 'All your forms & records · $records records',
                  count: records,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        StaggerIn(
          index: 1,
          child: SettingsCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            children: [
              SettingsRow(
                icon: 'consent/info',
                title: 'Help & feedback',
                subtitle: 'Report a problem or suggest a feature',
                onTap: () => notice(
                  'Help & feedback',
                  'Email the ConsentLink team at support@consentlink.app or '
                      'ask your supervisor.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
