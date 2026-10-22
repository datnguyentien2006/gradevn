// Bộ sinh fixture phiếu trả lời tổng hợp (chạy trong flutter test — cần dart:ui).
//
// Fixture được render từ CHÍNH SheetLayout của ứng dụng nên toạ độ ô luôn khớp
// với pipeline đọc ảnh. Đây là bộ hiệu chuẩn/hồi quy gốc của GradeVN, không
// phải bản sao phiếu của ứng dụng tham khảo.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

/// Kích thước trang fixture (A4 @150dpi ≈ 1240×1754).
const Size fixturePageSize = Size(1240, 1754);

const int _ringGray = 95;

final class FixtureDefinition {
  const FixtureDefinition({
    required this.name,
    required this.spec,
    required this.answers,
    required this.answerKey,
    required this.studentCodeRaw,
    required this.examCodeRaw,
    this.noisy = false,
  });

  final String name;
  final SheetSpec spec;

  /// Đáp án đã tô trên phiếu (null = câu để trống).
  final List<String?> answers;

  /// Đáp án đúng dùng để kiểm tra Grader.
  final String answerKey;

  /// Chuỗi 6 chữ số ở lưới số báo danh.
  final String studentCodeRaw;

  /// Chuỗi 6 chữ số ở lưới mã đề.
  final String examCodeRaw;

  /// Có phủ gradient + đốm nhiễu hay không.
  final bool noisy;

  SheetLayout get layout => SheetLayout.forSpec(spec, page: fixturePageSize);

  Map<String, Object?> toJson() => <String, Object?>{
        'name': name,
        'spec': <String, Object?>{
          'formType': spec.formType.name,
          'orientation': spec.orientation.name,
          'questionCount': spec.questionCount,
          'answerChoices': spec.answerChoices,
          'maxScore': spec.maxScore,
          'partOneCount': spec.partOneCount,
          'partTwoCount': spec.partTwoCount,
          'partThreeCount': spec.partThreeCount,
          'partOneWeight': spec.partOneWeight,
          'partTwoWeight': spec.partTwoWeight,
          'partThreeWeight': spec.partThreeWeight,
        },
        'studentCodeRaw': studentCodeRaw,
        'examCodeRaw': examCodeRaw,
        'answers': answers,
        'answerKey': answerKey,
        'expected': _expectedScores(),
      };

  /// Điểm kỳ vọng tính độc lập (số học thuần) để đối chiếu với Grader.
  Map<String, Object?> _expectedScores() {
    final key = answerKey.toUpperCase();
    var correct = 0;
    final partCorrect = <String, int>{'1': 0, '2': 0, '3': 0};
    final p1 = spec.partOneCount ?? 0;
    final p2 = spec.partTwoCount ?? 0;
    for (var i = 0; i < answers.length && i < key.length; i++) {
      if (answers[i] != null && answers[i]!.toUpperCase() == key[i]) {
        correct++;
        if (spec.formType == SheetFormType.ministry) {
          final part = i < p1 ? '1' : (i < p1 + p2 ? '2' : '3');
          partCorrect[part] = partCorrect[part]! + 1;
        }
      }
    }
    if (spec.formType == SheetFormType.ministry) {
      final scores = <String, double>{
        '1': _round2(partCorrect['1']! *
            (spec.partOneWeight ?? 0) /
            math.max(1, spec.partOneCount ?? 1)),
        '2': _round2(partCorrect['2']! *
            (spec.partTwoWeight ?? 0) /
            math.max(1, spec.partTwoCount ?? 1)),
        '3': _round2(partCorrect['3']! *
            (spec.partThreeWeight ?? 0) /
            math.max(1, spec.partThreeCount ?? 1)),
      };
      final total = _round2(scores.values.fold(0.0, (a, b) => a + b));
      return <String, Object?>{
        'score': total,
        'partScores': scores,
        'correctCount': correct,
      };
    }
    final score = _round2(correct * spec.maxScore / math.max(1, spec.questionCount));
    return <String, Object?>{
      'score': score,
      'partScores': <String, Object?>{},
      'correctCount': correct,
    };
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

FixtureDefinition standardFixture() {
  const count = 40;
  final answers = <String?>[
    for (var i = 0; i < count; i++) 'ABCD'[(i * 3 + 1) % 4],
  ];
  // Hai câu để trống để kiểm tra nhánh "bỏ trống".
  answers[5] = null;
  answers[17] = null;
  final key = <String>[
    for (var i = 0; i < count; i++) answers[i] ?? 'A',
  ];
  key[0] = 'B';
  key[12] = 'C';
  key[30] = 'D';
  return FixtureDefinition(
    name: 'standard40',
    spec: const SheetSpec(
      formType: SheetFormType.standard,
      orientation: SheetOrientation.portrait,
      questionCount: count,
      answerChoices: 4,
      maxScore: 10,
    ),
    answers: answers,
    answerKey: key.join(),
    studentCodeRaw: '000413',
    examCodeRaw: '000001',
  );
}

FixtureDefinition ministryFixture() {
  const p1 = 4;
  const p2 = 10;
  const p3 = 6;
  const total = p1 + p2 + p3;
  final answers = <String?>[
    for (var i = 0; i < total; i++) 'ABCD'[(i * 2 + 3) % 4],
  ];
  answers[2] = null;
  final key = <String>[
    for (var i = 0; i < total; i++) answers[i] ?? 'A',
  ];
  key[0] = 'D'; // Phần I sai 1
  key[7] = 'A'; // Phần II sai 1
  key[17] = 'B'; // Phần III sai 1
  return FixtureDefinition(
    name: 'ministry20',
    spec: const SheetSpec(
      formType: SheetFormType.ministry,
      orientation: SheetOrientation.portrait,
      questionCount: total,
      answerChoices: 4,
      maxScore: 10,
      partOneCount: p1,
      partTwoCount: p2,
      partThreeCount: p3,
      partOneWeight: 4,
      partTwoWeight: 5,
      partThreeWeight: 1,
    ),
    answers: answers,
    answerKey: key.join(),
    studentCodeRaw: '000888',
    examCodeRaw: '000123',
  );
}

FixtureDefinition noisyFixture() {
  const count = 40;
  final answers = <String?>[
    for (var i = 0; i < count; i++) 'ABCD'[(i * 5 + 2) % 4],
  ];
  final key = <String>[
    for (var i = 0; i < count; i++) answers[i]!,
  ];
  key[9] = answers[9] == 'A' ? 'B' : 'A';
  return FixtureDefinition(
    name: 'noisy40',
    spec: const SheetSpec(
      formType: SheetFormType.standard,
      orientation: SheetOrientation.portrait,
      questionCount: count,
      answerChoices: 4,
      maxScore: 10,
    ),
    answers: answers,
    answerKey: key.join(),
    studentCodeRaw: '000042',
    examCodeRaw: '000007',
    noisy: true,
  );
}

List<FixtureDefinition> allFixtures() => <FixtureDefinition>[
      standardFixture(),
      ministryFixture(),
      noisyFixture(),
    ];

/// Render một fixture thành PNG.
Uint8List renderFixture(FixtureDefinition fixture) {
  final image = img.Image(
    width: fixturePageSize.width.toInt(),
    height: fixturePageSize.height.toInt(),
  );
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  if (fixture.noisy) _applyGradient(image);

  final layout = fixture.layout;

  _drawDigitGrid(image, layout.studentCodeGrid, fixture.studentCodeRaw);
  _drawDigitGrid(image, layout.examCodeGrid, fixture.examCodeRaw);

  for (var q = 0; q < layout.totalQuestions; q++) {
    final block = layout.answerBlocks.firstWhere(
      (b) => q >= b.firstQuestionIndex && q < b.firstQuestionIndex + b.rows,
    );
    final row = q - block.firstQuestionIndex;
    final marked = q < fixture.answers.length ? fixture.answers[q] : null;
    final markedCol =
        marked == null ? -1 : 'ABCDEFGHIJ'.indexOf(marked.toUpperCase());
    for (var col = 0; col < block.columns; col++) {
      _drawBubble(image, block.cellRect(row, col), filled: col == markedCol);
    }
  }

  if (fixture.noisy) _applySpeckles(image, seed: 42);

  return img.encodePng(image, level: 6);
}

/// Thư mục gốc fixture (tương đối theo working dir của flutter test = project root).
const String fixturesRoot = 'test/fixtures';

/// Đảm bảo fixture PNG + JSON tồn tại trên đĩa; trả về đường dẫn PNG theo tên.
Map<String, String> ensureFixtures() {
  final pngDir = Directory('$fixturesRoot/generated')..createSync(recursive: true);
  final jsonDir = Directory('$fixturesRoot/expected')..createSync(recursive: true);
  final paths = <String, String>{};
  for (final fixture in allFixtures()) {
    final pngPath = '${pngDir.path}/${fixture.name}.png';
    File(pngPath).writeAsBytesSync(renderFixture(fixture));
    File('${jsonDir.path}/${fixture.name}.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(fixture.toJson()));
    paths[fixture.name] = pngPath;
  }
  return paths;
}

/// Đọc JSON expected đã lưu cho một fixture.
Map<String, dynamic> readExpectedJson(String name) {
  final file = File('$fixturesRoot/expected/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _drawDigitGrid(img.Image image, Rect grid, String code) {
  for (var row = 0; row < SheetLayout.digitRows; row++) {
    final digit = row < code.length ? int.tryParse(code[row]) : null;
    for (var col = 0; col < SheetLayout.digitColumns; col++) {
      final cell = SheetLayout.digitCellRect(grid, row, col);
      _drawBubble(image, cell, filled: digit != null && digit == col);
    }
  }
}

/// Vẽ một bong bóng tròn: vành xám 2px; nếu [filled] thì tô đen lõi.
void _drawBubble(img.Image image, Rect cell, {required bool filled}) {
  final cx = (cell.left + cell.width / 2).round();
  final cy = (cell.top + cell.height / 2).round();
  final radius = (math.min(cell.width, cell.height) * 0.36).round();
  final ring = img.ColorRgb8(_ringGray, _ringGray, _ringGray);
  img.drawCircle(image, x: cx, y: cy, radius: radius, color: ring);
  img.drawCircle(image, x: cx, y: cy, radius: radius - 1, color: ring);
  if (filled) {
    final fillRadius = (math.min(cell.width, cell.height) * 0.20).round();
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: fillRadius,
      color: img.ColorRgb8(0, 0, 0),
    );
  }
}

/// Gradient sáng→tối từ trái sang phải (mô phỏng bóng đổ/ánh sáng lệch).
void _applyGradient(img.Image image) {
  final w = image.width;
  final h = image.height;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final factor = 1.0 - 0.22 * (x / w);
      final p = image.getPixel(x, y);
      image.setPixelRgb(
        x,
        y,
        (p.r * factor).round().clamp(0, 255),
        (p.g * factor).round().clamp(0, 255),
        (p.b * factor).round().clamp(0, 255),
      );
    }
  }
}

/// Đốm nhiễu ngẫu nhiên (hạt bụi/nhiễu cảm biến), tất định theo seed.
void _applySpeckles(img.Image image, {required int seed}) {
  final random = math.Random(seed);
  final w = image.width;
  final h = image.height;
  final total = (w * h * 0.002).round();
  for (var i = 0; i < total; i++) {
    final x = random.nextInt(w);
    final y = random.nextInt(h);
    final v = 60 + random.nextInt(40);
    image.setPixelRgb(x, y, v, v, v);
  }
}
