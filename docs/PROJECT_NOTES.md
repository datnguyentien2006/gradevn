# PROJECT_NOTES — GradeVN

Ghi chú kỹ thuật theo từng vòng lặp của dự án. Ràng buộc xuyên suốt (áp
dụng cho MỌI vòng): **100% offline** (không gọi mạng lúc chạy), **UI tiếng
Việt**, **clean-room** (tự viết lại hành vi bằng Dart gốc, không sao chép
code/tài sản của app tham chiếu), gates: `flutter analyze` 0 lỗi · full
suite xanh · coverage ≥ 90% trên `lib/domain/services/**`.

| Vòng | Phạm vi chính | Trạng thái |
|---|---|---|
| M0–M3 | Skeleton, drift schema, import/export XLSX, grading engine, marker-frame template, 4-marker OMR pipeline, scan flow + camera UI + review screens | xong |
| R1 | Contest screen rework, 2-tab key editor, marker-pick crop, free-form scan | xong |
| R2 | 4-rect camera overlay (kéo + snap), NULL exam-code/SBD flow, result card trên nav bar, responsiveness, CropReview isolate spawn, drag-overlay demo bug | xong |
| R3 | Overlay = phép chiếu mốc theo TN Maker, kiểm chứng mốc + bằng chứng, thẻ điểm tức thời, ẩn "Chỉnh thủ công" sau feature flag | xong (xem dưới) |

## R3 — Camera overlay fidelity · Proof of detection · Instant score card

### 1. Overlay = PHÉP CHIẾU của 4 mốc in (không phải trang trí góc màn)

- `SheetProjection` (`lib/data/cv/preview_overlay.dart`): dựng **khung phiếu
  ảo** aspect-fit TRANG GIẤY chuẩn (kể cả lề, theo tỉ lệ `SheetLayout`) giữa
  vùng preview (lề 5% mỗi phía — đổi từ 8% để ô bám sát mép khi phiếu phủ
  khung, đúng obs_006); 4 ô overlay đặt tại **vị trí chiếu của 4 tâm mốc
  góc**, cỡ ô = cạnh mốc in thật × tỉ lệ khung, SÀN ~12% bề rộng preview
  (kẹp 34–150 px) — trong ảnh obs_006 ô chiếm ~12% bề rộng màn hình.
- Hình dạng khớp ảnh chụp obs_006 (clean-room): **ô TRẮNG ĐẶC (~92% đục),
  KHÔNG viền, KHÔNG bóng đổ, góc bo nhẹ, số thứ tự 1–4 rất nhạt**; ô
  **khoá** (detector thấy mốc thật trong bán kính 0.9 × cỡ ô) đổi **viền
  xanh đậm + nền bớt đục** để thấy mốc đã khớp.
- **Kéo tay (R2) được giữ** làm dự phòng mốc phai: kéo xong ô đó tắt
  auto-snap; các ô chưa kéo vẫn snap về ứng viên detector (~4 lần/giây,
  isolate, phân tích cả 2 hướng sensor).
- **Fullscreen đúng obs_006**: BỎ AppBar — preview tràn toàn màn hình
  (`Scaffold` nền đen + `extendBody`, preview tràn sau cả thanh nav
  Android); nút quay lại = icon mờ góc trái trên; nút chụp = **đĩa trắng
  tròn giữa-dưới** nổi trên nav bar (tính cả SafeArea); KHÔNG vẽ outline
  nét đứt (obs_006 chỉ có 4 ô trắng trên preview — khung phiếu ảo vẫn tồn
  tại ở tầng hình học để đặt vị trí mặc định).
- Không copy bất cứ tài nguyên/code nào của app tham chiếu — chỉ tái tạo
  **hành vi** (vị trí ô theo khung phiếu, trắng mờ, khoá xanh khi khớp mốc).

### 2. Kiểm chứng mốc + bằng chứng (điểm nghi ngờ lớn nhất của người dùng)

- **Round-trip sau nắn**: `verifyWarpedMarkers` (`lib/data/cv/scan_service.dart`)
  chạy lại detector trên **ảnh đã nắn phẳng**, đo khoảng cách 4 tâm mốc tới
  vị trí chuẩn của `SheetLayout`; ngưỡng **≤ 6 px trang chuẩn (1576×2205)** —
  CẢ 4 góc phải đạt, nếu không `scanPhoto` trả null → UI rơi
  **CropReviewScreen** (ghim tay) thay vì chấm phiếu có thể sai.
- **Bằng chứng debug trên preview + ảnh chụp**: build DEBUG vẽ ứng viên mốc
  (chấm đỏ + nhãn `cN`) và quad (xanh lá) đè lên preview (`_DebugDetectionPainter`)
  và lên ảnh chụp đã lưu (`saveDetectionProof` → annotate PNG, isolate).
  Bản release không chạy nhánh này. Ảnh kéo từ thiết bị về
  `docs/evidence/` (xem `docs/evidence/README.md`).
- **Test chống false-positive** (`test/cv/marker_verification_test.dart`,
  `test/cv/alignment_test.dart`): phiếu tô ĐẦY mọi bong bóng + lưới số (quad
  vẫn đúng 4 mốc góc ≤ 6 px) · chữ in mảnh viền rỗng (0 candidate) · dải nền
  bàn tối (0 candidate trong dải) · mốc dịch 15 px (round-trip TỪ CHỐI) ·
  xoay ±30° · thu phóng ×1.0–×2.0 · chếch 12° + shear · partial framing
  (đệm trắng lệch tâm) · bóng đổ (gradient + dải tối).

#### Detection accuracy (ghi từ test suite — cập nhật mỗi lần đổi detector)

| Chỉ số | Corpus test | Kết quả |
|---|---|---|
| True-accept | 6+ biến thể chụp mô phỏng: thẳng, xoay ±30°, xoay 12°+shear, partial framing, bóng đổ — detector đủ 4 mốc + giải mã đúng mọi câu | **100%** (suite xanh) |
| False-positive | 4 họ nhiễu: bong bóng tô đầy + lưới số, chữ mảnh, nền bàn tối, mốc dịch 15 px | **0%** (suite xanh) |
| Round-trip sai lệch | Fixture chuẩn: max offset | **≤ 3 px** (ngưỡng 6 px) |
| Per-frame runtime (preview) | Phân tích khung preview (640 px, isolate, throttle 250 ms) | chạy cách nhau ≥ 250 ms, không chặn UI |
| Runtime verifyWarpedMarkers | Benchmark 5 mẫu lấy trung vị (`marker_verification_test.dart` in stdout) | **trung vị 87.0 ms** (82.1–92.0) |

> Số đo runtime gần nhất (dán từ `flutter test test/cv/` — benchmark in
> sẵn, máy dev Linux, Flutter 3.47.7 / Dart 3.13.5):
> - `verifyWarpedMarkers` (trang chuẩn 1576×2205): 5 mẫu — 82.1 / **87.0
>   (trung vị)** / 92.0 ms.
> - Pipeline OMR trọn gói (detect + warp + đo + giải mã, 40 câu): 3 mẫu —
>   74 / **74 (trung vị)** / 75 ms — mục tiêu M2 < 2000 ms đạt với dư địa
>   ~27×.
> - Phân tích khung preview chạy ở bề rộng 640 px trong isolate, throttle
>   250 ms/lần (≤ 4 lần/giây) — không tranh thread UI.

- ⚠️ **Chưa có fixture ảnh in THẬT** (photo chụp từ điện thoại): chờ người
  dùng cung cấp ảnh phiếu in — thêm vào `test/fixtures/` cùng expected
  outputs (điểm/SBD/mã đề) như `standard40.json`.

### 3. Thẻ điểm tức thời sau chụp

- Chụp → `processPhoto` (isolate) → đủ 4 mốc (qua round-trip) + qua luật
  MÃ ĐỀ/SBD → **hiện thẻ điểm NGAY**, không dialog trung gian;
  `CropReviewScreen` chỉ ở nhánh fallback (thiếu mốc).
- Thẻ kết quả (`_ResultCardScreen`): nền = ảnh chụp gốc làm mờ tối; card
  trắng bo góc tiêu đề **"Kết quả phiếu"**; **"Điểm: x/10"** cỡ lớn; dòng
  **"N câu đúng • M sai • K bỏ trống"**; các dòng **Số báo danh · Mã đề ·
  Học sinh**; 2 nút **"Lưu kết quả"** (filled primary) và **"Chụp phiếu
  khác"** (secondary). Giữ nguyên quy tắc R2: card nổi hoàn toàn trên nav
  bar Android (SafeArea + viewPadding); NULL flow — lưới mã đề/SBD trống →
  điểm **"NULL"** + lý do "(Không có mã đề)"/"(Không có số báo danh)",
  không chấm, lưu dấu hiệu chờ bổ sung.
- Bộ chấm bắt chước hành vi app tham chiếu: trong 1 câu chọn ô **đậm nhất**
  (tô nhiều ô → lấy ô đậm, huà chọn cột nhỏ — tương đương cách TN Maker xử
  lý "Nhiều đáp án"); câu trống → bỏ trống (không trừ điểm ngoài luật).

### 4. "Chỉnh thủ công" — ẨN, KHÔNG XOÁ

- Feature flag `showManualAlignment = false`
  (`lib/presentation/screens/scan_screen.dart`). Nút + luồng ghim tay
  (`_captureManual` → `CropReviewScreen`) + kéo ô overlay (R2) **giữ nguyên
  implementation**, biên dịch + test xanh; bật `true` là nút hiện lại ngay —
  dành cho phiếu **mốc phai** sau khi kiểm chứng trên thiết bị xong.

### 5. Gates & demo checklist

- Gates: `flutter analyze` (0 lỗi) · `flutter test` (xanh toàn bộ) ·
  `flutter test --coverage` ≥ 90% trên `lib/domain/services/**` (lọc bằng
  `lcov`).
- Checklist demo trên thiết bị: overlay bám khung phiếu ảo khi di điện
  thoại; ô snap xanh lên mốc in thật; chụp → thẻ điểm hiện tức thời; ảnh
  bằng chứng annotate lưu `docs/evidence/`; **không** thấy nút "Chỉnh thủ
  công"; Lớp học / Kết quả / Thống kê / Tạo kỳ thi không đổi.
- Phạm vi KHÔNG đụng (scope guard): `classes_tab`, `results_tab`,
  `sheet_list_screen`, `sheet_detail_screen`, thống kê, tạo kỳ thi.

### Không hồi quy R1/R2

- Marker pipeline (detector → warp → đo) không đổi ngoài việc THÊM round-trip
  verify; NULL flows (exam-code/SBD) giữ nguyên semantics; responsiveness +
  SafeArea (card trên nav bar) giữ nguyên; CropReview isolate spawn giữ
  nguyên.
