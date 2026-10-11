import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/dashboard/dashboard_components.dart';
import 'package:consentlink/features/form_builder/form_builder_data.dart';
import 'package:consentlink/features/new_consent/consent_draft_data.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:consentlink/features/templates/clip_logo_screen.dart';
import 'package:consentlink/features/templates/describe_template_screen.dart';
import 'package:consentlink/features/templates/read_template_screen.dart';
import 'package:consentlink/features/templates/template_data.dart';
import 'package:consentlink/features/templates/template_detail_screen.dart';
import 'package:consentlink/features/templates/template_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpTemplates(
  WidgetTester tester, {
  String initial = '/templates',
  bool preview = true,
  bool large = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  GoRoute page(String path, Widget Function(GoRouterState) child) => GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        projectPushPage(key: state.pageKey, child: child(state)),
  );

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('Home placeholder'),
      ),
      GoRoute(
        path: '/new-consent/template',
        builder: (context, state) => const Text('Template & style placeholder'),
      ),
      GoRoute(
        path: '/templates',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: const TemplateLibraryScreen(),
        ),
        routes: [
          page('read', (_) => const ReadTemplateScreen()),
          page('clip', (_) => const ClipLogoScreen()),
          page('describe', (_) => const DescribeTemplateScreen()),
          page(
            'view/:id',
            (s) => TemplateDetailScreen(id: s.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      templatesPreviewProvider.overrideWithValue(preview),
      newConsentPreviewProvider.overrideWithValue(preview),
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
          child: child!,
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

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Lets the 3 s toast leave so no timer is left pending.
Future<void> clearToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// The read screen scans for 1.2 s before showing the rules.
Future<void> waitForScan(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('normal mode shows no sample templates', (tester) async {
    await pumpTemplates(tester, preview: false);
    expect(find.text('No templates yet'), findsOneWidget);
    expect(find.text('Health research v3'), findsNothing);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload a template'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('05.1 library filters, searches and opens a template', (
    tester,
  ) async {
    await pumpTemplates(tester);
    expect(find.text('My Opuwo health consent'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Official · NUST'), findsNWidgets(2));
    expect(find.text('Shared · NUST'), findsOneWidget);

    await tester.tap(find.text('Official'));
    await tester.pumpAndSettle();
    expect(find.text('My Opuwo health consent'), findsNothing);
    expect(find.text('Health research v3'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kavari');
    await tester.pumpAndSettle();
    expect(find.text('Interview + audio consent'), findsOneWidget);
    expect(find.text('Health research v3'), findsNothing);

    await tester.tap(find.text('Interview + audio consent'));
    await tester.pumpAndSettle();
    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Calibri 12 pt'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('05.1 plus makes a blank template to edit', (tester) async {
    final container = await pumpTemplates(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is DashboardIcon && w.name == 'projects/plus',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Who can use it?'), findsOneWidget);
    await tapVisible(tester, find.text('Save template').last);
    expect(find.text('Untitled template'), findsOneWidget);
    expect(find.text('Page numbers'), findsOneWidget);
    expect(container.read(templateLibraryProvider), hasLength(5));
    expectNoException(tester);
  });

  testWidgets('05.5 official template is locked; duplicate and use', (
    tester,
  ) async {
    final container = await pumpTemplates(
      tester,
      initial: '/templates/view/health-v3',
    );
    expect(find.text('Health research v3'), findsOneWidget);
    expect(
      find.text('Verified with NUST ethics office · v3 · 2 Oct 2026'),
      findsOneWidget,
    );
    expect(find.textContaining('are locked'), findsOneWidget);

    await tester.tap(find.text('Font'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Locked by the official template'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use for form'));
    await tester.pumpAndSettle();
    expect(find.text('Template & style placeholder'), findsOneWidget);
    expect(container.read(selectedTemplateProvider), 'health-v3');
    expectNoException(tester);
  });

  testWidgets('05.5 duplicate makes a private copy you can edit', (
    tester,
  ) async {
    final container = await pumpTemplates(
      tester,
      initial: '/templates/view/health-v3',
    );
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();
    expect(find.text('Copy of Health research v3'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.textContaining('are locked'), findsNothing);

    await tester.tap(find.text('Font'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Arial 12 pt');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save'));
    expect(find.text('Arial 12 pt'), findsOneWidget);
    expect(container.read(templateLibraryProvider), hasLength(5));
    await clearToast(tester);
    expectNoException(tester);
  });

  testWidgets('05.2 scans, edits a rule, clips the logo and saves (05.6)', (
    tester,
  ) async {
    final container = await pumpTemplates(tester);
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Upload a template'), findsOneWidget);
    await tester.tap(find.text(uploadedTemplateFile));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Scanning for macros…'), findsOneWidget);
    await waitForScan(tester);
    expect(find.text('Safe · macros removed'), findsOneWidget);
    expect(find.text('Arial Bold 13 pt'), findsOneWidget);
    expect(find.text('Medium'), findsNWidgets(2));

    await tapVisible(tester, find.text('Margins'));
    await tester.enterText(find.byType(TextField), '2 cm all sides');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save'));
    expect(find.text('2 cm all sides'), findsOneWidget);
    expect(find.text('Edited'), findsOneWidget);

    await tapVisible(tester, find.text('Logo found on page 1'));
    expect(find.text('Clip logo'), findsOneWidget);
    expect(find.text('Auto-detect edges (contour)'), findsOneWidget);
    await tester.tap(find.text('Remove white background'));
    await tester.pumpAndSettle();
    expect(find.text('Saved as PNG · used on every NUST form'), findsOneWidget);
    await tester.tap(find.text('Use this logo'));
    await tester.pumpAndSettle();
    expect(find.text('Logo clipped'), findsOneWidget);
    expect(container.read(logoCropProvider), isNotNull);

    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();
    expect(find.text('Who can use it?'), findsOneWidget);
    await tester.tap(find.text('NUST researchers'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save template').last);
    expect(find.text('Opuwo health consent'), findsOneWidget);
    expect(find.text('Shared · NUST'), findsNWidgets(2));
    expect(find.text('Template saved'), findsOneWidget);
    await clearToast(tester);
    expectNoException(tester);
  });

  testWidgets('05.4 assistant: untick, reply and create a template', (
    tester,
  ) async {
    final container = await pumpTemplates(
      tester,
      initial: '/templates/describe',
    );
    expect(find.text('On-device · you approve every change'), findsOneWidget);
    expect(find.text('Here’s the template I’d build:'), findsOneWidget);

    await tester.tap(find.text('Two columns: English | Afrikaans'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Add an Otjiherero summary');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('Add an Otjiherero summary'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    expect(find.text('Added: Add an Otjiherero summary'), findsOneWidget);
    // The new proposal keeps only the ticked items.
    expect(find.text('Two columns: English | Afrikaans'), findsOneWidget);

    await tapVisible(tester, find.text('Create template').last);
    expect(find.text('Save template'), findsWidgets);
    await tapVisible(tester, find.text('Save template').last);
    expect(find.text('Health consent + witness'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);
    expect(container.read(templateLibraryProvider), hasLength(5));
    await clearToast(tester);
    expectNoException(tester);
  });

  testWidgets('05.4 voice note plays', (tester) async {
    await pumpTemplates(tester, initial: '/templates/describe');
    expect(find.text('0:08'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is DashboardIcon && w.name == 'capture/play',
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('0:08'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('every screen fits 200% text and larger targets', (tester) async {
    for (final route in [
      '/templates',
      '/templates/view/health-v3',
      '/templates/view/my-opuwo',
      '/templates/clip',
      '/templates/describe',
    ]) {
      final details = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => details.add(d.toString());
      await pumpTemplates(tester, initial: route, textScale: 2, large: true);
      FlutterError.onError = previous;
      expect(details, isEmpty, reason: 'Layout error on $route');
    }
    final details = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => details.add(d.toString());
    await pumpTemplates(
      tester,
      initial: '/templates/read',
      textScale: 2,
      large: true,
    );
    await waitForScan(tester);
    await tester.ensureVisible(find.text('Save template'));
    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();
    FlutterError.onError = previous;
    expect(details, isEmpty, reason: 'Layout error on read + save sheet');
  });

  testWidgets('reduce motion: library and read screen settle', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpTemplates(tester, initial: '/templates/read');
    await waitForScan(tester);
    expect(find.text('Safe · macros removed'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expectNoException(tester);
  });
}
