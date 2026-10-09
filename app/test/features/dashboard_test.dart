import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/dashboard/dashboard_components.dart';
import 'package:consentlink/features/dashboard/dashboard_screen.dart';
import 'package:consentlink/features/dashboard/dashboard_loading.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpDashboard(
  WidgetTester tester, {
  bool preview = false,
  bool large = false,
  bool loading = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardPreviewProvider.overrideWithValue(preview),
        dashboardLoadingPreviewProvider.overrideWithValue(loading),
        largerTouchTargetsProvider.overrideWith((ref) => large),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: SafeArea(child: DashboardScreen())),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'normal dashboard never presents the Figma records as real data',
    (tester) async {
      await pumpDashboard(tester);
      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.text('Sync not connected'), findsOneWidget);
      expect(find.text('128'), findsNothing);
      expect(find.text('Water access & health in Opuwo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preview explains sample data and renders on a narrow screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpDashboard(tester, preview: true, large: true);
      await tester.pumpAndSettle();
      expect(find.text('Dashboard design preview'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('128'), findsOneWidget);
      // Cards are wider than the screen here, so the row must scroll first.
      await tester.ensureVisible(find.text('Templates'));
      await tester.pumpAndSettle();
      final row = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const PageStorageKey('dashboard-quick-actions')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(row.position.pixels, greaterThan(0));
      await tester.tap(find.text('Templates'));
      await tester.pumpAndSettle();
      expect(
        find.text('Templates will be connected in its feature task.'),
        findsOneWidget,
      );
      // Let preview sync timers finish.
      await tester.pump(const Duration(seconds: 4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick-action cards share the tallest card height', (
    tester,
  ) async {
    // Preview only: sample data makes "from your proposal" wrap to two lines.
    await pumpDashboard(tester, preview: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final heights = [
      for (final label in ['New consent', 'Field capture', 'Templates'])
        tester
            .getSize(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(DashboardAction),
              ),
            )
            .height,
    ];
    expect(heights.toSet(), hasLength(1));
    expect(heights.first, greaterThanOrEqualTo(124));
    // Let preview sync timers finish.
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('notice dialog opens and closes with reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpDashboard(tester, preview: true);
    await tester.pumpAndSettle();
    expect(find.text('Dashboard design preview'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard design preview'), findsNothing);
    await tester.ensureVisible(find.text('Templates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Templates'));
    await tester.pumpAndSettle();
    expect(
      find.text('Templates will be connected in its feature task.'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text('Templates will be connected in its feature task.'),
      findsNothing,
    );
    // Let preview sync timers finish.
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync bar follows the Figma offline to synced sequence', (
    tester,
  ) async {
    await pumpDashboard(tester, preview: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Offline · 3 consents waiting to sync'), findsOneWidget);
    await tester.tap(find.text('Offline · 3 consents waiting to sync'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Back online · syncing 3…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('All synced · just now'), findsOneWidget);
    // The fold starts on the frame after the 1.2 s timer, then takes 300 ms.
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('All synced · just now'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Offline · 3 consents waiting to sync'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync bar does not spin with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpDashboard(tester, preview: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline · 3 consents waiting to sync'));
    await tester.pump(const Duration(milliseconds: 300));
    // Let the 150 ms reduced-motion fades finish; a spinning icon would
    // never settle and fail here.
    await tester.pumpAndSettle();
    expect(find.text('Back online · syncing 3…'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading shimmer is static with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpDashboard(tester, preview: true, loading: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardLoading), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    // Let preview sync timers finish.
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
