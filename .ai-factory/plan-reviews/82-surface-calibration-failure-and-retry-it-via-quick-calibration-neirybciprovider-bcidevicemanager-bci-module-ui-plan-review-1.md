# Plan Review: Surface calibration failure and retry via quick calibration

**Plan:** `82-surface-calibration-failure-and-retry-it-via-quick-calibration-...`
**Files Reviewed (verified against codebase):** 12
**Risk Level:** 🟢 Low

## Verdict

The plan is accurate, well-scoped, and grounded in the real codebase. Every file path,
line reference, API name, and type assumption was checked against the actual source and
holds up. The cross-event reducer ordering reasoning (Task 6 note) is correct. No blocking
issues found.

## Verification of Key Assumptions

- **`neiry.NfbCalibrator.calibrateIndividualQuick()` exists** — confirmed at
  `neiry_kit/lib/src/api/nfb_calibrator.dart:192`. Signature is
  `static Future<IndividualNfbData> calibrateIndividualQuick()` — a single awaited Future,
  emits no stage events, resolves on `CalibrationCompleted` (carrying validity via
  `failReason`). The plan's Task 1 mapping (await the Future, mirror the full-flow mapping,
  emit `BciCalibrationCompleted`/`BciCalibrationFailed`) is correct. No `neiry_kit` change needed. ✓
- **Fail-reason string values** — `tooManyArtifacts` and `peakFrequencyAtBorder` confirmed as
  the exact `.name` values of `neiry_kit`'s `NfbCalibrationFailReason` enum
  (`nfb_calibration_fail_reason.dart`). `isValid` ⇔ `failReason == none`. The provider maps
  `failReason.name` → domain `String`, and the UI helper (Task 9) matches those exact strings. ✓
- **Domain `NfbCalibrationData.failReason` is a `String`** (`lib/Bci/Models/NfbCalibrationData.dart`)
  with documented allowed values matching the UI mapping. DTO `failReason: String?` assignment is type-safe. ✓
- **Line references** in `NeiryBciProvider.dart` (381-393), `IBciDeviceProvider.dart` (53),
  `BciDeviceManager.dart` (80-98, 234-246), `BciConnectionState.dart` (53-55),
  `BciNotifier.dart` (111), `IBciPairingService.dart` (20), `BciPairingService.dart`
  (47, 150, 153-200), `BciCalibrationProgressDTO.dart`, `BciPairingViewModel.dart` (46),
  `BciCalibrationSection.dart` (90, 133-167) — all accurate. ✓
- **DTO construction sites** — `grep` confirms `BciCalibrationProgressDTO(` is constructed in
  exactly the four `BciPairingService.dart` locations the plan touches (160, 184, 192, and the
  198 `null`→DTO replacement). No tests or other call sites construct it, so making
  `totalStages`/`failed` required will not produce uncovered compile errors. ✓
- **`BciCalibrating` construction site** — only one (`BciDeviceManager.dart:237`); the two other
  occurrences (`BciPairingService.dart:153`, `BciDataService.dart:80`) are *pattern matches*, not
  constructions, and adding a named field does not break them. ✓
- **Reducer cross-event ordering** — verified: the `BciImpedance` reducer branch (144-151) never
  touches `calibration`, and the `BciCalibrationCompleted`/`Failed` branches never touch `stage`.
  The final reduced state (`stage: impedance`, `calibration.failed: true`) is order-independent,
  exactly as the plan's Task 6 note claims. ✓

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — present. The change respects the layered
  boundary: `neiry_kit` stays isolated in `NeiryBciProvider`; the new method is added to
  `IBciDeviceProvider` first; domain → DTO conversion happens in the reducer; the package never
  sees domain models. No boundary violation. **OK.**
- **Rules (`.ai-factory/RULES.md`)** — present. Rule 1 (Module Services must be stateless):
  `BciPairingService.startQuickCalibration()` only delegates to the notifier, adding no
  `StreamController`/`StreamSubscription`/`dispose`. Rule 2 (no App.dart changes): none planned.
  Rule 3 (constructor DI): unchanged. **OK.**
- **Roadmap (`.ai-factory/ROADMAP.md`)** — present. This is a `fix`-class change (invalid
  calibration misreported as success). **WARN:** the plan does not reference a roadmap milestone
  for linkage. Non-blocking — note it when committing if a matching milestone exists.

## Non-Blocking Observations

1. **`_setState` dedup ignores `totalStages` (advisory).** `BciDeviceManager._setState`
   (line 127-137) dedupes `BciActive` transitions on `runtimeType` + `serial` only — not on
   `totalStages`. A direct `BciCalibrating(serial, totalStages: 4)` → `BciCalibrating(serial,
   totalStages: 1)` transition would be silently swallowed. In this plan that transition never
   occurs directly (full→quick always routes through `BciImpedance` first), so there is no live
   bug. Worth a one-line comment near the new `startQuickCalibration` so a future caller doesn't
   introduce a direct calibrating→calibrating switch and lose the event.

2. **`const` on `BciCalibrating` constructor (cosmetic).** Task 2's snippet drops the `const`
   keyword (`BciCalibrating(super.serial, {required this.totalStages})`). Adding a `final` field
   is compatible with a `const` constructor, and the sole construction site (line 237) is
   non-const, so either form compiles. Prefer keeping `const` for consistency with the sibling
   states (`BciImpedance`, `BciReady` are all `const`).

3. **Provider catch makes the manager catch defensive-only (intended).** Task 1 has the provider
   catch the quick-calibration throw internally and emit `BciCalibrationFailed`, so
   `await _provider.startQuickCalibration()` in Task 3 completes normally and the manager's
   try/catch becomes a redundant safety net. Harmless; keep it.

4. **l10n regeneration command (minor).** Task 8 offers `flutter gen-l10n` *or* `build_runner`.
   `packages/mind_l10n` uses `l10n.yaml`, so `flutter gen-l10n` is the correct path; `build_runner`
   is unnecessary for ARB→`AppLocalizations`. The new keys carry no placeholders, so generation
   is trivial.

## Positive Notes

- Correctly identifies that failure text must live on the `calibration` DTO, **not** `errorMessage`
  (which the `BciImpedance` reducer branch wipes to `null` at line 150) — a subtle trap the plan
  pre-empts explicitly.
- Reuses the exact existing full-flow mapping for the quick path, keeping the provider's two
  calibration entry points structurally identical.
- Keeps the green-check / failure-block / retry-button states mutually exclusive in the UI guard
  conditions, preventing a "complete + failed" visual contradiction.
- Phasing (domain → DI passthrough → DTO/reducer → presentation) with matching commit boundaries
  is clean and each phase compiles independently.

PLAN_REVIEW_PASS
