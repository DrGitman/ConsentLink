import 'dart:developer' show log;
import 'dart:io';

/// A phone sold as "6 GB" reports about 5.5 GiB; below that, drafting is
/// too slow to use (task 4 benchmark, Samsung A05).
const minimumMemoryBytes = 5 * 1024 * 1024 * 1024;

const _memInfoPath = '/proc/meminfo';
const _bytesPerKilobyte = 1024;
const _logName = 'ai.service';
final _memTotalLine = RegExp(r'^MemTotal:\s+(\d+)\s+kB', multiLine: true);

/// Total RAM of the device from `/proc/meminfo` (Android, Linux), or null
/// when it can't be read.
Future<int?> readTotalMemoryBytes({String path = _memInfoPath}) async {
  try {
    return parseTotalMemoryBytes(await File(path).readAsString());
  } on FileSystemException catch (error) {
    log('Cannot read $path: ${error.message}', name: _logName);
    return null;
  }
}

/// The `MemTotal` of a `/proc/meminfo` text in bytes, or null if absent.
int? parseTotalMemoryBytes(String memInfo) {
  final kilobytes = _memTotalLine.firstMatch(memInfo)?.group(1);
  return kilobytes == null ? null : int.parse(kilobytes) * _bytesPerKilobyte;
}
