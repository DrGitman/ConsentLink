import 'dart:io';

import 'package:consentlink/ai/service/device_memory.dart';
import 'package:flutter_test/flutter_test.dart';

const _sixGbPhone = '''
MemTotal:        5750000 kB
MemFree:          200000 kB
MemAvailable:    2100000 kB
''';

void main() {
  test('reads MemTotal in bytes', () {
    expect(parseTotalMemoryBytes(_sixGbPhone), 5750000 * 1024);
  });

  test('a "6 GB" phone passes the minimum, a 4 GB phone does not', () {
    expect(
      parseTotalMemoryBytes(_sixGbPhone)!,
      greaterThan(minimumMemoryBytes),
    );
    expect(
      parseTotalMemoryBytes('MemTotal:        3700000 kB\n')!,
      lessThan(minimumMemoryBytes),
    );
  });

  test('null when MemTotal is absent', () {
    expect(parseTotalMemoryBytes('MemFree: 200000 kB\n'), isNull);
    expect(parseTotalMemoryBytes(''), isNull);
  });

  test('reads a meminfo file, null when it is missing', () async {
    final folder = await Directory.systemTemp.createTemp('meminfo_test');
    addTearDown(() => folder.delete(recursive: true));
    final file = File('${folder.path}/meminfo')..writeAsStringSync(_sixGbPhone);

    expect(await readTotalMemoryBytes(path: file.path), 5750000 * 1024);
    expect(await readTotalMemoryBytes(path: '${folder.path}/none'), isNull);
  });
}
