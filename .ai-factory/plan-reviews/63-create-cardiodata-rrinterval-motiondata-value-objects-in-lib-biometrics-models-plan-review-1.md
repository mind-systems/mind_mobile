# Plan Review: 63 — CardioData + RrInterval + MotionData value objects

**Reviewer:** Claude
**Plan:** `.ai-factory/plans/63-create-cardiodata-rrinterval-motiondata-value-objects-in-lib-biometrics-models.md`
**Specs cross-checked:** `notes/27-biometrics-refactor.md` (Milestone 1), `notes/32-biosample-sdk-timestamps.md`, `notes/32-neiry-classifier-timestamps.md`, ROADMAP.md (Phase 21 first bullet)

## Summary

The plan is precise, minimal, and accurately reflects both the Phase 21 M1 spec in note 27 and the timestamp-fix amendment in note 32. All file paths, SDK type references, and field shapes were verified against the live codebase and `neiry_kit` source.

**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — pass. New `lib/Biometrics/Models/` directory follows the layered architecture (pure Dart value objects, no Flutter/Riverpod imports). Backfilling timestamp on `BciNfbData` / `BciEmotionsData` stays inside the existing domain layer.
- **RULES.md** — pass. Rules cover Module Services / DI / App.dart concerns, none of which apply to this milestone (pure data layer, no service or notifier work).
- **ROADMAP.md** — pass. The plan implements the first Phase 21 bullet verbatim, including the note-32 amendment ("Also add `DateTime timestamp` to the existing `BciNfbData` and `BciEmotionsData` … update `NeiryBciProvider._onNfbState` and `_onEmotionsState` to pass `timestamp: state.timestamp`").

## Verification against the codebase

- `lib/Bci/Models/BciNfbData.dart` and `lib/Bci/Models/BciEmotionsData.dart` exist with the shapes the plan assumes (`@immutable` class, `const` constructor, named optional doubles). ✓
- `lib/Bci/NeiryBciProvider.dart::_onNfbState` (line 258) constructs `BciNfbData(delta, theta, alpha, smr, beta)`; `_onEmotionsState` (line 280) constructs `BciEmotionsData(attention, relaxation, cognitiveLoad, cognitiveControl, selfControl)`. Both are the only construction sites in the project (`grep BciNfbData\(` / `BciEmotionsData\(` returns exactly these two lines outside the planning docs). ✓
- SDK types in `neiry_kit/lib/src/models/` confirm:
  - `NfbUserState.timestamp: DateTime` (required) ✓
  - `EmotionsStates.timestamp: DateTime` (required) ✓
  - `CardioData.timestamp: DateTime` (required) — referenced from M2 but matters for the M1 type definition ✓
  - `MemsSample.accelerometer` / `gyroscope` are `({double x, double y, double z})` records ✓
  - `RRInterval.intervalMs`, `timestamp`, `isArtifact` fields match the plan's `RrInterval` shape ✓
- `lib/Biometrics/` does not yet exist (confirmed via `ls`), so the new directory and files are truly additive. ✓

## Findings

### Non-blocking observations

1. **Style divergence from Phase 19 models, intentional but mis-described.** Task 2 says "Follows the same style as existing Phase 19 BCI models (no `@immutable` annotation required; `final class` is sufficient)." The existing Phase 19 models (`BciNfbData`, `BciEmotionsData`, `BciCardioData`, `BciChannelQuality`) actually use `@immutable class`, not `final class`. The new objects intentionally adopt the `final class` style prescribed by note 27. Reword to "Follows the style prescribed by note 27 — `final class` without `@immutable`; this is an intentional stylistic shift from the Phase 19 models." Not a code issue, just an inaccurate parenthetical that could confuse the implementer.

2. **Field order in `CardioData` differs from note 27.** Note 27 spec lists `heartRate, metricsAvailable, hasArtifacts, source, hrv`; the plan inserts `timestamp` between `hasArtifacts` and `source`. Since all params are named, ordering is unobservable at call sites and does not affect correctness. Worth flagging only because note 32 says "alongside" without specifying order. No action needed.

3. **No dartdoc on the new classes.** Settings declare `Docs: no`, and the spec snippets in note 27 don't include doc comments. The existing Phase 19 models do carry short dartdocs (e.g. `BciNfbData`'s "Raw NFB band amplitudes…"). Optional — staying consistent with `Docs: no` is fine, but a one-line `///` summary per file would match local convention with near-zero cost.

4. **`required` change in `BciNfbData` / `BciEmotionsData` constructors is technically breaking.** The plan correctly identifies only two call sites and updates both in Task 8. The greps confirm no other call sites exist (no test fixtures, no fakes). The change is safe in this codebase but should be remembered as a tripwire for any future plan that introduces a fake/mock of these models.

5. **`BciCardioData` is intentionally left without a timestamp field this milestone.** The plan calls this out explicitly. This is consistent with note 32, which routes the cardio-side timestamp through the M2 migration to the new `CardioData` — `BciCardioData` will be deleted before any consumer would benefit from a timestamp on it.

### Critical Issues

None.

### Positive Notes

- Dependency ordering between tasks (1 → 2,4,5 / 1,2 → 3 / 6,7 → 8) is correct and lets Phase 1 ship as a self-contained commit before Phase 2 touches the provider.
- Commit plan splits cleanly along the additive-vs-modifying boundary; commit 1 is risk-free, commit 2 is bounded to one file plus two model field additions.
- The plan correctly resolves the latent disagreement between note 27 (no `timestamp` on `CardioData`) and note 32 (timestamp required) in favor of note 32, matching the ROADMAP wording.
- Task 8 correctly notes that no new imports are needed in `NeiryBciProvider.dart` — both SDK types `NfbUserState` and `EmotionsStates` are already imported via `package:neiry_kit/neiry_kit.dart`. Verified.
- `MotionData` is correctly defined with Dart records mirroring `MemsSample`, including the same record-field naming (`x`, `y`, `z`) so future per-sample copy in `NeiryBciProvider` (Phase 21 M3) can pass `s.accelerometer` / `s.gyroscope` straight through without restructuring.
- The plan's note that the actual SDK-timestamp wiring for `CardioData` lands in the next milestone correctly avoids smuggling M2 work into M1.

PLAN_REVIEW_PASS
