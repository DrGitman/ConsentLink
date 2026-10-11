import 'dart:convert';

import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/core/theme/theme_provider.dart';
import 'package:consentlink/features/institution/researcher_details_screen.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:consentlink/features/responses/responses_data.dart';
import 'package:consentlink/features/settings/accessibility_settings_screen.dart';
import 'package:consentlink/features/settings/account_settings_screen.dart';
import 'package:consentlink/features/settings/feedback_settings_screen.dart';
import 'package:consentlink/features/settings/language_settings_screen.dart';
import 'package:consentlink/features/settings/me_screen.dart';
import 'package:consentlink/features/settings/privacy_settings_screen.dart';
import 'package:consentlink/features/settings/settings_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<ProviderContainer> pumpSettings(
  WidgetTester tester, {
  String initial = '/me',
  bool preview = true,
  bool large = false,
  double textScale = 1,
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
  GoRoute placeholder(String path) => GoRoute(
    path: path,
    builder: (context, state) => Scaffold(body: Text('$path placeholder')),
  );

  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/me',
        builder: (context, state) => const Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(child: MeScreen()),
        ),
      ),
      page('/settings/accessibility', const AccessibilitySettingsScreen()),
      page('/settings/languages', const LanguageSettingsScreen()),
      page('/settings/feedback', const FeedbackSettingsScreen()),
      page('/settings/account', const AccountSettingsScreen()),
      page('/settings/privacy', const PrivacySettingsScreen()),
      placeholder('/login'),
      placeholder('/researcher-details'),
      placeholder('/offline-pack'),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      settingsPreviewProvider.overrideWithValue(preview),
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

void main() {
  test('feedback pop-up follows how often', () {
    const every2nd = FeedbackSettings();
    expect(feedbackDue(every2nd, 1), isTrue);
    expect(feedbackDue(every2nd, 2), isFalse);
    expect(feedbackDue(every2nd, 3), isTrue);
    expect(
      feedbackDue(
        const FeedbackSettings(frequency: FeedbackFrequency.never),
        1,
      ),
      isFalse,
    );
    expect(feedbackDue(const FeedbackSettings(enabled: false), 1), isFalse);
    const random = FeedbackSettings(frequency: FeedbackFrequency.random);
    expect(feedbackDue(random, 1, random: .1), isTrue);
    expect(feedbackDue(random, 1, random: .9), isFalse);
  });

  testWidgets('08.1 normal mode shows no sample profile', (tester) async {
    await pumpSettings(tester, preview: false);
    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Ndapewa Shikongo'), findsNothing);
    expect(find.text('English · forms: 1'), findsOneWidget);
    expect(find.text('Not downloaded'), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('08.1 Me shows Figma rows and opens each page', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Ndapewa Shikongo'), findsOneWidget);
    expect(find.text('English · forms: 4'), findsOneWidget);
    expect(find.text('After every 2nd form'), findsOneWidget);
    expect(find.text('Gemma 4 E2B · 1.3 GB'), findsOneWidget);

    for (final (row, title) in [
      ('Accessibility', 'Accessibility'),
      ('Language', 'Languages'),
      ('Feedback pop-up', 'Feedback pop-up'),
      ('Privacy & data', 'Privacy & data'),
    ]) {
      await tapVisible(tester, find.text(row).first);
      expect(find.text(title), findsWidgets);
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
    }

    await tapVisible(tester, find.text('Ndapewa Shikongo'));
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Appearance'));
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(find.text('Light'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('08.5 sign out asks first', (tester) async {
    await pumpSettings(tester, initial: '/settings/account');
    await tapVisible(tester, find.text('Sign out'));
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsNothing);
    await tapVisible(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(find.text('/login placeholder'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('08.2 switches and text size are real settings', (tester) async {
    final container = await pumpSettings(
      tester,
      initial: '/settings/accessibility',
    );
    expect(find.text('You can stop at any time.'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tapVisible(tester, find.text('High contrast'));
    expect(container.read(highContrastProvider), isTrue);
    await tapVisible(tester, find.text('Reduce motion'));
    expect(container.read(reduceMotionPreferenceProvider), isTrue);
    await tapVisible(tester, find.text('Read aloud'));
    expect(container.read(readScreensAloudProvider), isTrue);
    expect(find.text('Speed 0.9×'), findsOneWidget);

    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    final box = tester.getRect(slider);
    await tester.tapAt(Offset(box.right - 30, box.center.dy));
    await tester.pumpAndSettle();
    expect(container.read(appTextScaleProvider), greaterThan(1.4));
    expectNoException(tester);
  });

  testWidgets('08.3 app language, download, review, turn off', (tester) async {
    final container = await pumpSettings(
      tester,
      initial: '/settings/languages',
    );
    expect(find.text('Reviewed by J. Kavari'), findsOneWidget);
    expect(find.text('Needs review'), findsNWidgets(2));

    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Afrikaans').last);
    expect(container.read(selectedAppLanguageProvider), 'Afrikaans');

    await tester.ensureVisible(find.text('Silozi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Silozi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Downloading…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Needs review'), findsNWidgets(3));

    await tapVisible(tester, find.text('Silozi'));
    expect(find.text('Review Silozi'), findsOneWidget);
    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();
    expect(find.text('Reviewed by you'), findsOneWidget);

    await tapVisible(tester, find.text('Deutsch'));
    expect(find.text('Off'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('08.4 how often, off, preview pop-up', (tester) async {
    final container = await pumpSettings(tester, initial: '/settings/feedback');
    expect(find.text('Never shown to participants under 18.'), findsOneWidget);
    await tapVisible(tester, find.text('After every 3rd form'));
    expect(
      container.read(feedbackSettingsProvider).frequency,
      FeedbackFrequency.everyThird,
    );
    await tapVisible(tester, find.text('Allow voice comments'));
    expect(container.read(feedbackSettingsProvider).voiceComments, isFalse);

    await tapVisible(tester, find.text('Preview pop-up'));
    expect(find.text('How was this for you?'), findsOneWidget);
    await tapVisible(tester, find.text('Skip'));
    expect(find.text('How was this for you?'), findsNothing);

    await tapVisible(tester, find.text('Show feedback pop-up'));
    expect(container.read(feedbackSettingsProvider).enabled, isFalse);
    await tapVisible(tester, find.text('Never'));
    // Disabled while the pop-up is off.
    expect(
      container.read(feedbackSettingsProvider).frequency,
      FeedbackFrequency.everyThird,
    );
    expectNoException(tester);
  });

  testWidgets('08.5 account: photo sheet, rows, delete asks twice', (
    tester,
  ) async {
    final container = await pumpSettings(tester, initial: '/settings/account');
    expect(find.text('nshikongo@nust.na'), findsOneWidget);
    expect(find.text('Keep records for'), findsNothing);

    await tapVisible(tester, find.text('Add photo'));
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();

    // 1×1 PNG stands in for a picked photo.
    container.read(profilePhotoProvider.notifier).state = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tapVisible(tester, find.text('Change photo'));
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(container.read(profilePhotoProvider), isNull);
    expect(find.text('Add photo'), findsOneWidget);

    await tapVisible(tester, find.text('Delete account'));
    expect(find.text('Delete account?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nothing was deleted'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('08.5 researcher details sheet edits and saves', (tester) async {
    final container = await pumpSettings(tester, initial: '/settings/account');
    await tapVisible(tester, find.text('Researcher details'));
    expect(find.text('Save details'), findsOneWidget);
    // Preview fills the Figma sample.
    expect(find.text('Ms Ndapewa Shikongo'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Mr Petrus Nangolo');
    await tester.enterText(fields.at(1), 'not-an-email');
    await tapVisible(tester, find.text('Save details'));
    expect(find.text('Enter an email like name@nust.na'), findsOneWidget);

    await tester.enterText(fields.at(1), 'pnangolo@nust.na');
    await tapVisible(tester, find.text('Save details'));
    expect(find.text('Details saved'), findsWidgets);
    expect(container.read(researcherDraftProvider).first, 'Mr Petrus Nangolo');
    expect(container.read(researcherEmailProvider), 'pnangolo@nust.na');
    expect(find.text('Mr Petrus Nangolo'), findsOneWidget);
    expect(find.text('pnangolo@nust.na'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('researcher details sheet swipes down to close', (
    tester,
  ) async {
    await pumpSettings(tester, initial: '/settings/account');
    await tapVisible(tester, find.text('Researcher details'));
    expect(find.text('Save details'), findsOneWidget);
    await tester.drag(find.text('Ms Ndapewa Shikongo'), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('Save details'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('privacy & data rows explain and download', (tester) async {
    await pumpSettings(tester, initial: '/settings/privacy');
    expect(find.text('5 years (NUST policy)'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await tapVisible(tester, find.text('Keep records for'));
    expect(find.textContaining('institution\'s policy'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Download all my data'));
    expect(find.text('Export'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('every screen fits 200% text and larger targets', (tester) async {
    for (final route in [
      '/me',
      '/settings/accessibility',
      '/settings/languages',
      '/settings/feedback',
      '/settings/account',
      '/settings/privacy',
    ]) {
      final details = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => details.add(d.toString());
      await pumpSettings(tester, initial: route, textScale: 2, large: true);
      FlutterError.onError = previous;
      expect(details, isEmpty, reason: 'Layout error on $route');
    }
  });
}
