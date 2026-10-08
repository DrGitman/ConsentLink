import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/auth/password_recovery_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('recovery validates email, preserves it and returns to login', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/recovery'),
              child: const Text('Open recovery'),
            ),
          ),
        ),
        GoRoute(
          path: '/recovery',
          builder: (context, state) => const PasswordRecoveryPreviewScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text('Open recovery'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preview reset request'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Check your inbox'), findsNothing);

    await tester.enterText(find.byType(TextField), 'tester@example.com');
    await tester.tap(find.text('Preview reset request'));
    await tester.pumpAndSettle();

    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.text('tester@example.com'), findsOneWidget);

    await tester.tap(find.text('Change email'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'tester@example.com',
    );

    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();

    expect(find.text('Open recovery'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
