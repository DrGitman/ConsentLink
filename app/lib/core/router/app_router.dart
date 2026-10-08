import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/preferences/language_accessibility_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/shell_page.dart';
import '../../features/splash/splash_screen.dart';
import '../l10n/app_localizations.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/auth/confirm_email_preview_screen.dart';
import '../../features/auth/password_recovery_preview_screen.dart';
import '../../features/legal/legal_content.dart';
import '../../features/legal/legal_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: const String.fromEnvironment(
      'INITIAL_ROUTE',
      defaultValue: '/splash',
    ),
    routes: [
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          for (final destination in ShellDestination.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/${destination.name}',
                  builder: (context, state) {
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
