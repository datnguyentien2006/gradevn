// Temporary script: fill PhieuTN40cau.jpg for student SBD 000413, exam code 001.
// Detects the 4 corner markers for an exact template->image mapping, then
// fills black discs on SBD grid, exam-code grid and the 40 answer bubbles.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const double frameWidth = 2311;
const double frameHeight = 3409;
const double markerSide = 87.0;
const double fillRadius = 37.0;

const List<double> sbdCols = [308.5, 402.0, 495.5, 589.0, 682.5, 776.0];
const List<double> examCols = [978.5, 1072.0, 1165.5];

class AnswerGroup {
  final int firstQuestion; // 0-based
  final List<double> colX;
  final double row0Y;
  final double rowPitch;
  const AnswerGroup(this.firstQuestion, this.colX, this.row0Y, this.rowPitch);
}

const groups = <AnswerGroup>[
  AnswerGroup(0, [1552.0, 1645.5, 1739.0, 1832.5], 1008.5, 108.6),
  AnswerGroup(10, [405.5, 498.3, 591.2, 684.0], 2207.0, 108.7),
  AnswerGroup(20, [978.5, 1071.8, 1165.2, 1258.5], 2207.0, 108.7),
  AnswerGroup(30, [1552.0, 1645.5, 1739.0, 1832.5], 2207.0, 108.7),
];

int digitRowY(int value) => (1008.5 + value * 108.6).round();

void main(List<String> args) {
  final srcPath = r'C:\Marker-td\PhieuTN40cau.jpg';
  final outPath = r'C:\Marker-td\PhieuTN40cau_001_000413.jpg';

  final bytes = File(srcPath).readAsBytesSync();
  final image = img.decodeImage(bytes)!;
  final w = image.width;
  final h = image.height;
  stdout.writeln('Image: $w x $h');

  final gray = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      gray[y * w + x] = img.getLuminance(image.getPixel(x, y)).toInt();
    }
  }

  bool isDark(int x, int y) =>
      x >= 0 && y >= 0 && x < w && y < h && gray[y * w + x] < 128;

  int darkCount(int cx, int cy) {
    var n = 0;
    final r = markerSide ~/ 2;
    for (var yy = cy - r; yy <= cy + r; yy += 3) {
      for (var xx = cx - r; xx <= cx + r; xx += 3) {
        if (isDark(xx, yy)) n++;
      }
    }
    return n;
  }

  List<int> refine(int ex, int ey) {
    var best = 0;
    var bx = ex, by = ey;
    for (var dy = -90; dy <= 90; dy++) {
      for (var dx = -90; dx <= 90; dx++) {
        final n = darkCount(ex + dx, ey + dy);
        if (n > best) {
          best = n;
          bx = ex + dx;
          by = ey + dy;
        }
      }
    }
    stdout.writeln('  marker near ($ex,$ey) -> ($bx,$by) dark=$best');
    return [bx, by];
  }

  // Expected: frame spans the inner area with symmetric page margins.
  final mx = (w - frameWidth) / 2;
  final my = (h - frameHeight) / 2;
  stdout.writeln(
      'Expected margins: x~${mx.toStringAsFixed(0)}, y~${my.toStringAsFixed(0)}');

  final tl = refine(mx.toInt(), my.toInt());
  final tr = refine((mx + frameWidth).toInt(), my.toInt());
  final bl = refine(mx.toInt(), (my + frameHeight).toInt());
  final br = refine((mx + frameWidth).toInt(), (my + frameHeight).toInt());

  final sx1 = (tr[0] - tl[0]) / frameWidth;
  final sy1 = (bl[1] - tl[1]) / frameHeight;
  final sx2 = (br[0] - bl[0]) / frameWidth;
  final sy2 = (br[1] - tr[1]) / frameHeight;
  stdout.writeln(
      'sx $sx1 / $sx2   sy $sy1 / $sy2');
  final sx = sx1;
  final sy = sy1;

  void fillDisc(double relX, double relY, String tag) {
    final cx = (tl[0] + relX * sx).round();
    final cy = (tl[1] + relY * sy).round();
    for (var dyy = -fillRadius.ceil(); dyy <= fillRadius.ceil(); dyy++) {
      for (var dxx = -fillRadius.ceil(); dxx <= fillRadius.ceil(); dxx++) {
        final d2 = dxx * dxx + dyy * dyy;
        if (d2 > fillRadius * fillRadius) continue;
        final px = cx + dxx;
        final pyc = cy + dyy;
        if (px < 0 || pyc < 0 || px >= w || pyc >= h) continue;
        // Anti-alias edge: blend fraction of coverage.
        final cov = (fillRadius - math.sqrt(d2.toDouble())).clamp(0.0, 1.0);
        final a = (cov * 255).round();
        image.setPixelRgba(px, pyc, 0, 0, 0, a);
      }
    }
    stdout.writeln('  filled $tag at ($cx,$cy)');
  }

  // -- SBD: 000413 --
  const sbd = '000413';
  for (var i = 0; i < sbd.length; i++) {
    fillDisc(sbdCols[i], digitRowY(sbd.codeUnitAt(i) - 48).toDouble(), 'SBD[$i]=${sbd[i]}');
  }

  // -- Ma de: 001 --
  const exam = '001';
  for (var i = 0; i < exam.length; i++) {
    fillDisc(examCols[i], digitRowY(exam.codeUnitAt(i) - 48).toDouble(), 'EXAM[$i]=${exam[i]}');
  }

  // -- Answers: key ABCD x40, skip questions (1-based) 1,3,5,7,9 --
  const key = 'ABCDABCDABCDABCDABCDABCDABCDABCDABCDABCD';
  const skipped = {0, 2, 4, 6, 8}; // 0-based question indices
  for (var q = 0; q < key.length; q++) {
    if (skipped.contains(q)) continue;
    final group = groups[q ~/ 10];
    final row = q % 10;
    final col = key.codeUnitAt(q) - 65; // A=0
    fillDisc(
      group.colX[col],
      group.row0Y + row * group.rowPitch,
      'Q${q + 1}=${key[q]}',
    );
  }

  final encoded = img.encodeJpg(image, quality: 92);
  File(outPath).writeAsBytesSync(encoded);
  stdout.writeln('Saved: $outPath (${encoded.length} bytes)');
}
