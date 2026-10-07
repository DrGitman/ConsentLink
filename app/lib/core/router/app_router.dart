import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/preferences/language_accessibility_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/shell/shell_page.dart';
import '../../features/splash/splash_screen.dart';
import '../l10n/app_localizations.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: const String.fromEnvironment(
      'INITIAL_ROUTE',
      defaultValue: '/splash',
    ),
    routes: [
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
