import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:consentlink/features/projects/project_widgets.dart';
import 'package:consentlink/features/responses/consent_record_screen.dart';
import 'package:consentlink/features/responses/insights_screen.dart';
import 'package:consentlink/features/responses/responses_data.dart';
import 'package:consentlink/features/responses/responses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpResponses(
  WidgetTester tester, {
  String initial = '/insights',
  bool preview = true,
  bool large = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/insights',
        pageBuilder: (context, state) =>
            projectPushPage(key: state.pageKey, child: const InsightsScreen()),
        routes: [
          GoRoute(
            path: 'responses',
            pageBuilder: (context, state) => projectPushPage(
              key: state.pageKey,
              child: const ResponsesScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/responses/:code',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: ConsentRecordScreen(code: state.pathParameters['code']!),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      insightsPreviewProvider.overrideWithValue(preview),
      largerTouchTargetsProvider.overrideWith((ref) => large),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            backgroundColor: AppColors.canvas,
            body: SafeArea(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void expectNoException(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    fail(error is FlutterError ? error.toStringDeep() : '$error');
  }
}

Finder circleButton(String label) =>
    find.byWidgetPredicate((w) => w is ProjectCircleButton && w.label == label);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets the 3 s toast leave so no timer is pending.
Future<void> clearToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('normal mode shows no sample data', (tester) async {
    await pumpResponses(tester, preview: false);
    expect(find.text('No insights yet'), findsOneWidget);
    expect(find.text('64'), findsNothing);
    await pumpResponses(tester, preview: false, initial: '/insights/responses');
    expect(find.text('No responses yet'), findsOneWidget);
    expect(find.text('All 0'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('07.1 lists, filters and searches responses', (tester) async {
    await pumpResponses(tester, initial: '/insights/responses');
    expect(find.text('All 69'), findsOneWidget);
    expect(find.text('Agreed 64'), findsOneWidget);
    expect(find.text('Declined 3'), findsOneWidget);
    expect(find.text('Withdrew 2'), findsOneWidget);
    expect(find.text('Kaera T.  ·  P-065'), findsOneWidget);
    expect(find.text('Today 10:42 · Otjiherero · signed'), findsOneWidget);
    expect(find.byType(ResponseCard), findsNWidgets(69));

    await tapVisible(tester, find.text('Declined 3'));
    expect(find.byType(ResponseCard), findsNWidgets(3));

    await tapVisible(tester, find.text('All 69'));
    await tester.tap(circleButton('Search responses'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'p-063');
    await tester.pumpAndSettle();
    expect(find.byType(ResponseCard), findsOneWidget);
    expect(find.text('Uaundja K.  ·  P-063'), findsOneWidget);

    await tester.tap(circleButton('Close search'));
    await tester.pumpAndSettle();
    expect(find.byType(ResponseCard), findsNWidgets(69));
    expectNoException(tester);
  });

  testWidgets('07.1 sort & filter sheet: only waiting to sync', (tester) async {
    await pumpResponses(tester, initial: '/insights/responses');
    await tester.tap(circleButton('Sort and filter'));
    await tester.pumpAndSettle();
    expect(find.text('Sort & filter'), findsOneWidget);
    await tester.tap(find.text('Only waiting to sync'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(195, 60));
    await tester.pumpAndSettle();
    expect(find.byType(ResponseCard), findsNWidgets(3));
    expect(circleButton('Sort and filter, on'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('07.2 shows the record; 07.5 records a withdrawal', (
    tester,
  ) async {
    final container = await pumpResponses(tester, initial: '/responses/P-065');
    expect(find.text('P-065 · Kaera T.'), findsOneWidget);
    expect(find.textContaining('Agreed · '), findsOneWidget);
    expect(find.text('Take part'), findsOneWidget);
    expect(find.text('Quote me'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
    expect(find.text('J. Kavari (interpreter)'), findsOneWidget);
    expect(find.text('Synced to NUST project storage'), findsOneWidget);

    await tester.tap(find.text('Record withdrawal'));
    await tester.pumpAndSettle();
    expect(find.text('Record withdrawal?'), findsOneWidget);
    expect(find.textContaining('Kaera’s answers stay'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      container.read(responsesProvider).first.status,
      ResponseStatus.agreed,
    );

    await tester.tap(find.text('Record withdrawal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(
      container.read(responsesProvider).first.status,
      ResponseStatus.withdrew,
    );
    expect(find.textContaining('Withdrew · '), findsOneWidget);
    expect(find.text('Record withdrawal'), findsNothing);
    expect(find.text('Withdrawal recorded'), findsOneWidget);
    expect(
      find.text('Withdrawal recorded · excluded from analysis'),
      findsOneWidget,
    );
    await clearToast(tester);
    expectNoException(tester);
  });

  testWidgets('07.2 declined record has no signature or withdraw', (
    tester,
  ) async {
    await pumpResponses(tester, initial: '/responses/P-063');
    expect(
      find.text('Declined before signing. No signature was taken.'),
      findsOneWidget,
    );
    expect(find.text('Record withdrawal'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('07.3 insights: goal, KPIs, periods, opens responses', (
    tester,
  ) async {
    await pumpResponses(tester);
    expect(find.text('64'), findsOneWidget);
    expect(find.text('/ 80'), findsOneWidget);
    expect(find.text('On track'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(find.text('6.2 min'), findsOneWidget);
    expect(find.text('Sep 4'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.text('97%'), findsOneWidget);
    expect(find.text('Sep 28'), findsOneWidget);

    expect(find.text('69 records · 3 waiting to sync'), findsOneWidget);
    await tapVisible(tester, find.text('View all responses'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('page-title-responses')), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('07.4 export sheet: formats, options, logged export', (
    tester,
  ) async {
    final container = await pumpResponses(tester);
    await tester.tap(circleButton('Export responses'));
    await tester.pumpAndSettle();
    expect(find.text('Water access & health · 69 records'), findsOneWidget);
    expect(find.text('Export 69 PDFs (.zip)'), findsOneWidget);

    await tester.tap(find.text('CSV'));
    await tester.pumpAndSettle();
    expect(find.text('Export 69 rows (.csv)'), findsOneWidget);
    await tester.tap(find.text('Password-protect file'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Export 69 rows (.csv)'));
    // tapVisible settles; the spinner is replaced when the sheet closes.
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Export'), findsNothing);
    expect(find.text('Export ready · 69 rows (.csv)'), findsOneWidget);
    expect(container.read(exportLogProvider), hasLength(1));
    await clearToast(tester);
    expectNoException(tester);
  });

  testWidgets('every screen fits 200% text and larger targets', (tester) async {
    for (final route in [
      '/insights',
      '/insights/responses',
      '/responses/P-065',
      '/responses/P-063',
    ]) {
      final details = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => details.add(d.toString());
      await pumpResponses(tester, initial: route, textScale: 2, large: true);
      FlutterError.onError = previous;
      expect(details, isEmpty, reason: 'Layout error on $route');
    }
    await tester.tap(circleButton('Export this record'));
    await tester.pumpAndSettle();
    expect(find.text('Export 1 PDF'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('reduce motion: insights settle without animation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpResponses(tester);
    await tester.pump();
    expect(find.text('64'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expectNoException(tester);
  });
}
