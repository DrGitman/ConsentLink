# Model card: ConsentLink on-device drafting model

_Last updated: 2 November 2026. Owner: P3 (`app/lib/ai/`)._

## Summary

ConsentLink drafts an informed consent form from a research proposal **on the phone only**. The proposal never leaves the device: there is no cloud model, no fallback server and no network call at runtime. A researcher reviews and approves every section before any participant sees it.

| | |
|---|---|
| Model | Gemma 4 E2B instruction-tuned, quantization-aware trained, Q4_0 |
| File | `gemma-4-E2B_q4_0-it.gguf`, 3.35 GB, from [`google/gemma-4-E2B-it-qat-q4_0-gguf`](https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf) |
| SHA-256 | `fa401b55b07ee70a54c6dae3903c783a6e65064312529ea57175cb5f8dec6634` |
| Licence | Apache 2.0 (model) · MIT (llama.cpp, llama_cpp_dart) |
| Runtime | llama.cpp b10182 through `llama_cpp_dart` 0.9.0-dev.10, CPU, arm64-v8a, in a worker isolate |
| Not used | the vision/audio projector (`mmproj`): the app only sends text |

The model is not in the repository (`*.gguf` is ignored). For development, it is copied into the app's internal storage, `files/models/` (see `llm/llm_model_config.dart`).

## Intended use

- **Input:** the text of an accepted proposal PDF, page by page (`pdf/`).
- **Output:** JSON following [`/schemas/consent_draft.schema.json`](../../../schemas/consent_draft.schema.json). Each section has its key, plain-language text, source pages, a source quote, the list of changes and a confidence (low / medium / high).
- **Users:** researchers preparing a consent form, who must review it.
- **Target:** Grade 6 reading level, explicit rights, an invitation to ask questions, and the 10 required elements (+4 for studies with minors, Figma G).

## Out of scope

- Deciding anything for a participant, or being shown to a participant without a researcher's approval.
- Legal or ethics advice. The ethics committee remains the authority.
- Writing in local languages. Translations come from reviewed language packs (`language/`), never from the model directly.
- Scanned PDFs without a text layer: they are refused (`ScannedPdfException`).

## Safeguards around the model

The model's output is never trusted as it comes:

1. **Output parser** (`prompts/consent_output_parser.dart`): a broken JSON root is rejected. A broken section is dropped and listed as missing. Logs never quote form text.
2. **Rule checker** (`rules/rule_checker.dart`): a deterministic check of each required element (ok / missing / uncertain). For example, confidentiality must state how long data is kept, and withdrawal must say "no penalty".
3. **Readability** (`rules/readability.dart`): Flesch-Kincaid grade computed in code, not estimated by the model. `null` ("not measured") for non-English text.
4. **Human review:** every section shows its source pages and quote ("Why?" sheet) and must be approved. Editing approved text drops the approval (P2 repository rules).

## Performance on phones

Debug build, invented prompt, 64 generated tokens, 4 threads, Gemma card sampling (temperature 1.0, top-p 0.95, top-k 64). Measured with the playground benchmark tile (`dev/tiles/llm_benchmark_tile.dart`).

| Phone | SoC / RAM | Context | Load | First token | Speed | Max RSS |
|---|---|---|---|---|---|---|
| Samsung Galaxy A05 (Android 15) | Helio G85 / 3.7 GB | 2048 | 15.7 s | 43.3 s | 0.6 tok/s | 2.1 GB |
| Samsung Galaxy S20 | 8 GB+ | 2048 | 4.8 s | 3.7 s | 5.9 tok/s | 2.5 GB |
| Samsung Galaxy S20 | 8 GB+ | 4096 | 3.5 s (warm) | 3.3 s | 6.0 tok/s | 5.2 GB* |

\* Includes memory still mapped from the previous run.

**Reading:**
- **6 GB of RAM or more is required**, as stated in the README. On a 4 GB phone the model runs, but it is memory-bound (the 3.35 GB file is mmapped and re-read from storage) and too slow to use.
- On the S20, a 150-token section takes about 25 s, and a 10-section form about 4–5 minutes. That is acceptable behind the step-by-step drafting screen.
- Output quality on the benchmark prompt was correct, plain-language English on both phones.

**Not yet measured:** drafting quality on real proposals (accuracy of source quotes, missed elements, hallucinated facts), release-build speed, battery and heat. These need a set of invented test proposals and a review by the team.

## Known limitations and risks

- **Hallucination:** the model may invent facts (for example a duration or a contact) that are not in the proposal. This is why every section carries a source page and quote, and why the rule checker and the researcher's approval are required.
- **English only for checks:** keyword checks and the reading grade work only for English. Other languages are marked "uncertain / not measured", never "ok".
- **Click languages:** Khoekhoegowab and Juǀ'hoansi text (ǀ ǁ ǂ ǃ, U+01C0–U+01C3) passes through the parser, the checker and the read-aloud service unchanged (tested), but the model is not used to write it.
- **Read-aloud:** device voices exist for English, Afrikaans and German at best. Other app languages get "no audio" until human recordings exist. Only local voices are used, never network voices.
- **Context length:** long proposals must be split. 4096 tokens was the largest context measured.
- **Device support:** the llama.cpp library is arm64-v8a only, and the app requires Android 8.0+ (minSdk 26).

## Fallback options (not implemented)

- `ggml-org/gemma-4-E2B-it-GGUF` → `gemma-4-E2B-it-Q4_0.gguf` (2.84 GB, not QAT) for tighter memory.
- A smaller model (for example Qwen 3.5 0.8B) for 4 GB phones, with lower quality, to be evaluated.

## Versions

| Component | Version | Where |
|---|---|---|
| llama_cpp_dart | 0.9.0-dev.10 (last for Dart 3.8) | `app/pubspec.yaml` |
| llama.cpp AAR | v0.9.0-dev.10, sha256 `51b5f462…aafcf7` | `app/android/app/libs/` |
| pdfrx (PDFium) | 2.1.5 | `app/pubspec.yaml` |
| flutter_tts | 4.2.3 | `app/pubspec.yaml` |
| Flutter / Dart | 3.32.3 / 3.8.1 | team toolchain |
