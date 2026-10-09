import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/dashboard/dashboard_components.dart';
import 'package:consentlink/features/new_consent/consent_draft_data.dart';
import 'package:consentlink/features/new_consent/drafting_screen.dart';
import 'package:consentlink/features/new_consent/review_draft_screen.dart';
import 'package:consentlink/features/new_consent/upload_proposal_screen.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpNewConsent(
  WidgetTester tester, {
  bool preview = true,
  bool large = false,
  String initial = '/new-consent',
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('Home placeholder'),
      ),
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
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  // Figma phone frame, unless the test sets its own size.
  if (tester.view.physicalSize == const Size(2400, 1800)) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final container = ProviderContainer(
    overrides: [
      newConsentPreviewProvider.overrideWithValue(preview),
      largerTouchTargetsProvider.overrideWith((ref) => large),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await settle(tester);
  return container;
}

/// The upload icon loops while its screen is visible, so pumpAndSettle never
/// finishes there. Pump past every finite transition (all well under 1 s).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pickSample(WidgetTester tester, String name) async {
  await tester.tap(find.text('Tap to upload or take a photo'));
  await settle(tester);
  await tester.tap(find.text(name));
  // Upload 0.9 s + scan 0.9 s run on timers.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 2500));
  await settle(tester);
}

// Tap the inner TextButton: DashboardAction's AnimatedScale (RenderTransform)
// never appears in hit-test results, so tapping it directly logs a warning.
final dismissButton = find.descendant(
  of: find.byWidgetPredicate(
    (w) => w is DashboardAction && w.label == 'Dismiss',
  ),
  matching: find.byType(TextButton),
);

/// Lets the 5 s "approved" toast time out so it can't cover buttons.
Future<void> clearSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Shows the full layout error (which widget overflowed) instead of a summary.
void expectNoException(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    fail(error is FlutterError ? error.toStringDeep() : '$error');
  }
}

void main() {
  testWidgets('normal mode uploads nothing and keeps Analyse disabled', (
    tester,
  ) async {
    await pumpNewConsent(tester, preview: false);
    expect(
      find.text('Start from your research paper or proposal'),
      findsOneWidget,
    );
    await tester.tap(find.text('Tap to upload or take a photo'));
    await settle(tester);
    expect(find.textContaining('Nothing has been uploaded'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await settle(tester);
    await tester.tap(find.text('Analyse with on-device AI'));
    await settle(tester);
    expect(find.text('Drafting your consent form'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview upload scans the PDF, blocks the exe, enables Analyse', (
    tester,
  ) async {
    await pumpNewConsent(tester);
    await pickSample(tester, 'Opuwo_water_proposal_v3.pdf');
    expect(find.text('Scanned · safe · 18 pages'), findsOneWidget);
    await pickSample(tester, 'survey_tool.exe');
    expect(find.text('survey_tool.exe was blocked'), findsOneWidget);
    await tester.tap(dismissButton);
    await settle(tester);
    expect(find.text('survey_tool.exe was blocked'), findsNothing);
    await tester.tap(find.text('Analyse with on-device AI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Drafting your consent form'), findsOneWidget);
    // 6 steps × 0.7 s, then the review opens.
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Review draft'), findsOneWidget);
    expect(find.text('9 of 10 required elements found'), findsOneWidget);
    expect(find.text('7 of 10 approved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review: approve, undo, add missing element and finish', (
    tester,
  ) async {
    final container = await pumpNewConsent(
      tester,
      initial: '/new-consent/review',
    );
    container.read(consentDraftProvider.notifier).loadSampleDraft();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Approve').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve').first);
    // The toast offers Undo for 5 s; don't settle past it.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('8 of 10 approved'), findsOneWidget);
    expect(find.text('Section approved'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('7 of 10 approved'), findsOneWidget);
    expect(find.text('Section approved'), findsNothing);

    await clearSnackBars(tester);
    await tapVisible(tester, find.text('9 of 10 required elements found'));
    expect(find.text('All 10 required elements found'), findsOneWidget);

    await tester.ensureVisible(find.text('+ 5 more sections'));
    await tester.tap(find.text('+ 5 more sections'));
    await tester.pumpAndSettle();
    while (find.text('Approve').evaluate().isNotEmpty) {
      await clearSnackBars(tester);
      await tester.ensureVisible(find.text('Approve').first);
      await tester.tap(find.text('Approve').first);
      await tester.pumpAndSettle();
    }
    expect(find.text('10 of 10 approved'), findsOneWidget);
    expect(find.text('Continue to form builder'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('why sheet shows the source and approves from the sheet', (
    tester,
  ) async {
    final container = await pumpNewConsent(
      tester,
      initial: '/new-consent/review',
    );
    container.read(consentDraftProvider.notifier).loadSampleDraft();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Why?'));
    expect(find.text('Why this text?'), findsOneWidget);
    expect(find.text('FROM YOUR PROPOSAL · p.6 · §3.4'), findsOneWidget);
    expect(find.text('Open page 6'), findsOneWidget);
    expect(find.text('Confidence: High'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Approve'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Why this text?'), findsNothing);
    expect(find.text('8 of 10 approved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit saves the new text and counts as approved', (tester) async {
    final container = await pumpNewConsent(
      tester,
      initial: '/new-consent/review',
    );
    container.read(consentDraftProvider.notifier).loadSampleDraft();
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Edit'));
    await tester.enterText(find.byType(TextField), 'You may get tired.');
    await tapVisible(tester, find.text('Save'));
    expect(find.text('8 of 10 approved'), findsOneWidget);
    expect(find.text('Edited'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drafting does not breathe with reduce motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpNewConsent(tester, initial: '/new-consent/drafting');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('screens fit a narrow phone with large text and targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await pumpNewConsent(tester, large: true);
    container.read(consentDraftProvider.notifier)
      ..pickSampleProposal()
      ..pickSampleBlockedFile();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expectNoException(tester);
    container.read(consentDraftProvider.notifier).loadSampleDraft();
    final router = GoRouter.of(
      tester.element(find.byType(UploadProposalScreen)),
    );
    router.go('/new-consent/review');
    await tester.pumpAndSettle();
    expectNoException(tester);
  });
}
