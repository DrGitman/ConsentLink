import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_data.dart';
import 'package:consentlink/features/projects/project_detail_screen.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:consentlink/features/projects/projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> pumpProjects(
  WidgetTester tester, {
  bool preview = false,
  bool large = false,
  String initial = '/projects',
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/projects',
        pageBuilder: (context, state) =>
            projectPushPage(key: state.pageKey, child: const ProjectsScreen()),
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
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const Text('Capture placeholder'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectsPreviewProvider.overrideWithValue(preview),
        largerTouchTargetsProvider.overrideWith((ref) => large),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => Scaffold(body: SafeArea(child: child!)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('normal mode shows an honest empty state', (tester) async {
    await pumpProjects(tester);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('All 0'), findsOneWidget);
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Water access & health in Opuwo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview lists sample projects and filters them', (tester) async {
    await pumpProjects(tester, preview: true);
    expect(find.text('All 5'), findsOneWidget);
    expect(find.text('Water access & health in Opuwo'), findsOneWidget);
    expect(find.text('64/80'), findsOneWidget);
    await tester.tap(find.text('Drafts'));
    await tester.pumpAndSettle();
    expect(find.text('Rundu market traders'), findsOneWidget);
    expect(find.text('Juǀ’hoan oral histories'), findsOneWidget);
    expect(find.text('Water access & health in Opuwo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card opens the project detail and back returns', (
    tester,
  ) async {
    await pumpProjects(tester, preview: true);
    await tester.tap(find.text('Water access & health in Opuwo'));
    await tester.pumpAndSettle();
    expect(find.text('Consented'), findsOneWidget);
    expect(
      find.text('Ethics: FCI-REC-2026-041 · valid to Mar 2027'),
      findsOneWidget,
    );
    expect(find.text('Participant fills on their own phone'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Consented'), findsNothing);
    expect(find.text('All 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('field capture only starts for collecting projects', (
    tester,
  ) async {
    await pumpProjects(
      tester,
      preview: true,
      initial: '/projects/rundu-traders',
    );
    expect(
      find.text('Create and approve a consent form first.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Start field capture'));
    await tester.pumpAndSettle();
    expect(find.text('Capture placeholder'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail fits a narrow screen with large text and targets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpProjects(
      tester,
      preview: true,
      large: true,
      initial: '/projects/water-opuwo',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    await pumpProjects(tester, preview: true, large: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce motion makes the push a short fade', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpProjects(tester, preview: true);
    await tester.tap(find.text('Youth & mobile banking'));
    // First frame lets the router build the new page; the fade then runs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Consented'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is SlideTransition && w.position.value != Offset.zero,
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
