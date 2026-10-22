import '../entities/sheet_spec.dart';
import 'sheet_layout.dart';

/// Ma trận mật độ mực (0..1) của một khối ô tròn.
///
/// `values[row][col]` = tỉ lệ pixel "có mực" trong vùng lõi của ô.
final class DensityBlock {
  DensityBlock(this.values)
      : assert(values.isNotEmpty, 'Khối mật độ phải có ít nhất 1 hàng'),
        assert(values.every((r) => r.isNotEmpty), 'Không được có hàng rỗng');

  final List<List<double>> values;

  int get rows => values.length;
  int get columns => values.first.length;

  double at(int row, int col) => values[row][col];
}

/// Kết quả giải mã một khối đáp án: mỗi câu → ký tự lựa chọn hoặc null (trống).
final class DecodedBlock {
  const DecodedBlock({required this.answers, required this.confidences});

  /// Mỗi phần tử là 'A'..'J' hoặc null nếu câu để trống.
  final List<String?> answers;

  /// Mật độ mực cao nhất của từng câu (dùng để hiển thị/kiểm tra độ tin cậy).
  final List<double> confidences;
}

/// Bộ giải mã mật độ mực → đáp án / chữ số.
///
/// Nguyên tắc: trong một câu, ô có mật độ mực cao nhất được chọn; nếu mật độ
/// cao nhất dưới [markThreshold] thì coi như câu để trống. Trường hợp tô nhiều
/// ô, chọn ô đậm nhất (ổn định: hoà thì chọn cột nhỏ hơn).
final class OmrDecoder {
  const OmrDecoder({this.markThreshold = 0.30});

  /// Ngưỡng mật độ tối thiểu để coi một ô là "được tô".
  final double markThreshold;

  static const String _letters = 'ABCDEFGHIJ';

  /// Giải mã toàn bộ các khối đáp án thành danh sách lựa chọn theo câu.
  ///
  /// [blocks] phải cùng thứ tự với `SheetLayout.answerBlocks`.
  List<String?> decodeAnswers({
    required List<DensityBlock> blocks,
    required SheetSpec spec,
    required int totalQuestions,
    int rowsPerAnswerBlock = 10,
  }) {
    final result = List<String?>.filled(totalQuestions, null);
    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      for (var row = 0; row < block.rows; row++) {
        final questionIndex = b * rowsPerAnswerBlock + row;
        if (questionIndex >= totalQuestions) break;
        result[questionIndex] = _decodeChoiceRow(block, row);
      }
    }
    return result;
  }

  /// Giải mã chi tiết một khối (kèm độ tin cậy từng câu).
  DecodedBlock decodeBlock(DensityBlock block) {
    final answers = <String?>[];
    final confidences = <double>[];
    for (var row = 0; row < block.rows; row++) {
      answers.add(_decodeChoiceRow(block, row));
      confidences.add(_maxOfRow(block, row));
    }
    return DecodedBlock(
      answers: List.unmodifiable(answers),
      confidences: List.unmodifiable(confidences),
    );
  }

  /// Câu [row] của khối: null nếu mọi ô đều dưới ngưỡng.
  String? _decodeChoiceRow(DensityBlock block, int row) {
    var bestCol = -1;
    var bestDensity = -1.0;
    for (var col = 0; col < block.columns; col++) {
      final d = block.at(row, col);
      if (d > bestDensity) {
        bestDensity = d;
        bestCol = col;
      }
    }
    if (bestCol < 0 || bestDensity < markThreshold) return null;
    return bestCol < _letters.length ? _letters[bestCol] : null;
  }

  double _maxOfRow(DensityBlock block, int row) {
    var best = 0.0;
    for (var col = 0; col < block.columns; col++) {
      if (block.at(row, col) > best) best = block.at(row, col);
    }
    return best;
  }

  /// Giải mã một lưới 6×10 chữ số (số báo danh hoặc mã đề).
  ///
  /// Mỗi hàng là một vị trí chữ số; cột được tô = giá trị chữ số. Hàng không
  /// xác định được trả về '?'.
  String decodeDigits(DensityBlock grid) {
    final buffer = StringBuffer();
    for (var row = 0; row < grid.rows; row++) {
      var bestCol = -1;
      var bestDensity = -1.0;
      for (var col = 0; col < grid.columns; col++) {
        final d = grid.at(row, col);
        if (d > bestDensity) {
          bestDensity = d;
          bestCol = col;
        }
      }
      buffer.write(bestCol < 0 || bestDensity < markThreshold ? '?' : '$bestCol');
    }
    return buffer.toString();
  }

  /// Chuẩn hoá mã (mã đề / số báo danh) để so khớp giữa key và phiếu.
  ///
  /// - Chuỗi toàn chữ số: bỏ các số 0 vô nghĩa ở đầu ("000001" → "1").
  /// - Chuỗi khác: trim + viết hoa.
  static String normalizeCode(String raw) {
    final cleaned = raw.trim().toUpperCase();
    if (cleaned.isEmpty) return '';
    if (RegExp(r'^\d+$').hasMatch(cleaned)) {
      final stripped = cleaned.replaceFirst(RegExp(r'^0+'), '');
      return stripped.isEmpty ? '0' : stripped;
    }
    return cleaned;
  }

  /// Số hàng của lưới chữ số (tương ứng SheetLayout.digitRows).
  static int get digitRows => SheetLayout.digitRows;
}
