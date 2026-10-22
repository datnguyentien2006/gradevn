# M3 device demo — pattern kỳ vọng (dictated input)

## Cấu hình demo (DB trống trên máy thật)
- Lớp học: `10A1` (1 lớp).
- Học sinh: SBD **000413** — **Nguyễn Văn A**.
- Kỳ thi: **40 câu, phiếu chuẩn (standard)**, điểm tối đa 10.
- Dãy đáp án (key) — mã đề nhập tay **`001`**: lặp `ABCD` × 10
  (Q1=A, Q2=B, Q3=C, Q4=D, Q5=A, Q6=B, Q7=C, Q8=D, …)

## Phiếu "học sinh giả" tô theo pattern quy định
- **SBD (lưới trái):** `000413` — lưới chữ số TN40 theo CỘT (6 cột = 6 vị trí, hàng = giá trị):
  tô cột1-giá trị 0, cột2-0, cột3-0, cột4-4, cột5-1, cột6-3.
- **Mã đề (lưới phải):** `001` — 3 CỘT: tô cột1-giá trị 0, cột2-0, cột3-1
  (decode `001` → chuẩn hoá `1` = key `001` → khớp trực tiếp).
- **Đáp án:** tô theo key ở trên, NGOẠI TRỪ:
  - **Q3:** tô **D** (key C) → SAI
  - **Q7:** **không tô** (key C) → BỎ TRỐNG
  - **Q10:** tô **A** (key D) → SAI

## Kỳ vọng khi chấm
| Số liệu | Giá trị |
|---|---|
| Điểm | **9.25** (= 37/40 × 10) |
| Đúng | 37 |
| Sai | 2 (Q3, Q10) |
| Bỏ trống | 1 (Q7) |
| SBD | 413 → gắn **Nguyễn Văn A** |
| Mã đề | 1 (key `001` dùng trực tiếp, KHÔNG hiện cảnh báo đoán key) |
| Ảnh | phiếu gạch kết quả: 37 ✓ xanh, 2 ✗ đỏ, 1 trống |

## Edge case 2 (mã đề mờ/đọc không được)
- Phiếu thứ hai **không tô lưới mã đề** (vẫn tô SBD + đáp án):
  → decode mã đề `???` → app dùng key có điểm khớp cao nhất (duy nhất) và hiển thị
  **cảnh báo đoán key**; điểm vẫn tính đúng 9.25.

## Edge case 1 (thiếu mốc ô vuông)
- Chụp ảnh mà một phần mép phiếu ra khỏi khung hình (mốc góc bị cắt/thiếu) →
  không đủ 4 mốc → màn hình soát cắt: người dùng **ghim 4 ô vuông đen** theo thứ tự
  (trái-trên, phải-trên, phải-dưới, trái-dưới) → nắn phẳng → quét lại → chấm đúng.
