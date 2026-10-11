import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_components.dart';
import '../new_consent/consent_widgets.dart';
import '../projects/project_widgets.dart';
import '../responses/responses_widgets.dart' show StaggerIn;
import 'profile_widgets.dart';
import 'settings_data.dart';
import 'settings_widgets.dart';

/// Account (from the Me profile card): photo, sign-in details, ethics
/// clearances, sign out and delete. Sign-in changes need the auth service
/// (not connected), so those rows explain what they will do. Privacy and
/// records live on their own page (privacy_settings_screen.dart).
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message:
          'Records waiting to sync stay encrypted on this phone. You will need '
          'your password or fingerprint to sign in again.',
      confirm: 'Sign out',
      icon: 'responses/logout',
    );
    if (ok == true && context.mounted) context.go('/login');
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'Your account and every record on this phone are deleted. Records '
          'already synced stay with the project for the retention period. '
          'This can’t be undone.',
      confirm: 'Delete',
    );
    if (ok != true || !context.mounted) return;
    await showProjectNotice(
      context,
      'Delete account',
      'Account deletion needs the auth service, which isn\'t connected yet. '
          'Nothing was deleted.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(settingsPreviewProvider);
    final hasPhoto = ref.watch(profilePhotoProvider) != null;
    final email = ref.watch(researcherEmailProvider);
    final (:name, :role, initials: _) = profileIdentity(ref);
    final primary = Theme.of(context).colorScheme.primary;
    void notice(String title, String text) =>
        showProjectNotice(context, title, text);
    void photo() => showProfilePhotoSheet(context, ref);

    return SettingsPage(
      title: 'Account',
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConsentPillButton(
            label: 'Sign out',
            icon: 'responses/logout',
            filled: false,
            height: 56,
            onPressed: () => _signOut(context),
          ),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(140, 48),
              overlayColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () => _delete(context),
            child: Text(
              'Delete account',
              style: dashboardText(
                15,
                color: AppColors.error,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      children: [
        RiseIn(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: hasPhoto
                      ? 'Change profile photo'
                      : 'Add profile photo',
                  child: GestureDetector(
                    onTap: photo,
                    child: SizedBox.square(
                      dimension: 104,
                      child: Stack(
                        children: [
                          const Positioned.fill(
                            child: ExcludeSemantics(
                              child: ProfileAvatar(size: 104),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const DashboardIcon(
                                'settings/camera',
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: dashboardText(20, weight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: dashboardText(13, color: AppColors.subtle),
                ),
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(120, 44),
                    overlayColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  onPressed: photo,
                  child: Text(
                    hasPhoto ? 'Change photo' : 'Add photo',
                    style: dashboardText(
                      15,
                      color: primary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        StaggerIn(
          index: 1,
          child: SettingsCard(
            children: [
              SettingsRow(
                icon: 'navigation/user',
                title: 'Researcher details',
                subtitle: email.isNotEmpty
                    ? email
                    : preview
                    ? 'nshikongo@nust.na'
                    : 'Name, email, faculty, supervisor',
                onTap: () => showResearcherDetailsSheet(context),
              ),
              SettingsRow(
                icon: 'form/lock',
                title: 'Password & fingerprint',
                subtitle: preview ? 'Changed 2 months ago' : 'Not set up',
                onTap: () => notice(
                  'Password & fingerprint',
                  'Password changes and fingerprint unlock come with the auth '
                      'service.',
                ),
              ),
              SettingsRow(
                icon: 'projects/shield',
                title: 'Ethics clearances',
                subtitle: preview ? '2 active' : 'None added',
                onTap: () => notice(
                  'Ethics clearances',
                  preview
                      ? 'NUST HREC 2026-041 (valid to Mar 2027) and NUST HREC '
                            '2025-118 (valid to Dec 2026).'
                      : 'Clearances appear here once you add them to a project.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
