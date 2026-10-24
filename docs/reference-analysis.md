# Reference-app analysis — TN Maker 4.0.0 (Phase B)

> **Clean-room note.** This document describes observed behavior of a third-party APK for the
> purpose of building an *original* Flutter app (GradeVN). No decompiled code, resources,
> layouts, strings or assets from the reference app are copied into GradeVN. Everything below is
> behavior observed via REA/JADX static analysis (tool provenance cited per section). Implementations
> will be written from scratch in Dart based on this behavioral description.

## 1. Subject identity & provenance

| Property | Value | How verified |
|---|---|---|
| File | `C:\Marker-td\tnmaker.apk` (50,501,628 bytes) | SHA-256 `1d3ef42b5a4af8ec84ec49da81105e9c98b45f1291e41aa215521d59db46a91f` |
| Package | `first.tnmaker.tracnghiem` | `rea inspect-android-package` (`tools/_b_out/package2.json`) |
| Version | 4.0.0 (versionCode 114) | same |
| App label | `@string/app_name` = **"TNMaker"** (both `default` and `vi` string configs) | `apkanalyzer resources value` |
| SDK range | minSdk 21 → targetSdk 34 | same |
| Classes / resources | 14,356 classes, 4,122 resources | same |
| Framework verdict | **NOT Flutter** — no `libapp.so`/`libflutter.so` on any ABI, coverage `complete` (2× runs) | `rea identify-flutter-build` |

Evidence files: `tools/_b_out/package2.json`, `manifest.xml`, `components.txt`, `classes_app.json`, `files.txt`, `main_*.json|java`.

Framework decision per plan-adaptation rule: native Kotlin/Java app ⇒ **full-depth JADX analysis** (class/method/reference tracing), skipping Flutter/Dart decompilation paths (verified dead end).

## 2. High-level verdict

TN Maker is a native Android **OMR (Optical Mark Recognition) grading app**: it reads multiple-choice
answer sheets with the phone camera, decodes pencil/pen bubble marks in real time, and scores them
against imported or manually created answer keys, with on-device statistics, Excel/PDF export and a
Firebase-backed auth/cloud layer plus Google Play Billing.

## 3. Library inventory (from complete class-name inventory, `search_android_classes` empty query via MCP — complete coverage)

| Library | Classes | Role in app |
|---|---|---|
| OpenCV Java (`org.opencv.*`, `libopencv_java3.so`, arm64-v8a) | 102 | Camera capture (`JavaCameraView`), all image processing |
| ML Kit text recognition (API 16 classes + GMS Dynamite modules + embedded `assets/mlkit-google-ocr-models/*` GOCR latin mbv2 detector/recognizer/layout/script-id, `libmlkit_google_ocr_pipeline.so`) | small API, bundled models | OCR of handwritten/printed student info zone |
| Apache POI + XMLBeans | 1,048 + 763 | `.xlsx` import/export |
| JExcelAPI (`jxl.*`) | 450 | `.xls` import/export (consumer: `view.u`) |
| iText 5 (`com.itextpdf.*`) | 398 | PDF generation (consumer: `view.v`) |
| Google Play Billing client | Billing | premium unlock |
| Firebase (auth, messaging, analytics-ish) | 193 | Google login, notifications |
| Google Play services | 5,694 incl. MLKit dynamite | OCR runtime + auth |
| journeyapps zxing scanner (`CaptureActivity`) | 7 | QR answer-key import |
| Glide (40) + Picasso (1) | image loading | result image display |
| androidx.sqlite | 24 | SQLite persistence |
| CameraX | **0 classes** | camera runs through OpenCV `JavaCameraView` only |
| Obfuscated app core (`y0`=159, `j6`=82, `k5`=63, … many small packages) | ~1,400+ micro-packages | ProGuard-obfuscated app internals incl. the OMR template "engine" singleton `d5.a` (89 methods) |

App-owned classes under `first.tnmaker.tracnghiem.*`: 89 top-level (models, control, view, fragment, auth, purchase) + obfuscated helpers.

## 4. Screen flow (from decoded AndroidManifest, `components.txt` — 65 components)

Onboarding: `IntroSlideActivity` → `CheckPermission` → `ProfileActivity` (profile + Google login `auth.GoogleLoginActivity`, `ForgotPasswordActivity`, `auth.FirebaseHelper`).

Main hub: `control.HomeActivity` with Fragments `ClassFragment`, `ContestFragment`, `ListContestFragment`, `ListStudentFragment` (`control.ActivityManager` coordinates global state; `control.MainActivity` = camera OMR scanner; `control.SettingActivity`; `control.InfoActivity`; `control.AboutActivity`; `view.GuideUser`).

Key management (`ViewKey`, `ViewListKey`, `view.ReviewKey`, `ViewReviewHandImport`) — create/edit/import keys.
Answer management: `ViewAnswer`, `ReviewAnswer` + `viewpager.ReviewAnswerActivity`, `AnswerSheet`, `ViewListAnswer`, `ViewListContestStudent`, `ViewListClass`.
Statistics: `ChartActivity`, `ChartDetail` (4 RecyclerViews, model.a[] → per-question stats — method/field evidence).
Purchase: `purchase.PurchaseActivity`, `BillingUpdatesManager`(+Listener), `Products`, `PremiumFunction`.
Scanner UI: `view.MyCameraView` (extends `org.opencv.android.JavaCameraView`) inside `MainActivity`.
QR: `com.journeyapps.barcodescanner.CaptureActivity`; file picking via `com.obsez.android.lib.filechooser`; `FileProvider` for share/export.

## 5. Data model (exact field sets from `inspect_android_class`, non-obfuscated model classes)

- **MyContest** (the exam/contest + template config): `id`, `classID`, `nameClass`, `nameContest`, `dateContest`, **`formContest`** (sheet form type; camera code branches on 50/120 vs others), **`formTypeContest`**, **`isHorizontal`** (int, 0/1), **`isMinistry`** (int, 0/1 — "Ministry" two-part official format), `numberAnswerContest`, `numberKeyContest`, **`sentenceContest`** (# questions), `sentencePartOne/Second/Third`, **`scoreContest`** (score scale target), part-scoring knobs `scoreTotalPartOne/Third`, `scoreTotalPartFour`, `scoreOneCorrectPartSecond/Two/ThreeCorrectPartSecond`, `scoreFourCorrectPartSecond`, `isSwitchPartOne/Second/Third/Four` (part toggles), `typeSort`.
- **MyKey** (answer key): `id`, `contestID`, **`made`** (exam-code string, e.g. "Đề 123"), `key` (answer string), `textKey` (display text), `midPoint`, **`autoCorrect`** (scoring-rule string parsed → int[]), `pathKey`, `pathOriginal` (key-sheet image). Parcelable.
- **MyAnswer** (a graded student sheet): `id`, `contestID`, `made`, `textMade`, **`sobaodanh`** (student-ID string decoded from the 6×10 ID grid), `textSobaodanh`, `idStudent`, `nameStudent`, `answer` (decoded answer string), `score` (float), `scorePartOne/Second/Third/Four` (float, ministry part scores), `textScore`, `pathOriginal` / `pathResult` (marked overlay image) / `pathInfo` (student-info OCR image), `midPoint`. Parcelable.
- **MyScore** (in-memory grading result): `findAnswer: int[]`, `findKey: int[]`, `findAutoCorrect: int[]`, `trueAnswerNumber: int`, `made`, `sobaodanh`.
- **MySetting** (singleton: `getInstance`): `exportType`, `name`, `numberSeparate`, `override`, `sentenceNumber`, `separate`, `timeBack`, `typeSort`, `typeView`, `vibrate`, `warning`, `warningAnswer`, `warningID`, `warningKey`.
- **MyClass**, **MyStudent** (class/student registry for linking scanned sheets by student ID) + obfuscated model helpers `model.a…e`.
- **Persistence**: SQLite (androidx.sqlite) behind obfuscated repository singletons (`i.h(Context)` = keys repo, `e5.a` = answers repo, `l.h` = students/classes; engine singleton `d5.a.V()` = 89-method template/scoring engine). Result images saved via `d5.a.A0(...)` into named folders (`originalImage`, answer/info/result subfolders per contest+orientation; constants `i5.a.f3964e/f/h`, `i5.c.a.INFO_TYPE`).

## 6. OMR pipeline (decompiled method bodies in `tools/_b_out/main_*.java`)

Evidence chain: `MainActivity.onCameraFrame` → per-frame callback (`CvCameraViewListener2`).

1. **Free-tier gate:** `if (H == 1 && purchase.isPro == 0 && ActivityManager.W <= 0) { promo + finish(); }` — W is a trial counter decremented per graded sheet (`onCameraFrame.java` lines 2–6).
2. **Live frame + capture region:** `L = frame.rgba()`, clone to overlay `M`, `K = L.submat(y0, Y+y0, 0, W)` — fixed capture rectangle; scale factor `W/1280` feeds tolerance helpers `i(scale)`.
3. **Per-block alignment finding:** for each precomputed template block mask `V[i]`: `findContours` → `h(contours, i, scale, flags)`:
   - `boundingRect` + `minAreaRect`; **aspect-ratio filter 0.8–1.2** (reject lines/dots/letters).
   - **Ink-density test:** `blackPercent = (contourArea − countNonZero(submat))/area` must exceed setting threshold `d5.a``.V().o0(scale)` (adjustable sensitivity setting).
   - Accept largest valid area; map block-local coordinates to full-page coordinates via block origin rects `a1[i]`.
   - All blocks (counter `z0 == i`) must be found before proceeding.
4. **Perspective warp (`j()`):** `getPerspectiveTransform` + `warpPerspective` of capture region using found corner/marks → corrected page `O` + grid corner arrays `P0`, `Q0`; sets block count `Z0`. Branches on template mode: `formContest == 50 || 120` or `isMinistry > 0` or `isHorizontal == 1` → `n() + l() + k()`; else `n() + m()`.
5. **Per-block preprocessing (`i(block)`):** `V[i] = M.submat(b1[i])` → brightness add +100 → `cvtColor` RGBA→GRAY → `GaussianBlur 3×3 σ≈2` → **`adaptiveThreshold(blockSize=31, C=5·scale)`** (BINARY). Called per block (`main_i.java`).
6. **Grid decoding (`m()` + engine `d5.a`):** for each of `Z0` blocks — engine `I0(P0, Q0, block, formContest, isHorizontal, isMinistry)` returns cell size `A0 × B0`; cell dims `C0 = A0/11`, `D0 = B0/6` — **a 11-col × 6-row lattice per block** (10 digit columns + margin for the ID/code grids; same lattice coordinates drive answer grids). For each cell: `submat` crop → `h0(cell)` ink-density value → `dArr[row][col]`; overlay circles `radius = 9·D0/20`, `thickness = D0/7` for UI; blank cells are whited-out. Full blocks decoded by engine `H(block, dArr, findAnswer[], …)` → decoded answers `c1[block][][]`; exam-code & student-ID digits decoded with `f(...)`/`g(...)` post-steps.
7. **Finalize (`p()`):**
   - Mode `H==0` (**scanning a key**): store `originalImage`, open `ViewKey` with new `MyKey(made=exam code decoded, key=answer string, textKey, midpoint, autoCorrect = engine default `w0(formContest)` e.g. "1 điểm/câu" default rule)`.
   - Mode `H==1` (**scanning a student sheet**): load matching key by exam code from keys repo `i.h(context)`; `t0(findAnswer, findKey, autoCorrect, …)` → per-question correct/incorrect `int[]`; `i0(...)` → answer-cell positions for overlay; `e(...)` draws ✅/❌ overlay; save `answerImage`; `M(...)` → **trueAnswerNumber** (correct count); `F(...)` crops/attaches **info image** (student info zone → ML Kit OCR) with `i5.c.a.INFO_TYPE`; if `isMinistry == 0` → **score = round(correct × u0(sentenceContest, scoreContest) × 100) / 100** and `q0(...)` score text ("Điểm: x.xx" style); else part-scores `j0(contest, marks)` → 3 floats (Part I/II/III) summed by `s0(list)`, text `Z(...)`; build `MyAnswer`; open `ViewAnswer`; decrement trial counter `W` (UI badge "X sheet còn lại" style promo).
   - `n()`: corner/line cleanup pass (`Canny(50, 80)`-family morphological cleanup on residual mask `R` — erode → subtract → bitwise_not → dilate 3×3; `main_n.java`).

Engine methods referenced (all inside `d5.a`, obfuscated, 89 methods): `o0, I0, l0, h0, H, F, w0, t0, i0, M, u0, q0, j0, s0, Z, A0` (image storage), `f, g`.

## 7. Scoring rules (observed)

- Standard format: **`score = round(correct_count × u0(sentenceContest, scoreContest) × 100) / 100`** — i.e. `scorePerQuestion = scoreContest / sentenceContest` semantics, two-decimal rounding (Vietnamese 10-point scale conventions).
- Ministry (bộ đề official) format: 3/4 part scores (`scorePartOne/Second/Third/Four`) each computed per-part from question counts `sentencePartOne/Second/Third` and part-scoring knobs; separate display + total (`textScore`).
- `findAutoCorrect` int-array encodes per-question scoring weights parsed from `MyKey.autoCorrect` (e.g. 0/1 question scoring, penalty-less; supports multiple keys per contest — `numberKeyContest`).
- Answer matching: per-question, no observed "SAI bug đổi câu" (-1 per wrong question) option.

## 8. Answer-key formats & import/export

- **Manual** creation via `ViewKey` / `ReviewKey` after scanning a blank key sheet, or hand-entry in `AnswerSheet` view.
- **Excel:** `.xls` via JExcelAPI (consumer class `first.tnmaker.tracnghiem.view.u`, 15 refs to `jxl.Workbook`), `.xlsx` via Apache POI (consumers: `fragment.ListStudentFragment`, `view.ViewListKey`). Import keys/student lists; export results.
- **QR code:** journeyapps/ZXing `CaptureActivity` encodes/imports key data.
- **PDF:** iText (consumer `view.v`, 25 refs to `com.itextpdf.text.Document`) — export result sheets/reports.
- Image outputs: original capture, marked result overlay, info crop (all JPEG files in app folders per contest; shared via FileProvider).

## 9. Statistics

- `ChartActivity`: contest overview — score list (ArrayList<Float>), key list, menu actions.
- `ChartDetail`: 4 RecyclerView sections + `model.a[]` arrays — per-question correct/incorrect aggregates, student/answer details (`view.e/f/g` adapters, h5.d backing store).

## 10. Monetization & accounts

- Google Play Billing (`purchase.*`): premium unlock `getPurchaseIsPro()`; free trial = counter `ActivityManager.W` decremented per scanned sheet; gate inside camera loop + promo dialog.
- Google login (Firebase Auth + GMS), Firebase messaging notifications; cloud sync optional — **core OMR/grading works offline** (all CV/OCR is on-device).

## 11. Risks & gaps (for clean-room reconstruction)

1. **No runtime pass yet.** All pipeline numbers above come from static analysis of one APK; device-behavior verification (real frames, thresholds on lighting) remains untested. Ranges/thresholds will need empirical calibration in GradeVN.
2. **The template engine `d5.a` (89 obfuscated methods) was only mapped at call-boundary level.** Exact constants of the 11×6 lattice geometry per `formContest` value (50, 120, others), part-boundaries for ministry formats, and `o0(scale)` sensitivity defaults were **not** extracted as full numeric tables — the per-form geometry is spread across obfuscated bodies; treat observed constants (blockSize 31, C=5×scale, aspect 0.8–1.2, brightness +100, blur 3×3, radius 9/20, thickness 1/7) as starting points, not gospel.
3. **OCR usage depth is unknown** (which fields OCR'd: tên, số báo danh, thành phố?). The pipeline plumbs an INFO image to ML Kit; exact parse/reconcile logic (e.g., matching students by ID from `MyClass`/`MyStudent` DB) was not decompiled.
4. **Obfuscated internals imply inference.** DB schemas, exact stored strings (`textKey`, `midPoint` semantics), and error-handling UX were observed indirectly from call sites.
5. **Reference-app features we should NOT replicate** (per clean-slate goal): Firebase/cloud accounts, Billing/trial counter, Google-login dependency. GradeVN will be **offline-first, no backend, no gating**.
6. The reference ships native code only in arm64-v8a; irrelevant to GradeVN (pure Dart CV planned), but confirms no x86 runtime assumptions were needed there.

## 12. Feature list for GradeVN parity (functional baseline)

1. Contest/class/student registry (offline SQLite via drift).
2. Answer-key creation: manual entry + camera key-scan with exam-code+ID grid; multiple keys per contest.
3. Camera OMR scan of student sheets: alignment → decode ID grid + exam code + chosen answers → per-question overlay.
4. Grading: correct count → 10-scale score; ministry two/multi-part formats; per-question scoring weights (autoCorrect).
5. Student-info OCR linking to registered students (optional ML Kit / tesseract fallback in Flutter scope; must degrade gracefully offline).
6. Review screens: result list, per-sheet marked image, per-question stats; charts/aggregates.
7. Export: XLSX (and generation of print-ready PDF answer sheets where feasible).
8. Settings: sensitivity threshold, export layout, warnings, sorting, vibration/timeback UX.
9. 100% offline, Vietnamese UI, no gating/paywalls.
