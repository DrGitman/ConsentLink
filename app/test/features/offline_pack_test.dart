import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/offline/offline_pack_screen.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('unavailable packs stay pending and continuing opens Home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/offline-pack',
      routes: [
        GoRoute(
          path: '/offline-pack',
          builder: (_, _) => const OfflinePackScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home destination')),
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
    await tester.pumpAndSettle();

    expect(find.text('Not downloaded'), findsOneWidget);
    expect(find.text('Ready'), findsNothing);
    expect(find.textContaining('64%'), findsNothing);
    // ListView builds children as they approach the viewport. Reach the
    // additional languages as a user would before checking their content.
    await tester.scrollUntilVisible(
      find.textContaining('Oshiwambo'),
      150,
      scrollable: find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Oshiwambo'), findsOneWidget);
    await tester.tap(find.text('Continue without pack'));
    await tester.pumpAndSettle();
    expect(find.text('Home destination'), findsOneWidget);
  });

  testWidgets('large text and targets fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [largerTouchTargetsProvider.overrideWith((ref) => true)],
        child: MaterialApp(
          theme: AppTheme.light(largerTouchTargets: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const OfflinePackScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Continue without pack'), findsOneWidget);
  });
}
