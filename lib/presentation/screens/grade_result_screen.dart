// Màn KẾT QUẢ tức thời sau chụp (R4 + tinh chỉnh R13):
// - Header: nút tròn aqua (quay lại) thẳng hàng với "Mã đề {code}" +
//   dòng "{đúng} / {tổng} = {điểm,2 chữ số kiểu vi}". Nút info đã bỏ.
// - Thân: ảnh phiếu ĐÃ NẮN (grayscale) phủ VÀNH TRÒN màu theo kết quả:
//   xanh lá = đúng, ĐỎ = sai, VÀNG = bỏ trống (yêu cầu người dùng);
//   lưới số/SBD: ô đọc được vành xanh, không đọc được vành cam.
//   Khung ngoài có viền aqua nhạt #80DEEA bo góc 16.
// - Card "Cảnh báo" giữa màn (nền trắng nhạt, dòng vàng nhạt):
//   Trùng SBD / Mã đề / Nhiều đáp án / Không trả lời / Sai quy chế.
// - 2 nút dưới: "CHỤP LẠI" (pop về camera) và "GIỮ" (lưu DB → về chi tiết
//   kỳ thi) — viền xanh #00FF66. Quay lại/lưu điều hướng trả về
//   camera/chi tiết.
// R13 (yêu cầu người dùng): nút ← aqua nhỏ 40, bỏ nút i + legend; viền
// khung ảnh #80DEEA; card Cảnh báo nền sáng #F5FAFA, tiêu đề đỏ, dòng
// thanh vàng nhạt #FFF3C4 chữ #8A6100; CHỤP LẠI/GIỮ viền #00FF66.
// Camera R11 giữ nguyên.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gradevn/l10n/generated/app_localizations.dart';

import '../../data/cv/scan_flow.dart' show GradedScan;
import '../../domain/entities/contest.dart';
import '../../domain/entities/graded_sheet.dart';
import '../../domain/services/omr_decoder.dart';
import '../../domain/services/sheet_layout.dart';

const _kAqua = Color(0xFF00BCD4); // nút ← nền tròn header
const _kAquaBorder = Color(0xFF80DEEA); // viền khung ảnh phiếu
const _kWarnBg = Color(0xEBF5FAFA); // nền card Cảnh báo (trắng nhạt ~92%)
const _kWarnTitle = Color(0xFFE53935); // tiêu đề "Cảnh báo"
const _kWarnItemBg = Color(0xFFFFF3C4); // thanh nền vàng nhạt từng dòng
const _kWarnItemText = Color(0xFF8A6100); // chữ vàng đậm/nâu vàng trong thanh
const _kActionGreen = Color(0xFF00FF66); // CHỤP LẠI / GIỮ
const _green = Color(0xFF1E8E3E);
const _red = Color(0xFFDB4437);
const _yellow = Color(0xFFF9AB00);

/// Hàng cảnh báo trong card "Cảnh báo".
final class _WarnRow {
  const _WarnRow(this.label, this.value);

  final String label;
  final String value;
}

final class GradeResultScreen extends StatefulWidget {
  const GradeResultScreen({
    super.key,
    required this.graded,
    required this.contest,
    required this.layout,
    required this.previousSheets,
    required this.onSave,
  });

  final GradedScan graded;
  final Contest contest;
  final SheetLayout layout;

  /// Phiếu đã chấm TRƯỚC ĐÓ của cùng kỳ thi — kiểm tra "Trùng SBD".
  final List<GradedSheet> previousSheets;

  /// Lưu DB (dồn cho ScanScreen; KHÔNG pop trong callback).
  final Future<bool> Function() onSave;

  @override
  State<GradeResultScreen> createState() => _GradeResultScreenState();
}

final class _GradeResultScreenState extends State<GradeResultScreen> {
  bool _saving = false;

  /// "GIỮ": lưu DB rồi về chi tiết kỳ thi (pop cả màn kết quả lẫn camera).
  /// Thu Navigator TRƯỚC async gap (lint use_build_context_synchronously).
  Future<void> _keep() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final ok = await widget.onSave();
    if (!mounted) return;
    if (ok) {
      navigator
        ..pop() // màn kết quả
        ..pop(); // màn camera → chi tiết kỳ thi
    } else {
      setState(() => _saving = false);
    }
  }

  bool _isDuplicateStudent(GradedScan graded, List<GradedSheet> previous) {
    if (!graded.graded) return false;
    if (graded.student != null) {
      return previous.any((s) => s.studentId == graded.student!.id);
    }
    final code = OmrDecoder.normalizeCode(graded.photo.scan.studentCodeRaw);
    if (code.isEmpty) return false;
    return previous.any(
      (s) => s.studentCode.isNotEmpty && OmrDecoder.normalizeCode(s.studentCode) == code,
    );
  }

  List<_WarnRow> _warningRows(AppLocalizations l10n) {
    final graded = widget.graded;
    final scan = graded.photo.scan;
    final rows = <_WarnRow>[
      _WarnRow(
        l10n.warnDuplicateLabel,
        _isDuplicateStudent(graded, widget.previousSheets)
            ? l10n.warnDuplicateYes
            : l10n.warnDuplicateNone,
      ),
      _WarnRow(
        l10n.resultExamCodeLabel,
        graded.usedKey?.examCode ?? graded.usedExamCode,
      ),
    ];
    if (graded.usedBestGuessKey) {
      rows.add(_WarnRow(
          l10n.resultExamCodeLabel, l10n.resultBestGuessNote));
    }
    if (graded.multiAnswerCount > 0) {
      rows.add(_WarnRow(
        l10n.warnMultiLabel,
        l10n.warnMultiValue(graded.multiAnswerCount),
      ));
    }
    if (graded.result.unansweredCount > 0) {
      rows.add(_WarnRow(
        l10n.warnBlankLabel,
        l10n.warnBlankValue(graded.result.unansweredCount),
      ));
    }
    final unreadable =
        scan.studentCodeRaw.contains('?') || scan.examCodeRaw.contains('?');
    if (unreadable ||
        (!graded.graded && graded.ungradedReason != null)) {
      rows.add(_WarnRow(l10n.warnIrregularLabel, l10n.warnIrregularValue));
    }
    return rows;
  }

  String _scoreLine(AppLocalizations l10n) {
    final graded = widget.graded;
    if (!graded.graded) return l10n.resultNullScore;
    final correct = graded.result.correctCount;
    final total = widget.contest.sheetSpec.questionCount;
    final score = graded.result.score.toStringAsFixed(2).replaceFirst('.', ',');
    return '$correct / $total = $score';
  }

  /// Style chung cho CHỤP LẠI / GIỮ: viền xanh #00FF66, chữ xanh,
  /// bo góc 13, nền trong suốt.
  ButtonStyle _actionButtonStyle() => OutlinedButton.styleFrom(
        foregroundColor: _kActionGreen,
        side: const BorderSide(color: _kActionGreen, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final graded = widget.graded;
    final examCode = graded.usedExamCode.isEmpty
        ? '—'
        : graded.usedExamCode.padLeft(3, '0');
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF232326),
      body: Column(
        children: [
          // ----------------------------------------------------------------
          // HEADER: nút quay lại (aqua, nhỏ) thẳng hàng với
          // "Mã đề {code}" + dòng điểm. Nút info đã bỏ (R13).
          // ----------------------------------------------------------------
          Padding(
            padding: EdgeInsets.fromLTRB(12, safeTop + 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _RoundHeaderButton(
                  icon: Icons.arrow_back,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.resultExamCodeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Text(
                            examCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _scoreLine(l10n),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ----------------------------------------------------------------
          // THÂN: ảnh phiếu nắn phẳng + vành tròn màu kết quả (CustomPaint),
          // phủ card "Warning!!!" giữa màn như ảnh tham chiếu TNMaker.
          // ----------------------------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _GradedSheetView(
                    layout: widget.layout,
                    imageBytes: graded.photo.warpedBytes,
                    correctFlags: graded.result.correctFlags,
                    answers: graded.photo.scan.answers,
                    studentCodeRaw: graded.photo.scan.studentCodeRaw,
                    examCodeRaw: graded.photo.scan.examCodeRaw,
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: _WarningCard(rows: _warningRows(l10n)),
                  ),
                ],
              ),
            ),
          ),
          // ----------------------------------------------------------------
          // FOOTER: CHỤP LẠI | GIỮ — 2 nút viền xanh #00FF66, bằng nhau
          // chia đều trong thanh đáy.
          // ----------------------------------------------------------------
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(), // về camera
                      style: _actionButtonStyle(),
                      child: Text(l10n.gradeResultRetake),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : _keep,
                      style: _actionButtonStyle(),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kActionGreen),
                            )
                          : Text(l10n.gradeResultKeep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card "Cảnh báo" giữa màn: nền trắng nhạt hơi trong (~92%) bo tròn,
/// tiêu đề đỏ đậm căn giữa, từng dòng là thanh nền vàng nhạt với chữ
/// nâu vàng (#8A6100) đọc rõ trên nền sáng.
final class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.rows});

  final List<_WarnRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: _kWarnBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.warnTitle,
            style: const TextStyle(
              color: _kWarnTitle,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _kWarnItemBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: _kWarnItemText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 190),
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          color: _kWarnItemText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nút tròn header — nền aqua #00BCD4, đường kính 40 (R13: thu nhỏ,
/// chỉ còn nút quay lại).
final class _RoundHeaderButton extends StatelessWidget {
  const _RoundHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _kAqua,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

/// Ảnh phiếu nắn phẳng + VÀNH TRÒN màu theo kết quả — CustomPaint đè lên
/// Image (fit contain). Toạ độ trang chuẩn ([SheetLayout]) scale theo vùng
/// hiển thị image thực tế (applyBoxFit contain).
final class _GradedSheetView extends StatelessWidget {
  const _GradedSheetView({
    required this.layout,
    required this.imageBytes,
    required this.correctFlags,
    required this.answers,
    required this.studentCodeRaw,
    required this.examCodeRaw,
  });

  final SheetLayout layout;
  final Uint8List imageBytes;
  final List<bool?> correctFlags;
  final List<String?> answers;
  final String studentCodeRaw;
  final String examCodeRaw;

  @override
  Widget build(BuildContext context) {
    return Container(
      // R13: khung VIỀN ngoài quanh vùng ảnh phiếu — aqua nhạt #80DEEA,
      // 1.5px, bo góc 16 (chỉ khung ngoài, không đụng card Cảnh báo bên trong).
      decoration: BoxDecoration(
        border: Border.all(color: _kAquaBorder, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5), // 16 trừ bề dày viền
        child: LayoutBuilder(builder: (context, constraints) {
          // Vùng image thực tế: aspect-fit contain của trang chuẩn.
          final fs = applyBoxFit(
            BoxFit.contain,
            SheetLayout.standardPage,
            constraints.biggest,
          );
          final dest = fs.destination;
          final origin = Offset(
            (constraints.biggest.width - dest.width) / 2,
            (constraints.biggest.height - dest.height) / 2,
          );
          final displayRect = origin & dest;
          return Stack(
            children: [
              Positioned.fromRect(
                rect: displayRect,
                child: Image.memory(imageBytes, fit: BoxFit.fill),
              ),
              Positioned.fromRect(
                rect: displayRect,
                child: IgnorePointer(
                  child: CustomPaint(
                    size: dest,
                    painter: _GradeOverlayPainter(
                      layout: layout,
                      correctFlags: correctFlags,
                      answers: answers,
                      studentCodeRaw: studentCodeRaw,
                      examCodeRaw: examCodeRaw,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Vằn tròn kết quả — toạ độ TRANG CHUẨN (layout) → px hiển thị.
final class _GradeOverlayPainter extends CustomPainter {
  const _GradeOverlayPainter({
    required this.layout,
    required this.correctFlags,
    required this.answers,
    required this.studentCodeRaw,
    required this.examCodeRaw,
  });

  final SheetLayout layout;
  final List<bool?> correctFlags;
  final List<String?> answers;
  final String studentCodeRaw;
  final String examCodeRaw;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / layout.page.width;
    Offset map(Offset p) => Offset(p.dx * scale, p.dy * scale);

    void ring(Rect cell, Color color, double widthFactor) {
      final c = map(cell.center);
      final r = math.min(cell.width, cell.height) * 0.62 * scale;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * widthFactor
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(c, r, paint);
    }

    // Lưới số (SBD + Mã đề): ô đọc được → vành xanh; không đọc được ('?')
    // → vành cam cả lưới slot.
    void digitGrid(DigitGridGeometry g, String raw) {
      for (var slot = 0; slot < g.slots; slot++) {
        final parsed = slot < raw.length ? int.tryParse(raw[slot]) : null;
        final unreadable = slot < raw.length && raw[slot] == '?';
        if (parsed != null) {
          ring(g.cellRect(slot, parsed), _green, 0.09);
        } else if (unreadable) {
          ring(g.cellRect(slot, 0), const Color(0xFFF57C00), 0.09);
        }
      }
    }

    digitGrid(layout.studentCodeGrid, studentCodeRaw);
    digitGrid(layout.examCodeGrid, examCodeRaw);

    // Bong bóng đáp án: chọn = ô được decode (col theo chữ cái) và vành
    // màu theo cờ chấm; bỏ trống → vành VÀNG ô đầu hàng (yêu cầu người dùng).
    const letters = 'ABCDEFGHIJ';
    for (var q = 0; q < layout.totalQuestions; q++) {
      if (q >= correctFlags.length) break;
      final flag = correctFlags[q];
      AnswerBlockGeometry? block;
      var row = 0;
      for (final b in layout.answerBlocks) {
        if (q >= b.firstQuestionIndex && q < b.firstQuestionIndex + b.rows) {
          block = b;
          row = q - b.firstQuestionIndex;
          break;
        }
      }
      if (block == null) continue;
      if (flag == null) {
        ring(block.cellRect(row, 0), _yellow, 0.10);
        continue;
      }
      var col = 0;
      final chosen = q < answers.length ? answers[q] : null;
      final idx = chosen == null ? -1 : letters.indexOf(chosen);
      if (idx >= 0) col = idx;
      ring(block.cellRect(row, col), flag ? _green : _red, 0.10);
    }
  }

  @override
  bool shouldRepaint(_GradeOverlayPainter oldDelegate) => false;
}
