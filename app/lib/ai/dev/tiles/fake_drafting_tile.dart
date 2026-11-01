import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai_exceptions.dart';
import '../../ai_providers.dart';
import '../../domain/consent_element.dart';
import '../../domain/drafting_event.dart';
import '../../drafting/consent_drafting_service.dart';

const fakeDraftingTitle = 'Fake drafting';
const fakeDraftingRunLabel = 'Run';
const fakeDraftingMinorsLabel = 'Study involves minors';

// Invented input: the fake never reads the bytes.
const _inventedFileName = 'invented_proposal.pdf';
const _inventedFileText = 'Invented proposal for the AI playground.';

/// One log line per drafting event, without any form text.
String describeDraftingEvent(DraftingEvent event) => switch (event) {
  DraftingStepStarted(:final step) => '… ${step.name}',
  DraftingStepCompleted(:final step) => '✓ ${step.name}',
  DraftingCompleted(:final draft, :final report) =>
    'Done: ${draft.sections.length} sections, '
        'missing [${draft.missing.map((e) => e.jsonKey).join(', ')}], '
        'rules ${report.found}/${report.required} ok',
};

/// Runs the drafting service from [consentDraftingServiceProvider].
class FakeDraftingTile extends ConsumerStatefulWidget {
  const FakeDraftingTile({super.key});

  @override
  ConsumerState<FakeDraftingTile> createState() => _FakeDraftingTileState();
}

class _FakeDraftingTileState extends ConsumerState<FakeDraftingTile> {
  final _lines = <String>[];
  StreamSubscription<DraftingEvent>? _subscription;
  bool _involvesMinors = false;

  bool get _running => _subscription != null;

  void _run() {
    final request = DraftingRequest(
      fileBytes: Uint8List.fromList(utf8.encode(_inventedFileText)),
      fileName: _inventedFileName,
      profile: StudyProfile.fromInvolvesMinors(_involvesMinors),
    );
    final stopwatch = Stopwatch()..start();
    setState(() {
      _lines.clear();
      _subscription = ref
          .read(consentDraftingServiceProvider)
          .draft(request)
          .listen(
            (event) => setState(() => _lines.add(describeDraftingEvent(event))),
            onError: (Object error) => setState(
              () => _lines.add(
                error is ConsentAiException ? '✗ $error' : '✗ unexpected',
              ),
            ),
            onDone: () => setState(() {
              _lines.add('${stopwatch.elapsedMilliseconds} ms');
              _subscription = null;
            }),
          );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fakeDraftingTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            title: const Text(fakeDraftingMinorsLabel),
            value: _involvesMinors,
            onChanged: _running
                ? null
                : (value) => setState(() => _involvesMinors = value),
          ),
          FilledButton(
            onPressed: _running ? null : _run,
            child: const Text(fakeDraftingRunLabel),
          ),
          for (final line in _lines) Text(line),
        ],
      ),
    ),
  );
}
