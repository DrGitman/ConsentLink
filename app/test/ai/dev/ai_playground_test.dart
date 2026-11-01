import 'package:consentlink/ai/ai_providers.dart';
import 'package:consentlink/ai/dev/ai_playground.dart';
import 'package:consentlink/ai/dev/tiles/fake_drafting_tile.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/drafting/fake_consent_drafting_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpPlayground(WidgetTester tester) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      consentDraftingServiceProvider.overrideWithValue(
        const FakeConsentDraftingService(stepDelay: Duration.zero),
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

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text(fakeDraftingRunLabel));
    await tester.pumpAndSettle();

    expect(find.textContaining('/14 ok'), findsOneWidget);
  });
}
