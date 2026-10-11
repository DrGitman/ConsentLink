import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/dashboard/dashboard_components.dart';
import 'package:consentlink/features/form_builder/form_builder_data.dart';
import 'package:consentlink/features/form_builder/form_builder_screen.dart';
import 'package:consentlink/features/form_builder/template_style_screen.dart';
import 'package:consentlink/features/new_consent/consent_draft_data.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpForm(
  WidgetTester tester, {
  bool preview = true,
  bool large = false,
  String initial = '/new-consent/form',
}) async {
  if (tester.view.physicalSize == const Size(2400, 1800)) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/projects',
        builder: (context, state) => const Text('Projects placeholder'),
      ),
      GoRoute(
        path: '/new-consent/form',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: const FormBuilderScreen(),
        ),
      ),
      GoRoute(
        path: '/new-consent/template',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: const TemplateStyleScreen(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
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
  await tester.pumpAndSettle();
  return container;
}

void expectNoException(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    fail(error is FlutterError ? error.toStringDeep() : '$error');
  }
}

void main() {
  testWidgets('preview shows the six Figma questions', (tester) async {
    await pumpForm(tester);
    expect(find.text('Participant details'), findsOneWidget);
    expect(find.text('Name or pseudonym'), findsOneWidget);
    expect(find.text('Short text · required'), findsOneWidget);
    expect(find.text('Yes / No · required'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Signature or thumbprint'), 200);
    expect(find.text('Consent capture · required'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('normal mode starts with only consent capture', (tester) async {
    final c = await pumpForm(tester, preview: false);
    expect(c.read(formFieldsProvider), hasLength(1));
    expect(find.text('Signature or thumbprint'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('add a question from the 12-type sheet', (tester) async {
    final c = await pumpForm(tester);
    await tester.scrollUntilVisible(find.text('Add a question'), 200);
    await tester.tap(find.text('Add a question'));
    await tester.pumpAndSettle();
    expect(find.text('Rating scale'), findsOneWidget);
    expect(
      find.textContaining('Tip: keep participant questions'),
      findsOneWidget,
    );
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    expect(c.read(formFieldsProvider).last.type, FieldType.date);
    expect(c.read(formFieldsProvider), hasLength(7));
    expectNoException(tester);
  });

  testWidgets('voice badge toggles and edit sheet changes required', (
    tester,
  ) async {
    final c = await pumpForm(tester);
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is DashboardAction &&
            w.label == 'Voice answers on for Village / site',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      c.read(formFieldsProvider).firstWhere((f) => f.id == 'site').voiceAllowed,
      isFalse,
    );
    await tester.tap(find.text('Village / site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Required'));
    await tester.pumpAndSettle();
    expect(
      c.read(formFieldsProvider).firstWhere((f) => f.id == 'site').required,
      isTrue,
    );
    expectNoException(tester);
  });

  testWidgets('consent capture cannot be deleted', (tester) async {
    final c = await pumpForm(tester);
    await tester.scrollUntilVisible(find.text('Signature or thumbprint'), 200);
    await tester.tap(find.text('Signature or thumbprint'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete question?'), findsNothing);
    expect(c.read(formFieldsProvider).any((f) => f.id == 'consent'), isTrue);
    expectNoException(tester);
  });

  testWidgets('template & style switches templates and saves', (tester) async {
    await pumpForm(tester, initial: '/new-consent/template');
    expect(find.text('Look of your form'), findsOneWidget);
    expect(find.text('Official NUST template · locked fields'), findsOneWidget);
    expect(find.text('Arial · 11 pt'), findsOneWidget);
    await tester.tap(find.text('Social sciences v2'));
    await tester.pumpAndSettle();
    expect(find.text('Calibri · 12 pt'), findsOneWidget);
    expect(find.text('Official NUST template · locked fields'), findsNothing);
    await tester.tap(find.text('Save form'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Form saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Projects placeholder'), findsOneWidget);
    expectNoException(tester);
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
    await pumpForm(tester, large: true);
    expectNoException(tester);
    await tester.scrollUntilVisible(find.text('Add a question'), 300);
    await tester.tap(find.text('Add a question'));
    await tester.pumpAndSettle();
    expectNoException(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await pumpForm(tester, large: true, initial: '/new-consent/template');
    expectNoException(tester);
  });
}
