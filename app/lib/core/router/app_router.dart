import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/preferences/language_accessibility_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/form_builder/form_builder_screen.dart';
import '../../features/form_builder/template_style_screen.dart';
import '../../features/new_consent/drafting_screen.dart';
import '../../features/new_consent/review_draft_screen.dart';
import '../../features/new_consent/upload_proposal_screen.dart';
import '../../features/projects/project_detail_screen.dart';
import '../../features/projects/project_transition.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/shell/shell_page.dart';
import '../../features/splash/splash_screen.dart';
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
                else
                  GoRoute(
                    path: '/${destination.name}',
                    builder: (context, state) {
                      if (destination == ShellDestination.home) {
                        return const DashboardScreen();
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
