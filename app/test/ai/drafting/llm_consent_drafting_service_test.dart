import 'dart:typed_data';

import 'package:consentlink/ai/ai_exceptions.dart';
import 'package:consentlink/ai/domain/consent_element.dart';
import 'package:consentlink/ai/domain/drafting_event.dart';
import 'package:consentlink/ai/domain/rule_report.dart';
import 'package:consentlink/ai/drafting/consent_drafting_service.dart';
import 'package:consentlink/ai/drafting/llm_consent_drafting_service.dart';
import 'package:consentlink/ai/llm/llm_model_config.dart';
import 'package:consentlink/ai/llm/llm_runtime.dart';
import 'package:consentlink/ai/pdf/proposal_page.dart';
import 'package:consentlink/ai/pdf/proposal_text_extractor.dart';
import 'package:consentlink/ai/rules/readability.dart';
import 'package:flutter_test/flutter_test.dart';

// Invented proposal page; with no keyword hit, page 1 is always selected.
const _givenPage = 1;
const _notGivenPage = 9;

final class _FakeExtractor implements ProposalTextExtractor {
  _FakeExtractor([this.error]);

  final ConsentAiException? error;

  @override
  Future<List<ProposalPage>> extract(Uint8List bytes) async {
    if (error case final error?) throw error;
    return [ProposalPage(pageNumber: _givenPage, text: 'Invented study.')];
  }
}

/// Answers each call with [answer]; records the element key of each call.
final class _FakeRuntime implements LlmRuntime {
  _FakeRuntime(this.answer);

  final String Function(String key, int attempt) answer;
  final calls = <String>[];

  @override
  Stream<String> generate(LlmPrompt prompt) async* {
    final key = RegExp(r'Element key: (\w+)').firstMatch(prompt.user)![1]!;
    calls.add(key);
    yield answer(key, calls.where((call) => call == key).length);
  }

  @override
  Future<void> load(LlmModelConfig config) async {}

  @override
  Future<void> dispose() async {}
}

String _sectionAnswer(String key, {int page = _givenPage}) =>
    '{"form_language":"en","reading_grade":null,"sections":[{"key":"$key",'
    '"title":"About $key","text":"You will hear about $key. You can ask us '
    'anything. Taking part is your choice. You can stop at any time.",'
    '"source_pages":[$page],"source_quote":"Invented study.","changes":[],'
    '"confidence":"high"}],"missing":[]}';

String _missingAnswer(String key) =>
    '{"form_language":"en","reading_grade":null,"sections":[],'
    '"missing":["$key"]}';

DraftingRequest _request(StudyProfile profile) => DraftingRequest(
  fileBytes: Uint8List.fromList(const [1]),
  fileName: 'invented.pdf',
  profile: profile,
);

Future<List<DraftingEvent>> _run(
  _FakeRuntime runtime, {
  StudyProfile profile = StudyProfile.standard,
}) => LlmConsentDraftingService(
  extractor: _FakeExtractor(),
  runtime: runtime,
).draft(_request(profile)).toList();

DraftingCompleted _completed(List<DraftingEvent> events) =>
    events.last as DraftingCompleted;

RuleItem _itemOf(DraftingCompleted completed, ConsentElement element) =>
    completed.report.items.singleWhere((item) => item.element == element);

void main() {
  test('emits each step in order, then the draft and its report', () async {
    final runtime = _FakeRuntime((key, _) => _sectionAnswer(key));
    final events = await _run(runtime);

    expect(events.take(events.length - 1), [
      for (final step in DraftingStep.values) ...[
        DraftingStepStarted(step),
        DraftingStepCompleted(step),
      ],
    ]);
    final draft = _completed(events).draft;
    final standard = requiredElementsFor(StudyProfile.standard);
    expect(draft.sections.map((section) => section.element), standard);
    expect(draft.missing, isEmpty);
    expect(draft.readingGrade, draftReadingGrade(draft.sections, 'en'));
    expect(_completed(events).report.required, standard.length);
    expect(runtime.calls, standard.map((element) => element.jsonKey));
  });

  test('drafts the 4 extra elements for a study with minors', () async {
    final runtime = _FakeRuntime((key, _) => _sectionAnswer(key));
    final events = await _run(runtime, profile: StudyProfile.minors);

    expect(
      _completed(events).draft.sections,
      hasLength(requiredElementsFor(StudyProfile.minors).length),
    );
  });

  test('a clean "missing" answer is kept without a retry', () async {
    final runtime = _FakeRuntime(
      (key, _) => key == 'risks' ? _missingAnswer(key) : _sectionAnswer(key),
    );
    final completed = _completed(await _run(runtime));

    expect(completed.draft.missing, [ConsentElement.risks]);
    expect(completed.failed, isEmpty);
    expect(_itemOf(completed, ConsentElement.risks).status, RuleStatus.missing);
    expect(runtime.calls.where((key) => key == 'risks'), hasLength(1));
  });

  group('retries once, then marks the element failed', () {
    for (final (name, broken) in [
      ('invalid JSON', (String key) => 'not json'),
      ('a dropped section', (String key) => _sectionAnswer('unknown_key')),
      (
        'a page not given',
        (String key) => _sectionAnswer(key, page: _notGivenPage),
      ),
    ]) {
      test('$name, then a valid answer', () async {
        final runtime = _FakeRuntime(
          (key, attempt) => key == 'duration' && attempt == 1
              ? broken(key)
              : _sectionAnswer(key),
        );
        final completed = _completed(await _run(runtime));

        expect(completed.draft.missing, isEmpty);
        expect(completed.failed, isEmpty);
        expect(runtime.calls.where((key) => key == 'duration'), hasLength(2));
      });

      test('$name twice', () async {
        final runtime = _FakeRuntime(
          (key, _) => key == 'duration' ? broken(key) : _sectionAnswer(key),
        );
        final completed = _completed(await _run(runtime));

        expect(completed.draft.missing, [ConsentElement.duration]);
        expect(completed.failed, [ConsentElement.duration]);
        expect(
          _itemOf(completed, ConsentElement.duration).status,
          RuleStatus.uncertain,
        );
        expect(
          runtime.calls.where((key) => key == 'duration'),
          hasLength(maxAttemptsPerElement),
        );
      });
    }
  });

  test('a runtime failure stops drafting', () async {
    final runtime = _FakeRuntime(
      (key, _) => throw const LlmException('Load the model first.'),
    );

    await expectLater(
      LlmConsentDraftingService(
        extractor: _FakeExtractor(),
        runtime: runtime,
      ).draft(_request(StudyProfile.standard)),
      emitsThrough(emitsError(isA<LlmException>())),
    );
    expect(runtime.calls, hasLength(1));
  });

  test('an extraction failure is an error after the first step', () async {
    final service = LlmConsentDraftingService(
      extractor: _FakeExtractor(const ScannedPdfException('No text.')),
      runtime: _FakeRuntime((key, _) => _sectionAnswer(key)),
    );

    await expectLater(
      service.draft(_request(StudyProfile.standard)),
      emitsInOrder([
        const DraftingStepStarted(DraftingStep.readingPages),
        emitsError(isA<ScannedPdfException>()),
      ]),
    );
  });
}
