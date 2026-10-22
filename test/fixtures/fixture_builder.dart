// Bộ sinh fixture phiếu trả lời tổng hợp (chạy trong flutter test — cần dart:ui).
//
// Fixture được render từ CHÍNH SheetLayout + SheetTemplate của ứng dụng
// (hình học khung mốc đo từ PhieuTN40cau.jpg) nên toạ độ ô luôn khớp với
// pipeline đọc ảnh. Đây là bộ hiệu chuẩn/hồi quy gốc của GradeVN.
//
// Ghi chú R1: phiếu "bộ đề" (ministry20) đã bị loại khỏi bộ fixture — template
// in thật của dạng đó người dùng sẽ cung cấp sau; logic chấm nhiều phần vẫn
// được kiểm tra bằng test tổng hợp (grader_test.dart).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:gradevn/data/cv/sheet_painter.dart';
import 'package:gradevn/domain/entities/sheet_spec.dart';
import 'package:gradevn/domain/services/sheet_layout.dart';
import 'package:image/image.dart' as img;

/// Trang chuẩn xử lý của pipeline (marker frame × 0.5 = 1156×1705).
final Size fixturePageSize = SheetLayout.standardPage;

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

  /// Chuỗi chữ số in trên lưới số báo danh (6 lưới của template TN40).
  final String studentCodeRaw;

  /// Chuỗi chữ số in trên lưới mã đề (3 lưới).
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
    for (var i = 0; i < answers.length && i < key.length; i++) {
      if (answers[i] != null && answers[i]!.toUpperCase() == key[i]) {
        correct++;
      }
    }
    final score =
        _round2(correct * spec.maxScore / math.max(1, spec.questionCount));
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
    examCodeRaw: '001',
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
    examCodeRaw: '007',
    noisy: true,
  );
}

List<FixtureDefinition> allFixtures() => <FixtureDefinition>[
      standardFixture(),
      noisyFixture(),
    ];

/// Render một fixture thành PNG: phiếu quét chuẩn (mốc + bong bóng + chữ số)
/// rồi tô đen các ô đã "tô phấn" theo đáp án.
Uint8List renderFixture(FixtureDefinition fixture) {
  final layout = fixture.layout;
  final image = img.decodePng(renderScanSheet(layout))!;

  // Tô lưới chữ số: mật độ block là [lưới][giá trị]; code theo chuỗi.
  void digitGrid(DigitGridGeometry grid, String code) {
    for (var slot = 0; slot < grid.slots; slot++) {
      final digit = slot < code.length ? int.tryParse(code[slot]) : null;
      if (digit == null) continue;
      drawBubble(image, grid.cellRect(slot, digit), filled: true);
    }
  }

  digitGrid(layout.studentCodeGrid, fixture.studentCodeRaw);
  digitGrid(layout.examCodeGrid, fixture.examCodeRaw);

  for (var q = 0; q < layout.totalQuestions; q++) {
    final block = layout.answerBlocks.firstWhere(
      (b) => q >= b.firstQuestionIndex && q < b.firstQuestionIndex + b.rows,
    );
    final row = q - block.firstQuestionIndex;
    final marked = q < fixture.answers.length ? fixture.answers[q] : null;
    final markedCol =
        marked == null ? -1 : 'ABCDEFGHIJ'.indexOf(marked.toUpperCase());
    if (markedCol >= 0) {
      drawBubble(image, block.cellRect(row, markedCol), filled: true);
    }
  }

  if (fixture.noisy) {
    _applyGradient(image);
    _applySpeckles(image, seed: 42);
  }

  return img.encodePng(image, level: 6);
}

/// Thư mục gốc fixture (tương đối theo working dir của flutter test = project root).
const String fixturesRoot = 'test/fixtures';

/// Đảm bảo fixture PNG + JSON tồn tại trên đĩa; trả về đường dẫn PNG theo tên.
Map<String, String> ensureFixtures() {
  final pngDir = Directory('$fixturesRoot/generated')..createSync(recursive: true);
  final jsonDir = Directory('$fixturesRoot/expected')..createSync(recursive: true);
  // Dọn fixture cũ đã lỗi thời (ministry20 của bố cục M2).
  for (final dir in [pngDir, jsonDir]) {
    for (final stale in [
      '${dir.path}/ministry20.png',
      '${dir.path}/ministry20.json',
    ]) {
      final f = File(stale);
      if (f.existsSync()) f.deleteSync();
    }
  }
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
