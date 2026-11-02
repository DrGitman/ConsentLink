import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tiles/fake_drafting_tile.dart';
import 'tiles/llm_benchmark_tile.dart';
import 'tiles/llm_drafting_tile.dart';
import 'tiles/model_download_tile.dart';

/// Dev-only screen to try each AI brick on its own. Never routed in the app.
///
/// Run with `flutter run -t lib/ai/dev/ai_playground.dart`.
void main() => runApp(const ProviderScope(child: AiPlayground()));

const playgroundTitle = 'AI playground';

/// One tile per brick; each task adds its own tile here.
const playgroundTiles = <Widget>[
  FakeDraftingTile(),
  LlmBenchmarkTile(),
  LlmDraftingTile(),
  ModelDownloadTile(),
];

class AiPlayground extends StatelessWidget {
  const AiPlayground({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: playgroundTitle,
    home: Scaffold(
      appBar: AppBar(title: const Text(playgroundTitle)),
      body: ListView(children: playgroundTiles),
    ),
  );
}
