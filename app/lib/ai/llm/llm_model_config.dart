import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../ai_exceptions.dart';

/// Gemma 4 E2B, QAT Q4_0, from google/gemma-4-E2B-it-qat-q4_0-gguf (D4.2).
const gemmaModelFileName = 'gemma-4-E2B_q4_0-it.gguf';

/// Folder in the app's internal storage where the model is copied.
const modelsFolderName = 'models';

/// Context sizes the benchmark compares; 2048 fits a 4 GB phone (D4.6).
const smallContextSize = 2048;
const largeContextSize = 4096;

/// Helio G85 class phones have 2 fast cores and 6 slow ones.
const defaultThreadCount = 4;

/// Where and how to load the on-device model.
final class LlmModelConfig {
  /// Throws an [ArgumentError] for a blank path or a size below 1.
  LlmModelConfig({
    required this.modelPath,
    this.contextSize = smallContextSize,
    this.threadCount = defaultThreadCount,
  }) {
    if (modelPath.trim().isEmpty) {
      throw ArgumentError.value(modelPath, 'modelPath', 'Is blank');
    }
    if (contextSize < 1) {
      throw RangeError.value(contextSize, 'contextSize', 'Must be >= 1');
    }
    if (threadCount < 1) {
      throw RangeError.value(threadCount, 'threadCount', 'Must be >= 1');
    }
  }

  final String modelPath;
  final int contextSize;
  final int threadCount;
}

/// Path of the model in the app's internal `files/models` folder.
///
/// Internal, because Android 11+ hides files that adb puts in the external
/// app folder. Throws a [ModelNotFoundException] if it is not there.
Future<String> deviceModelPath() async {
  final folder = await getApplicationSupportDirectory();
  final path = '${folder.path}/$modelsFolderName/$gemmaModelFileName';
  if (!File(path).existsSync()) {
    throw const ModelNotFoundException(
      'The model is not on this phone. Copy $gemmaModelFileName to the '
      "app's internal files/$modelsFolderName folder.",
    );
  }
  return path;
}
