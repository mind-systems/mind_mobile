# Code Review: 63 — CardioData + RrInterval + MotionData value objects

**Reviewer:** Claude
**Plan:** `.ai-factory/plans/63-create-cardiodata-rrinterval-motiondata-value-objects-in-lib-biometrics-models.md`
**Diff scope:** 8 files (5 new value objects under `lib/Biometrics/Models/`, 2 modified BCI models, 1 modified provider).

## Summary

Pure additive milestone. New value objects match the note 27 / note 32 spec verbatim; the two existing Phase 19 models gain a required `timestamp` field with both call sites in `NeiryBciProvider` updated. `flutter analyze` is clean for all changed files (only pre-existing infos in unrelated files).

## Verification

- **All `BciNfbData(...)` and `BciEmotionsData(...)` construction sites accounted for.** A repo-wide grep returns exactly the two production call sites in `lib/Bci/NeiryBciProvider.dart` (lines 259, 282) — both pass `timestamp: s.timestamp` / `timestamp: e.timestamp`. No test fixtures, fakes, or other constructors exist. The breaking `required` addition is therefore safe.
- **SDK type contracts hold.** `NfbUserState.timestamp` and `EmotionsStates.timestamp` are non-nullable `DateTime` fields in `neiry_kit`. Passing them straight through cannot produce a runtime null violation.
- **No new imports needed in `NeiryBciProvider.dart`.** `NfbUserState`/`EmotionsStates` are already in scope via `package:neiry_kit/neiry_kit.dart`. Confirmed against the imports block (lines 1–18).
- **`lib/Biometrics/Models/` is newly created.** No name collision with anything else in the project. Imports inside the new files use relative paths consistent with the existing project style (`import 'CardioHrvIndices.dart';` and `import 'SensorSource.dart';`).
- **`flutter analyze` (full project run):** 7 issues, all pre-existing in unrelated files (`SyncApi.dart`, `UserApi.dart`, `StatsApi.dart`, `BreathTimelineWidget.dart`). Zero findings in any of the 8 changed/new files.
- **Field shapes match spec.**
  - `SensorSource` — `{ neiry, garmin, polar, appleHealth }` ✓
  - `CardioHrvIndices` — six nullable doubles, all optional named ✓
  - `CardioData` — `heartRate`, `metricsAvailable`, `hasArtifacts`, `timestamp`, `source` required; `hrv` nullable ✓
  - `RrInterval` — `intervalMs`, `timestamp`, `isArtifact`, `source` all required ✓
  - `MotionData` — `accelerometer`/`gyroscope` as `({double x, double y, double z})` records, `timestamp`, `source` required ✓

## Findings

### Critical

None.

### Non-blocking observations

1. **Constructor parameter order in `BciNfbData` / `BciEmotionsData` puts `required this.timestamp` first, ahead of the existing optional `delta`/`alpha`/… fields.** This is valid Dart and idiomatic (`required` named-parameters are conventionally listed first). It does change the canonical "shape" of the constructor as documented in `plans/53-…`, but all call sites use named arguments so nothing breaks. Non-issue, purely stylistic.

2. **`BciCardioData` is intentionally left without a `timestamp` field this milestone.** Per the plan and note 32, the cardio-side timestamp will be addressed by the M2 migration when `BciCardioData` is deleted and replaced by the new `CardioData`. Until then `BioSample.fromCardio` (when it lands in M5) would have to fall back to `DateTime.now()` if asked to consume the legacy `BciCardioData` — but the milestone is correctly bounded and this fallback would not exist in any committed code at this point. Worth a future-tripwire note only.

3. **Doc comments added even though `Docs: no` is declared in plan settings.** Each new file carries a short `///` summary (4 of 5 also document the `timestamp` SDK-origin invariant). Implementation choice over the literal setting — the doc strings are short, accurate, and consistent with the existing Phase 19 model conventions. No action.

4. **No `@override` on the constructors of `BciNfbData` / `BciEmotionsData`** — N/A; these are concrete classes without a base. Just noting that the `@immutable` annotation is preserved on both, so analyzer-enforced immutability remains.

5. **`final class` vs `@immutable class` style divergence.** The five new objects use `final class` (Dart 3.0+ class modifier — prohibits subclassing) without `@immutable`, while the existing Phase 19 models use `@immutable class`. Both buy similar guarantees by different routes. Intentional per note 27's spec; consistent within the new directory. No action.

## Positive Notes

- Dependency ordering between tasks was respected; each new file imports only what it needs.
- Doc comments on `CardioData`, `RrInterval`, and `MotionData` correctly emphasize the "timestamp must originate from the SDK" invariant — exactly the load-bearing fact from note 32.
- `MotionData` records mirror `MemsSample` field names (`x`, `y`, `z`) so future per-sample wiring in Phase 21 M3 can pass `s.accelerometer` / `s.gyroscope` straight through.
- Constructor signature changes are minimal and surgical; the diff in `NeiryBciProvider.dart` is two lines and changes nothing else.
- No Flutter, Riverpod, or other framework imports leak into the new value objects — they are pure Dart, matching the architecture rule that the domain layer stays framework-free.

REVIEW_PASS
