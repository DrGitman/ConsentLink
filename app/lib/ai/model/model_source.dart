import '../llm/llm_model_config.dart';

/// Where a model file is downloaded from, and how to check it.
final class ModelSource {
  const ModelSource({
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
  });

  final String url;
  final String fileName;
  final int sizeBytes;

  /// Lowercase hex digest of the whole file.
  final String sha256;
}

/// Gemma 4 E2B QAT Q4_0 from Google's official Hugging Face repo (D4.2),
/// pinned to a commit so the file can't change under the checksum.
/// Public, Apache 2.0: no account needed.
const gemmaModelSource = ModelSource(
  url:
      'https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/'
      '675cff42a74c774d6cb76f76d8eacb49b48c9b93/$gemmaModelFileName',
  fileName: gemmaModelFileName,
  sizeBytes: 3349516256,
  sha256: 'fa401b55b07ee70a54c6dae3903c783a6e65064312529ea57175cb5f8dec6634',
);
