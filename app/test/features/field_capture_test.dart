import 'package:consentlink/core/theme/app_theme.dart';
import 'package:consentlink/features/field_capture/answer_screen.dart';
import 'package:consentlink/features/field_capture/choices_screen.dart';
import 'package:consentlink/features/field_capture/done_screen.dart';
import 'package:consentlink/features/field_capture/field_capture_data.dart';
import 'package:consentlink/features/field_capture/hand_over_screen.dart';
import 'package:consentlink/features/field_capture/read_consent_screen.dart';
import 'package:consentlink/features/field_capture/sign_screen.dart';
import 'package:consentlink/features/field_capture/voice_input.dart';
import 'package:consentlink/features/preferences/accessibility_preferences.dart';
import 'package:consentlink/features/projects/project_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class FakeVoiceInput implements VoiceInput {
  FakeVoiceInput({this.available = true, this.words = 'Kaera Tjiuma'});
  final bool available;
  final String words;
  int starts = 0;
  int stops = 0;

  @override
  Future<bool> start({
    required void Function(String text) onText,
    required void Function(double level) onLevel,
    required void Function() onStopped,
  }) async {
    starts++;
    if (!available) return false;
    onLevel(.8);
    onText(words);
    return true;
  }

  @override
  Future<void> stop() async => stops++;
}

Future<ProviderContainer> pumpCapture(
  WidgetTester tester, {
  String initial = '/field-capture',
  bool preview = true,
  bool large = false,
  double textScale = 1,
  CaptureParticipant? participant,
  VoiceInput? voice,
  CaptureSession? session,
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
      GoRoute(
        path: '/home',
        builder: (context, state) => const Text('Home placeholder'),
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) =>
            Text('Project ${state.pathParameters['id']}'),
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
          page('answer', const AnswerScreen()),
          page('choices', const ChoicesScreen()),
          page('sign', const SignScreen()),
          page('done', const DoneScreen()),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      fieldCapturePreviewProvider.overrideWithValue(preview),
      largerTouchTargetsProvider.overrideWith((ref) => large),
      voiceInputProvider.overrideWithValue(voice ?? FakeVoiceInput()),
      if (participant != null)
        captureParticipantProvider.overrideWithValue(participant),
    ],
  );
  addTearDown(container.dispose);
  if (session != null) {
    container.read(captureSessionProvider.notifier).state = session;
  }
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

/// The thank-you appears after 0.35 s and the pop-up after another 1.1 s.
Future<void> settleDone(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

const _allChosen = {
  'take_part': true,
  'record_voice': true,
  'quote': false,
  'contact_again': false,
};

void main() {
  testWidgets('06.1 normal mode shows no sample participant', (tester) async {
    await pumpCapture(tester, preview: false);
    expect(find.text('Field capture'), findsOneWidget);
    expect(find.text('No participant session'), findsOneWidget);
    expect(find.text('P-065'), findsNothing);
    await tester.tap(find.text('Start for participant'));
    await tester.pumpAndSettle();
    expect(find.text('Field capture'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.1 hand over: Figma content, language and toggles', (
    tester,
  ) async {
    final container = await pumpCapture(tester);
    expect(find.text('Offline · saving on this phone'), findsOneWidget);
    expect(find.text('P-065'), findsOneWidget);
    expect(find.text('Water access & health · Opuwo site'), findsOneWidget);
    expect(find.text('Recorded Otjiherero voice'), findsOneWidget);
    expect(
      find.text('Hand the phone to the participant, or read it together.'),
      findsOneWidget,
    );

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Recorded English voice'), findsOneWidget);

    await tester.tap(find.text('Interpreter present'));
    await tester.pumpAndSettle();
    expect(container.read(captureSessionProvider).interpreter, isTrue);

    await tester.tap(find.text('Start for participant'));
    await tester.pumpAndSettle();
    expect(find.text('Section 1 of 8'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.2 reads aloud, replays a sentence and moves on', (
    tester,
  ) async {
    await pumpCapture(tester, initial: '/field-capture/read');
    expect(find.text('What is this study about?'), findsOneWidget);
    // Playback has finished after settling; replay a sentence. At the
    // session's 150% text it sits below the fold, so scroll to it first.
    await tester.ensureVisible(find.text('The study is run by NUST.'));
    await tester.pump();
    await tester.tap(find.text('The study is run by NUST.'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Reading aloud · Otjiherero'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Read aloud · Otjiherero'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Section 3 of 8'), findsOneWidget);
    expect(find.text('Is there any risk to me?'), findsOneWidget);
    expect(
      find.text('You may feel tired during the interview.'),
      findsOneWidget,
    );

    await tapVisible(tester, find.text('I have a question'));
    expect(find.text('Ask the researcher'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Section 2 of 8'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.2 last section continues to the questions', (tester) async {
    await pumpCapture(
      tester,
      initial: '/field-capture/read',
      session: const CaptureSession(section: 7),
    );
    expect(find.text('Section 8 of 8'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 4'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.3 answers by voice, or types instead', (tester) async {
    final voice = FakeVoiceInput();
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/answer',
      voice: voice,
      session: const CaptureSession(question: 1),
    );
    expect(find.text('What is your name?'), findsOneWidget);
    expect(find.text('Tap the microphone to answer'), findsOneWidget);

    // The longer question pushes the card under the footer; scroll to it.
    await tester.ensureVisible(find.text('Tap the microphone to answer'));
    await tester.pump();
    await tester.tap(find.text('Tap the microphone to answer'));
    await tester.pump();
    expect(voice.starts, 1);
    expect(find.text('Kaera Tjiuma'), findsOneWidget);
    expect(find.text('Listening… tap to stop'), findsOneWidget);

    await tester.tap(find.text('Listening… tap to stop'));
    await tester.pumpAndSettle();
    expect(voice.stops, greaterThan(0));
    expect(find.text('Tap the microphone to answer'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      container.read(captureSessionProvider).answers['name'],
      'Kaera Tjiuma',
    );
    expect(find.text('Question 3 of 4'), findsOneWidget);

    await tapVisible(tester, find.text('Type instead'));
    await tester.enterText(find.byType(TextField), '5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Question 4 of 4'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.3 says so when voice input is unavailable', (tester) async {
    await pumpCapture(
      tester,
      initial: '/field-capture/answer',
      voice: FakeVoiceInput(available: false),
    );
    await tester.tap(find.text('Tap the microphone to answer'));
    await tester.pumpAndSettle();
    expect(
      find.text('Voice input isn’t available. Type instead.'),
      findsOneWidget,
    );
    expectNoException(tester);
  });

  testWidgets('06.4 Continue waits for every choice', (tester) async {
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/choices',
    );
    expect(find.text('Your choices'), findsOneWidget);
    await tapVisible(tester, find.text('Yes').at(0));
    await tapVisible(tester, find.text('Yes').at(1));
    await tapVisible(tester, find.text('No').at(2));
    expect(container.read(captureSessionProvider).allChosen, isFalse);
    await tapVisible(tester, find.text('No').at(3));
    expect(container.read(captureSessionProvider).allChosen, isTrue);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('How would you like to give consent?'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.4 saying no to taking part ends without signing', (
    tester,
  ) async {
    await pumpCapture(
      tester,
      initial: '/field-capture/choices',
      session: CaptureSession(choices: {..._allChosen, 'take_part': false}),
    );
    await tester.tap(find.text('Finish'));
    await settleDone(tester);
    expect(find.text('Thank you, Kaera'), findsOneWidget);
    expect(
      find.textContaining('You are not part of the study'),
      findsOneWidget,
    );
    // Close the feedback pop-up.
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('06.5 signing enables Finish; Clear fades the ink', (
    tester,
  ) async {
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/sign',
      session: const CaptureSession(choices: _allChosen),
    );
    expect(find.textContaining('Kaera Tjiuma · '), findsOneWidget);
    final pad = find.byType(SignaturePad);
    await tester.timedDrag(
      pad,
      const Offset(160, 30),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(container.read(captureSessionProvider).canFinish, isTrue);

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Sign here with your finger'), findsOneWidget);
    expect(container.read(captureSessionProvider).canFinish, isFalse);

    await tester.timedDrag(
      pad,
      const Offset(160, 30),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish'));
    await settleDone(tester);
    expect(find.text('Thank you, Kaera'), findsOneWidget);
    expect(find.text('How was this for you?'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expectNoException(tester);
  });

  testWidgets('06.5 thumbprint needs a hold and a witness', (tester) async {
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/sign',
      session: const CaptureSession(choices: _allChosen),
    );
    await tester.tap(find.text('Thumbprint'));
    await tester.pumpAndSettle();
    expect(find.text('Hold thumb inside the frame'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Hold thumb inside the frame')) -
          const Offset(0, 80),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Scanning… keep holding'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Captured'), findsOneWidget);
    expect(container.read(captureSessionProvider).canFinish, isFalse);
    expect(find.text('Add a witness to finish.'), findsOneWidget);

    await tapVisible(tester, find.text('Add witness signature'));
    await tester.enterText(find.byType(TextField), 'Uno Kahuure');
    await tester.timedDrag(
      find.byType(SignaturePad).last,
      const Offset(140, 20),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Save witness'));
    expect(find.text('Witnessed by Uno Kahuure'), findsOneWidget);
    expect(container.read(captureSessionProvider).canFinish, isTrue);
    expectNoException(tester);
  });

  testWidgets('06.5 say it records with a timer', (tester) async {
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/sign',
      session: const CaptureSession(choices: _allChosen),
    );
    await tester.tap(find.text('Say it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tap and say “I agree”'));
    await tester.pump(const Duration(milliseconds: 2100));
    expect(find.text('Recording… 0:02'), findsOneWidget);
    await tester.tap(find.text('Recording… 0:02'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recorded 0:02'), findsOneWidget);
    expect(container.read(captureSessionProvider).verbalSeconds, 2);
    expectNoException(tester);
  });

  testWidgets('06.6 feedback: choose a face, a tag and send', (tester) async {
    final container = await pumpCapture(
      tester,
      initial: '/field-capture/done',
      session: CaptureSession(
        projectId: 'water-health',
        choices: _allChosen,
        completedAt: DateTime(2026, 10, 4),
      ),
    );
    await settleDone(tester);
    expect(find.text('How was this for you?'), findsOneWidget);
    expect(find.text('Not linked to your consent answers.'), findsOneWidget);

    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voice helped'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Send feedback'));
    expect(find.text('How was this for you?'), findsNothing);
    expect(find.text('Thanks for your feedback.'), findsOneWidget);
    final saved = container.read(captureFeedbackProvider).single;
    expect(saved.rating, 3);
    expect(saved.tags, {'Voice helped'});

    await tester.tap(find.text('Hand back to researcher'));
    await tester.pumpAndSettle();
    expect(find.text('Project water-health'), findsOneWidget);
    expectNoException(tester);
  });

  testWidgets('06.6 never asks minors for feedback', (tester) async {
    await pumpCapture(
      tester,
      initial: '/field-capture/done',
      participant: const CaptureParticipant(
        code: 'P-066',
        name: 'Tuyeni Shikongo',
        project: 'Water access & health',
        site: 'Opuwo',
        isMinor: true,
      ),
    );
    await settleDone(tester);
    expect(find.text('Thank you, Tuyeni'), findsOneWidget);
    expect(find.text('How was this for you?'), findsNothing);
    expectNoException(tester);
  });

  testWidgets('every screen fits 200% text and larger targets', (tester) async {
    for (final route in [
      '/field-capture',
      '/field-capture/read',
      '/field-capture/answer',
      '/field-capture/choices',
      '/field-capture/sign',
    ]) {
      await pumpCapture(tester, initial: route, textScale: 2, large: true);
      expectNoException(tester);
    }
    await pumpCapture(
      tester,
      initial: '/field-capture/done',
      textScale: 2,
      large: true,
    );
    await settleDone(tester);
    expectNoException(tester);
    await tapVisible(tester, find.text('Skip'));
    expectNoException(tester);
  });

  testWidgets('reduce motion: no loops while listening', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpCapture(tester, initial: '/field-capture/answer');
    await tester.tap(find.text('Tap the microphone to answer'));
    // Would time out if the mic, halo or waveform kept looping.
    await tester.pumpAndSettle();
    expect(find.text('Listening… tap to stop'), findsOneWidget);
    expectNoException(tester);
  });
}
