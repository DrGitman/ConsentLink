import 'dart:io';

import 'package:consentlink/ai/ai_providers.dart';
import 'package:consentlink/ai/dev/ai_playground.dart';
import 'package:consentlink/ai/dev/tiles/fake_drafting_tile.dart';
import 'package:consentlink/ai/dev/tiles/llm_drafting_tile.dart';
import 'package:consentlink/ai/dev/tiles/model_download_tile.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/drafting/fake_consent_drafting_service.dart';
import 'package:consentlink/ai/model/model_download_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> _pumpPlayground(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      consentDraftingServiceProvider.overrideWithValue(
        const FakeConsentDraftingService(stepDelay: Duration.zero),
      ),
      // No network and an empty folder: the tile must show "not downloaded".
      modelDownloadServiceProvider.overrideWithValue(
        ModelDownloadService(
          client: MockClient(
            (_) async => http.Response('', HttpStatus.notFound),
          ),
          modelsFolder: () async =>
              Directory('${Directory.systemTemp.path}/no_model_here'),
        ),
      ),
    ],
    child: const AiPlayground(),
  ),
);

void main() {
  test('describes a step without any form text', () {
    expect(
      describeDraftingEvent(
        const DraftingStepCompleted(DraftingStep.readingPages),
      ),
      '✓ readingPages',
    );
  });

  testWidgets('shows the LLM drafting tile, ready to run', (tester) async {
    await _pumpPlayground(tester);
    await tester.scrollUntilVisible(find.text(llmDraftingRunLabel), 200);

    expect(find.text(llmDraftingTitle), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text(llmDraftingRunLabel),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('the model download tile shows the model is absent', (
    tester,
  ) async {
    await _pumpPlayground(tester);
    await tester.scrollUntilVisible(find.text(modelDownloadTitle), 200);
    await tester.pump();

    expect(find.text(modelAbsentText), findsOneWidget);
    final download = find.ancestor(
      of: find.text(modelDownloadRunLabel),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(download).onPressed, isNotNull);
    expect(find.text(modelDownloadDeleteLabel), findsOneWidget);
  });

  testWidgets('fake drafting shows every step, then the result', (
    tester,
  ) async {
    await _pumpPlayground(tester);

    await tester.tap(find.text(fakeDraftingRunLabel));
    await tester.pumpAndSettle();

    for (final step in DraftingStep.values) {
      expect(find.text('✓ ${step.name}'), findsOneWidget);
    }
    expect(find.textContaining('rules 9/10 ok'), findsOneWidget);
    expect(find.textContaining('[contacts_ethics]'), findsOneWidget);
  });

  testWidgets('the minors switch checks the 14 elements', (tester) async {
    await _pumpPlayground(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(FakeDraftingTile),
        matching: find.byType(Switch),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(fakeDraftingRunLabel));
    await tester.pumpAndSettle();

    expect(find.textContaining('/14 ok'), findsOneWidget);
  });
}
