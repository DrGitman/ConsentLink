import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/field_capture/done_screen.dart';
import 'package:consentlink/features/field_capture/field_capture_data.dart';
import 'package:consentlink/features/field_capture/hand_over_screen.dart';
import 'package:consentlink/features/field_capture/read_consent_screen.dart';
import 'package:consentlink/features/minors/age_check_screen.dart';
import 'package:consentlink/features/minors/assent_screen.dart';
import 'package:consentlink/features/minors/assent_stopped_screen.dart';
import 'package:consentlink/features/minors/guardian_consent_screen.dart';
import 'package:consentlink/features/minors/guardian_details_screen.dart';
import 'package:consentlink/features/minors/minors_data.dart';
import 'package:consentlink/features/minors/minors_settings_screen.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:consentlink/features/responses/consent_record_screen.dart';
import 'package:consentlink/features/responses/responses_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpMinors(
  WidgetTester tester, {
  required String initial,
  bool large = false,
  double textScale = 1,
  void Function(ProviderContainer)? setup,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  GoRoute page(String path, Widget child) => GoRoute(
    path: path,
    pageBuilder: (context, state) =>
        projectPushPage(key: state.pageKey, child: child),
  );

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const Text('Home placeholder')),
      GoRoute(
        path: '/projects/:id',
        builder: (_, state) => Text('Project ${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/insights/responses',
        builder: (_, _) => const Text('Responses placeholder'),
      ),
      page(
        '/participants/water-opuwo',
        const MinorsSettingsScreen(projectId: 'water-opuwo'),
      ),
      GoRoute(
        path: '/responses/:code',
        builder: (_, state) =>
            ConsentRecordScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/field-capture',
        pageBuilder: (context, state) => projectPushPage(
          key: state.pageKey,
          child: HandOverScreen(
            projectId: state.uri.queryParameters['project'],
          ),
        ),
        routes: [
          page('read', const ReadConsentScreen()),
          page('done', const DoneScreen()),
          page('age', const AgeCheckScreen()),
          page('guardian', const GuardianDetailsScreen()),
          page('guardian-consent', const GuardianConsentScreen()),
          page('assent', const AssentScreen()),
          page('stopped', const AssentStoppedScreen()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      fieldCapturePreviewProvider.overrideWithValue(true),
      insightsPreviewProvider.overrideWithValue(true),
      largerTouchTargetsProvider.overrideWith((ref) => large),
    ],
  );
  addTearDown(container.dispose);
  setup?.call(container);
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

/// Guardian finished 10.3–10.4 (age 14, all yes except photos, signed).
void guardianDone(ProviderContainer c, {bool takePart = true, int age = 14}) {
  final m = c.read(minorSessionProvider.notifier);
  m.start();
  m.setAge(age);
  m.setAuthority(true);
  m.choose('take_part', takePart);
  m.choose('record_voice', true);
  m.choose('photos', false);
  m.setStrokes([
    [for (var i = 0; i < 12; i++) Offset(10.0 + i * 8, 20.0 + i % 3)],
  ]);
}

void main() {
  testWidgets('age check: minors need a guardian, bands follow 10.1', (
    tester,
  ) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture?project=water-opuwo',
    );
    await tester.tap(find.text('Start for participant'));
    await tester.pumpAndSettle();
    expect(find.text('How old is the participant?'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('Under 18 — two steps needed'), findsOneWidget);

    // 7–11 is off for this project.
    c.read(minorSessionProvider.notifier).setAge(11);
    await tester.pumpAndSettle();
    expect(find.textContaining('aren’t switched on'), findsOneWidget);

    c.read(minorSessionProvider.notifier).setAge(18);
    await tester.pumpAndSettle();
    expect(find.text('18 or over · standard consent form'), findsOneWidget);

    c.read(minorSessionProvider.notifier).setAge(14);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with guardian'));
    await tester.pumpAndSettle();
    expect(find.text('Guardian'), findsWidgets);
    expect(
      find.text('Step 1 of 3 · for participant P-071 (age 14)'),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('guardian details: authority check, then guardian reads', (
    tester,
  ) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/guardian',
      setup: (c) => c.read(minorSessionProvider.notifier).start(),
    );
    expect(find.text('Uerimunu Tjiuma'), findsOneWidget);
    await tapVisible(tester, find.text('Legal guardian'));
    expect(
      c.read(minorSessionProvider).relationship,
      GuardianRelationship.legalGuardian,
    );
    // Not confirmed yet: nothing happens.
    await tapVisible(tester, find.text('Guardian reads & signs'));
    expect(find.text('Guardian reads & signs'), findsOneWidget);
    expect(c.read(minorSessionProvider).guardianReading, isFalse);

    await tapVisible(tester, find.textContaining('legal authority'));
    expect(c.read(minorSessionProvider).authorityConfirmed, isTrue);
    await tapVisible(tester, find.text('Guardian reads & signs'));
    expect(c.read(minorSessionProvider).guardianReading, isTrue);
    expect(find.text('Section 1 of 8'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('guardian consent: three choices and a signature', (
    tester,
  ) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/guardian-consent',
      setup: (c) => c.read(minorSessionProvider.notifier).start(),
    );
    expect(find.text('Do you allow your child to take part?'), findsOneWidget);
    expect(
      find.textContaining('Uerimunu read the full consent'),
      findsOneWidget,
    );
    await tapVisible(tester, find.text('Yes').at(0));
    await tapVisible(tester, find.text('Yes').at(1));
    await tapVisible(tester, find.text('No').at(2));
    expect(c.read(minorSessionProvider).allChosen, isTrue);
    expect(c.read(minorSessionProvider).choices['photos'], isFalse);
    // Not signed yet.
    await tapVisible(tester, find.text('Now ask the young person'));
    expect(find.text('Now ask the young person'), findsOneWidget);

    await tapVisible(tester, find.text('Tap to sign'));
    final pad = find.bySemanticsLabel('Signature pad. Sign with your finger.');
    await tester.drag(pad, const Offset(160, 30));
    await tester.drag(pad, const Offset(-120, 20));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(c.read(minorSessionProvider).signed, isTrue);
    expect(find.text('Signed'), findsOneWidget);

    await tapVisible(tester, find.text('Now ask the young person'));
    expect(find.text('It’s your choice'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('guardian says no: finish without asking the child', (
    tester,
  ) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/guardian-consent',
      setup: (c) => guardianDone(c, takePart: false),
    );
    await tapVisible(tester, find.text('Finish'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Thank you'), findsOneWidget);
    final r = c.read(responsesProvider).firstWhere((r) => r.code == 'P-071');
    expect(r.status, ResponseStatus.declined);
    expect(r.audit.single.text, contains('guardian'));
    expectNoException(tester);
  });

  testWidgets('12–17: Not sure pauses, No always stops', (tester) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/assent',
      setup: guardianDone,
    );
    expect(find.text('It’s your choice'), findsOneWidget);
    // Listen plays for a (simulated) minute, so settle the scroll before
    // starting it but pump frame-by-frame afterwards: pumpAndSettle would
    // fast-forward the fake clock and stop playback before we can assert.
    await tester.ensureVisible(find.text('Listen to what will happen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Listen to what will happen'));
    await tester.pump();
    expect(find.text('Listening…'), findsOneWidget);
    await tester.ensureVisible(find.text('Listening…'));
    await tester.pump();
    await tester.tap(find.text('Listening…'));
    await tester.pump();

    await tapVisible(tester, find.text('Not sure'));
    expect(find.textContaining('Paused. Ask the researcher'), findsOneWidget);
    await tapVisible(tester, find.text('Done'));
    expect(find.text('It’s your choice'), findsOneWidget);

    await tapVisible(tester, find.text('No'));
    await tapVisible(tester, find.text('Done'));
    expect(find.text('Thank you for telling us'), findsOneWidget);
    expect(find.textContaining('overridden by the child'), findsOneWidget);
    final r = c.read(responsesProvider).firstWhere((r) => r.code == 'P-071');
    expect(r.status, ResponseStatus.declined);
    expect(r.audit.single.text, contains('assent'));

    await tapVisible(tester, find.text('Back to researcher'));
    expect(find.text('Home placeholder'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('12–17: Yes saves consent + assent, no feedback pop-up', (
    tester,
  ) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/assent',
      setup: guardianDone,
    );
    await tapVisible(tester, find.text('Yes'));
    await tapVisible(tester, find.text('Done'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }
    expect(find.text('Thank you'), findsOneWidget);
    expect(find.text('How was this for you?'), findsNothing);
    final record = c
        .read(minorRecordsProvider)
        .firstWhere((r) => r.code == 'P-071');
    expect(record.assent, AssentAnswer.yes);
    expect(record.choices['photos'], isFalse);
    expect(
      c.read(responsesProvider).firstWhere((r) => r.code == 'P-071').status,
      ResponseStatus.agreed,
    );
    expectNoException(tester);
  });

  testWidgets('7–11: pictures, faces and a big listen button', (tester) async {
    final c = await pumpMinors(
      tester,
      initial: '/field-capture/assent',
      setup: (c) => guardianDone(c, age: 9),
    );
    expect(
      find.text('Do you want to help with our questions?'),
      findsOneWidget,
    );
    expect(find.text('Yes!'), findsOneWidget);
    await tapVisible(tester, find.text('No'));
    expect(c.read(minorSessionProvider).assent, AssentAnswer.no);
    await tapVisible(tester, find.text('Done'));
    expect(find.text('Thank you for telling us'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('10.1 participants setting turns the minors flow on and off', (
    tester,
  ) async {
    final c = await pumpMinors(tester, initial: '/participants/water-opuwo');
    expect(find.text('FCI-REC-2026-041 covers ages 12–17'), findsOneWidget);
    await tapVisible(tester, find.text('Picture + audio assent'));
    expect(c.read(minorsSettingsProvider)['water-opuwo']!.childBand, isTrue);
    await tapVisible(tester, find.text('Includes under-18s'));
    expect(
      c.read(minorsSettingsProvider)['water-opuwo']!.includesMinors,
      isFalse,
    );
    expectNoException(tester);
  });

  testWidgets('10.8 minor record shows both decisions and can withdraw', (
    tester,
  ) async {
    final c = await pumpMinors(tester, initial: '/responses/P-071');
    expect(find.text('P-071 · age 14'), findsOneWidget);
    expect(find.text('Uerimunu Tjiuma · Parent'), findsOneWidget);
    expect(
      find.text('Take part: Yes · Voice: Yes · Photos: No'),
      findsOneWidget,
    );
    expect(
      find.text('Said “Yes” after listening (12–17 form)'),
      findsOneWidget,
    );
    expect(find.textContaining('12 Mar 2030'), findsOneWidget);
    await tapVisible(tester, find.text('Record withdrawal'));
    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(c.read(minorRecordsProvider).first.withdrawnAt, isNotNull);
    expect(find.textContaining('Withdrawn ·'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('every minors screen fits 200% text and larger targets', (
    tester,
  ) async {
    for (final route in [
      '/participants/water-opuwo',
      '/field-capture/age',
      '/field-capture/guardian',
      '/field-capture/guardian-consent',
      '/field-capture/assent',
      '/field-capture/stopped',
      '/responses/P-071',
    ]) {
      final details = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => details.add(d.toString());
      await pumpMinors(
        tester,
        initial: route,
        textScale: 2,
        large: true,
        setup: route.endsWith('assent') ? guardianDone : null,
      );
      FlutterError.onError = previous;
      expect(details, isEmpty, reason: 'Layout error on $route');
    }
  });
}
