import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixture_builder.dart';

/// Test sinh fixture: bảo đảm PNG + JSON sidecar tồn tại và hợp lệ.
void main() {
  test('sinh và kiểm tra fixture PNG + JSON', () {
    final paths = ensureFixtures();
    expect(paths.length, 3);

    for (final entry in paths.entries) {
      final pngFile = File(entry.value);
      expect(pngFile.existsSync(), isTrue, reason: 'Thiếu PNG ${entry.value}');
      final png = pngFile.readAsBytesSync();
      expect(png.length, greaterThan(2000));
      // Chữ ký PNG: 89 50 4E 47
      expect(png.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);

      final json = readExpectedJson(entry.key);
      expect(json['name'], entry.key);
      expect(json['studentCodeRaw'], isA<String>());
      expect(json['examCodeRaw'], isA<String>());
      expect((json['answers'] as List<dynamic>).isNotEmpty, isTrue);
      expect((json['answerKey'] as String).isNotEmpty, isTrue);
      expect(json['expected'], isA<Map<String, dynamic>>());
    }
  });
}
