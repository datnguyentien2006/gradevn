# GradeVN — Implementation plan (Flutter)

Derived from `docs/reference-analysis.md` (Phase B). Original code, from scratch; no assets or code from the reference APK.

## 1. Product definition (one-liner)

Offline Vietnamese OMR app: teachers define contests with answer keys (multiple keys per contest), scan student answer sheets with the phone camera on-device, GradeVN decodes and grades them against the 10-point Vietnamese scale (incl. multi-part "ministry" formats), and exports results to XLSX/PDF/printable sheets.

Non-goals: accounts/cloud backend, purchases, ads, gating counters. 100 % offline.

## 2. Architecture (clean layering as required)

```
lib/
  domain/        # pure-Dart business logic — 100% unit-testable target zone
    entities/      # Contest, ClassRoom, Student, AnswerKey, AnswerSheetResult, GradedAnswer…
    value_objects/ # ScoringRule, FormSpec (50/120/ministry/horizontal), SheetGeometry(11×6 lattice)
    services/      # Grader (correct-count + part scores), OmrDecoder (grid→chars/answers), OcrMatcher
  data/          # implementations
    db/            # drift: tables + DAOs; repository implementations
    repositories/  # keys_repo, answers_repo, contest_repo, class_repo, students_repo
    import_export/ # XLSX (syncfusion_flutter_xlsio), PDF (printing/pkg pdf), JSON backup
    camera/        # camera + image streaming plumbing
    cv/            # OMR image pipeline (pure Dart or opencv_dart, see §4)
    ocr/           # student-info OCR adapter (optional module; isolated behind interface)
  presentation/  # UI, 100% Vietnamese
    screens/       # home, contest detail, key editor, scan (camera), result review, stats, settings
    widgets/       # sheets, score badges, overlays
    state/         # Riverpod providers/notifiers
```

Pattern: **repository pattern** — domain defines abstract repositories & services; `data/` implements them; `presentation/` depends only on domain interfaces via Riverpod providers (no direct data-layer imports).

## 3. State management: **Riverpod** (justification over Bloc)

- Testability: providers are trivially overridable per test (no inherited-widget ceremony), aligning with the >90 % coverage goal on logic and repository seams.
- Async-first data flow: grading/imports produce `AsyncValue`s; Riverpod's `Stream`/`Future` providers map to drift `watch()` queries without adapters — Bloc would need extra event/state plumbing for the same result.
- Composition: scoring engine + repositories compose as pure providers (e.g. `graderProvider = Provider(Grader())`) — short DAG, less boilerplate than Bloc's event→state class for screens that are mostly reactive lists (results, students, stats).
- `flutter_riverpod` (stable) + generated notifiers; no codegen dependency beyond `riverpod_generator` (dev).

Bloc remains fully adequate but heavier for this codebase shape (read-mostly data + one camera screen); **Riverpod chosen**.

## 4. Technology stack (all paths free/open)

| Concern | Package | Notes |
|---|---|---|
| DB | `drift` (SQLite, moor lineage) | offline-first; mirrors reference's SQLite repos |
| State | `flutter_riverpod` + `riverpod_generator` (dev) | see §3 |
| Camera | `camera` (+ `mobile_scanner` for QR key import) | reference used OpenCV JavaCameraView; Fluid-equivalent capture |
| CV | **pure-Dart image pipeline first** (`image` package + own Dart re-implementation of the observed steps); optional `opencv_dart` only if Dart can't hit performance targets on device — isolated behind `OmrImagePipeline` interface |
| OCR (student info) | `google_mlkit_text_recognition` (optional, on-device, works offline on-device once installed); graceful no-op fallback if unavailable | isolated behind `StudentInfoOcr` interface |
| XLSX | `syncfusion_flutter_xlsio` (community license) | required feature |
| PDF | `pdf` + `printing` | printable result reports / blank sheet generation |
| DI | plain Riverpod providers | transformers unnecessary |
| Tests | `flutter_test` + `drift` `NativeDatabase.memory()` + `mocktail` | fixtures under `test/fixtures/` |

## 5. OMR pipeline mapping (Dart re-implementation, from reference behavior — not code)

Each reference stage → GradeVN equivalent (numbers are **initial calibration values**, to be tuned with real-device fixture tests):

| Ref stage (evidence) | GradeVN home |
|---|---|
| capture-region submat (onCameraFrame) | `ImageCrop.captureRegion()` — interactive crop rect UI |
| brightness +100 → gray → Gaussian 3×3 σ2 → adaptiveThreshold 31, C=5·scale (i()) | `OmrImagePipeline.binarize()` |
| per-block findContours + aspect 0.8–1.2 + ink-density ≥ setting (h()) | `AlignmentDetector.findMarks()` + `SensitivitySetting` provider |
| all-blocks gate → getPerspectiveTransform/warpPerspective (j()) | `AlignmentDetector` + `PerspectiveWarper` (pure-Dart homography on `image` Mat-equivalent) |
| 11×6 lattice, cell = A0/11 × B0/6, radius 9/20·cell (m()) | `SheetGeometry.fromFormSpec()` — lattice → cell rects |
| density value per cell h0() | `OmrImagePipeline.cellDensity()` |
| engine H() cell-densities → decoded answers; f()/g() ID/code digits | `OmrDecoder` (pure Dart over density matrix + thresholds) |
| finalize p(): t0/M → correct[], u0/q0 score, j0/s0/z part scores, F info crop (p()) | `domain/services/Grader` + `GradedResult` builder + `InfoZoneCropper` |
| free-trial gating in camera loop | **omitted** (no gating) |

`FormSpec` supports: standard (portrait, any length), ministry multi-part (parts I/II/III(/IV) with per-part sentence counts + scoring knobs), horizontal layouts, and sheet forms ~50/120 questions as first two *templates we calibrate* (template folder is data-driven, extensible).

## 6. Scoring rules (from observed behavior §7, re-derived)

- Per question `1..N`: correct if decoded mark == key answer.
- Default rule: plain correct/incorrect (no negative marking) — `ScoringRule.simple(pointsPerQuestion = max/ length)`.
- Custom `autoCorrect`-style rule (per-question weights, e.g. 2-point hard questions) parsed from key editor.
- Format standard: `score = round(Σ per-question points × 100) / 100` on the contest-defined max (Vietnamese 10-scale default).
- Ministry format: per-part counts × per-part weights, separate + total (`partOne/Two/Three(/Four)`); part toggles.
- Multiple keys per contest: best-match key chosen by exam code decoded from sheet.

## 7. Milestones (each: `flutter analyze` 0 errors + tests green + demo checklist → user sign-off)

### M0 — Skeleton & environment
- Flutter project scaffolding, exact folder layout §2, lint config, drift schema v1 (all tables), CI-less test harness, Vietnamese `l10n` baseline, app icon/name (GradeVN), theme.
- **Demo:** app launches on Android emulator; empty DB; all screens routable with placeholder content; `flutter analyze` 0 errors.

### M1 — Data core (repositories + import)
- Contest/class/student/key CRUD; XLSX import (keys + student lists) & export; JSON backup/restore; SQLite persistence verified after restart.
- **Demo:** create contest → import keys XLSX → list keys; restart app → data persists; unit tests cover grading rule parsing + repository CRUD.

### M2 — Grading engine (pure Dart, no camera)
- `FormSpec` + `SheetGeometry` lattice; `OmrDecoder` from synthetic density matrices; `Grader` correct count + 10-score + part-scores + multiple-key matching; fixture tests with rendered sheets (generated PNGs with `image`) under `test/fixtures/` covering: clean sheet, noisy margins, missing marks, 2 keys, ministry 3-part.
- **Demo:** CLI/test-driven: feed synthetic sheet image → graded result; >90 % line coverage on `domain/services/*` measured.

### M3 — Camera scanning UX
- Camera preview (portrait), capture-region crop, live alignment overlay plane (detect per frame in isolate), sheet grading full loop → result saved, per-question ✅/❌ overlay image, ID-grid + exam-code decode, student-info OCR linking (with offline no-op fallback), review screens (list + per-sheet detail + marked image + part scores).
- **Demo:** scan a printed/simulated sheet in emulator/device recording: correct decode on ≥2 fixture sheets; auto-link student; review + export from result screen.

### M4 — Statistics, polish & release
- Stats screens: per-question correct/incorrect bars, score lists, class ranking; settings (sensitivity, export layout, warnings, sorting, vibrate/haptics, time-back UX); final XLSX/PDF reports; dark theme; performance pass (scan loop isolate + caching).
- **Demo:** end-to-end teacher story; release build commands (see Phase D); `flutter analyze` 0 errors, full test suite green; coverage report in `coverage/`.

## 8. Verification (Phase D requirements mapping)

- `flutter test --coverage` ≥ 90 % lines on `lib/domain/services/**` (grading/OMR math) — enforced via `dart pub global run coverage` CI script locally + report into PROJECT_NOTES.
- `test/fixtures/`: generated + committed reference sheets + expected decodas/JSON `expected/` sidecars; every grading change re-runs fixtures.
- Release: `flutter build apk --release` (Android); **iOS** — macOS-only: document `xcodebuild` + signing steps (machine lacks macOS; document per plan).
- Documentation: `README.md` (build/run/test/export), `docs/` retained, PROJECT_NOTES final entry.

## 9. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Pure-Dart CV slower than reference's native OpenCV on low-end devices | isolate + downscale (reference used scale factor W/1280 for the same reason); `opencv_dart` fallback behind interface (§4) |
| Lattice constants differ per form; reference tables not fully extracted | data-driven `FormSpec` templates; calibration UI + fixture tuning; observed constants as priors (reference-analysis §6, §11.2) |
| ML Kit OCR needs Play Services device presence | interface isolation + no-op fallback; grading works without OCR |
| iOS build impossible on this machine | per plan: Phase D documents Mac steps |
| XLSX import edge cases (merged cells, formats) | strict importer tests; JSON/CSV fallback documented |
