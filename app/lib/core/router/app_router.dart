import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/preferences/language_accessibility_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/field_capture/answer_screen.dart';
import '../../features/field_capture/choices_screen.dart';
import '../../features/field_capture/done_screen.dart';
import '../../features/field_capture/hand_over_screen.dart';
import '../../features/field_capture/read_consent_screen.dart';
import '../../features/field_capture/sign_screen.dart';
import '../../features/minors/age_check_screen.dart';
import '../../features/minors/assent_screen.dart';
import '../../features/minors/assent_stopped_screen.dart';
import '../../features/minors/guardian_consent_screen.dart';
import '../../features/minors/guardian_details_screen.dart';
import '../../features/minors/minors_settings_screen.dart';
import '../../features/form_builder/form_builder_screen.dart';
import '../../features/form_builder/template_style_screen.dart';
import '../../features/new_consent/drafting_screen.dart';
import '../../features/new_consent/review_draft_screen.dart';
import '../../features/new_consent/upload_proposal_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/responses/consent_record_screen.dart';
import '../../features/responses/insights_screen.dart';
import '../../features/responses/responses_screen.dart';
import '../../features/projects/project_transition.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/shell/shell_page.dart';
import '../../features/settings/accessibility_settings_screen.dart';
import '../../features/settings/account_settings_screen.dart';
import '../../features/settings/feedback_settings_screen.dart';
import '../../features/settings/language_settings_screen.dart';
import '../../features/settings/me_screen.dart';
import '../../features/settings/privacy_settings_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/templates/clip_logo_screen.dart';
import '../../features/templates/describe_template_screen.dart';
import '../../features/templates/read_template_screen.dart';
import '../../features/templates/template_detail_screen.dart';
import '../../features/templates/template_library_screen.dart';
import '../l10n/app_localizations.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/auth/confirm_email_preview_screen.dart';
import '../../features/auth/password_recovery_preview_screen.dart';
import '../../features/institution/institution_screen.dart';
import '../../features/institution/researcher_details_screen.dart';
import '../../features/offline/offline_pack_screen.dart';
import '../../features/legal/legal_content.dart';
import '../../features/legal/legal_screen.dart';
import '../widgets/dictation_sheet.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: const String.fromEnvironment(
      'INITIAL_ROUTE',
      defaultValue: '/splash',
    ),
    routes: [
      GoRoute(
        path: '/offline-pack',
        builder: (context, state) => const OfflinePackScreen(),
      ),
      GoRoute(
        path: '/institution',
        builder: (context, state) => const InstitutionScreen(),
      ),
      GoRoute(
        path: '/researcher-details',
        builder: (context, state) => const ResearcherDetailsScreen(),
      ),
      for (final document in LegalDocument.values)
        GoRoute(
          path: document.route,
          pageBuilder: (context, state) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);

            return CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              reverseTransitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: LegalScreen(document: document),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (MediaQuery.disableAnimationsOf(context)) return child;

                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                              reverseCurve: Curves.easeInOut,
                            ),
                          ),
                      child: child,
                    );
                  },
            );
          },
        ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) {
          final reduceMotion = MediaQuery.disableAnimationsOf(context);

          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            reverseTransitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            child: const LoginScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  if (MediaQuery.disableAnimationsOf(context)) return child;

                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                            reverseCurve: Curves.easeInOut,
                          ),
                        ),
                    child: child,
                  );
                },
          );
        },
      ),

      GoRoute(
        path: '/sign-up',
        pageBuilder: (context, state) {
          final reduceMotion = MediaQuery.disableAnimationsOf(context);

          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            reverseTransitionDuration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 350),
            child: const SignUpScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  if (MediaQuery.disableAnimationsOf(context)) return child;

                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                            reverseCurve: Curves.easeInOut,
                          ),
                        ),
                    child: child,
                  );
                },
          );
        },
      ),
      if (const bool.fromEnvironment('AUTH_PREVIEW'))
        GoRoute(
          path: '/confirm-email-preview',
          pageBuilder: (context, state) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            final email = state.extra is String
                ? state.extra! as String
                : 'tester@example.com';

            return CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              reverseTransitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: ConfirmEmailPreviewScreen(email: email),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (MediaQuery.disableAnimationsOf(context)) return child;

                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                              reverseCurve: Curves.easeInOut,
                            ),
                          ),
                      child: child,
                    );
                  },
            );
          },
        ),
      if (const bool.fromEnvironment('AUTH_PREVIEW'))
        GoRoute(
          path: '/password-recovery-preview',
          pageBuilder: (context, state) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);

            return CustomTransitionPage<void>(
              key: state.pageKey,
              transitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              reverseTransitionDuration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 350),
              child: const PasswordRecoveryPreviewScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (MediaQuery.disableAnimationsOf(context)) return child;

                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOut,
                              reverseCurve: Curves.easeInOut,
                            ),
                          ),
                      child: child,
                    );
                  },
            );
          },
        ),
      if (const bool.fromEnvironment('AUTH_PREVIEW'))
        GoRoute(
          path: '/dictation-check',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Voice input check')),
            body: Center(
              child: FilledButton.icon(
                icon: const Icon(Icons.mic_none),
                label: const Text('Test voice input'),
                onPressed: () async {
                  final text = await showDictationSheet(
                    context,
                    fieldLabel: 'Title & name',
                  );

                  if (!context.mounted || text == null) return;

                  await showDialog<void>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Text received'),
                      content: Text(text),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      GoRoute(
        path: '/preferences',
        builder: (context, state) => const LanguageAccessibilityScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          return OnboardingScreen(onComplete: () => context.go('/preferences'));
        },
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      // New consent (Figma 04.1–04.4): full screen, outside the tab shell.
      GoRoute(
        path: '/new-consent',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: const UploadProposalScreen(),
        ),
        routes: [
          GoRoute(
            path: 'drafting',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const DraftingScreen(),
            ),
          ),
          GoRoute(
            path: 'review',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ReviewDraftScreen(),
            ),
          ),
          GoRoute(
            path: 'form',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const FormBuilderScreen(),
            ),
          ),
          GoRoute(
            path: 'template',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const TemplateStyleScreen(),
            ),
          ),
        ],
      ),
      // Field capture (Figma 06.1–06.6): full screen, outside the tab shell.
      GoRoute(
        path: '/field-capture',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: HandOverScreen(
            projectId: state.uri.queryParameters['project'],
          ),
        ),
        routes: [
          GoRoute(
            path: 'read',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ReadConsentScreen(),
            ),
          ),
          GoRoute(
            path: 'answer',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const AnswerScreen(),
            ),
          ),
          GoRoute(
            path: 'choices',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ChoicesScreen(),
            ),
          ),
          GoRoute(
            path: 'sign',
            pageBuilder: (context, state) =>
                projectPushPage(key: state.pageKey, child: const SignScreen()),
          ),
          GoRoute(
            path: 'done',
            pageBuilder: (context, state) =>
                projectPushPage(key: state.pageKey, child: const DoneScreen()),
          ),
          // Minors (Figma 10.2–10.7): age check, guardian, assent, stop.
          for (final (path, page) in <(String, Widget)>[
            ('age', const AgeCheckScreen()),
            ('guardian', const GuardianDetailsScreen()),
            ('guardian-consent', const GuardianConsentScreen()),
            ('assent', const AssentScreen()),
            ('stopped', const AssentStoppedScreen()),
          ])
            GoRoute(
              path: path,
              pageBuilder: (context, state) =>
                  projectPushPage(key: state.pageKey, child: page),
            ),
        ],
      ),
      // Project setting — includes minors (Figma 10.1), full screen.
      GoRoute(
        path: '/participants/:id',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: MinorsSettingsScreen(projectId: state.pathParameters['id']!),
        ),
      ),
      // Consent record (Figma 07.2 / 07.5): full screen, outside the tab shell.
      GoRoute(
        path: '/responses/:code',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: ConsentRecordScreen(code: state.pathParameters['code']!),
        ),
      ),
      // Template Studio (Figma 05.1–05.6): full screen, outside the tab shell.
      GoRoute(
        path: '/templates',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: const TemplateLibraryScreen(),
        ),
        routes: [
          GoRoute(
            path: 'read',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ReadTemplateScreen(),
            ),
          ),
          GoRoute(
            path: 'clip',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ClipLogoScreen(),
            ),
          ),
          GoRoute(
            path: 'describe',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const DescribeTemplateScreen(),
            ),
          ),
          GoRoute(
            path: 'view/:id',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: TemplateDetailScreen(id: state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      // Settings (Figma 08.2–08.5, Account and Privacy split from 08.5): full screen, opened from the Me tab.
      for (final (path, page) in <(String, Widget)>[
        ('accessibility', const AccessibilitySettingsScreen()),
        ('languages', const LanguageSettingsScreen()),
        ('feedback', const FeedbackSettingsScreen()),
        ('account', const AccountSettingsScreen()),
        ('privacy', const PrivacySettingsScreen()),
      ])
        GoRoute(
          path: '/settings/$path',
          pageBuilder: (context, state) =>
              projectPushPage(key: state.pageKey, child: page),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          for (final destination in ShellDestination.values)
            StatefulShellBranch(
              routes: [
                if (destination == ShellDestination.projects)
                  GoRoute(
                    path: '/projects',
                    pageBuilder: (context, state) => projectPushPage(
                      key: state.pageKey,
                      child: const ProjectsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: ':id',
                        pageBuilder: (context, state) => projectPushPage(
                          key: state.pageKey,
                          child: ProjectDetailScreen(
                            projectId: state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (destination == ShellDestination.insights)
                  // Insights (07.3) and Responses (07.1).
                  GoRoute(
                    path: '/insights',
                    pageBuilder: (context, state) => projectPushPage(
                      key: state.pageKey,
                      child: const InsightsScreen(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'responses',
                        pageBuilder: (context, state) => projectPushPage(
                          key: state.pageKey,
                          child: const ResponsesScreen(),
                        ),
                      ),
                    ],
                  )
                else
                  GoRoute(
                    path: '/${destination.name}',
                    builder: (context, state) {
                      if (destination == ShellDestination.home) {
                        return const DashboardScreen();
                      }
                      if (destination == ShellDestination.me) {
                        return const MeScreen();
                      }
                      return ShellPage(destination: destination);
                    },
                  ),
              ],
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      final strings = AppLocalizations.of(context);

      return Scaffold(
        appBar: AppBar(title: Text(strings.routeErrorTitle)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.routeErrorDescription),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: Text(strings.returnHome),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});
