# Plan Review: Migrate `BciCardioData` → `CardioData` across the codebase

**Plan:** `64-migrate-bcicardiodata-cardiodata-across-the-codebase.md`
**Files Reviewed:** 7 source files + plan + roadmap/architecture/rules
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS — the migration stays inside the domain layer (`lib/Bci/` + `lib/Biometrics/`), preserves the existing layering, and does not cross the module boundary. The new `CardioData` lives in `lib/Biometrics/Models/`, which is a domain-side sibling, so no dependency rule is violated. The capability split is correctly deferred to a later milestone, so `cardioStream` staying on `IBciDeviceProvider` is consistent with current architecture.
- **Rules (`.ai-factory/RULES.md`):** PASS — no Service stateful state introduced, no App.dart wiring touched, no constructor-injection rule affected.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS — work is the natural continuation of Phase 20 (biometrics refactor, notes 27 Milestone 2 and 32). The plan correctly cites both.

## Codebase Verification

Cross-checked every claimed touch point against the current source:

| Claim | Verified |
|---|---|
| `BciNotifierEvent.dart` imports `BciCardioData` and `BciCardioUpdated.data` is `BciCardioData` | ✓ (lines 2, 58) |
| `IBciDeviceProvider.dart` declares `Stream<BciCardioData> get cardioStream` with relative import | ✓ (lines 4, 53) |
| `BciDeviceManager.dart` exposes pass-through getter at line 81 | ✓ (lines 7, 81) — and `BciCardioData` appears nowhere else in this file |
| `NeiryBciProvider.dart` cardio controller is at line 40 | ✓ |
| `NeiryBciProvider.dart` cardio getter is at line 74 | ✓ |
| `_onCardioState` lives at lines 271–277 with the listed shape | ✓ |
| `BciNotifier`'s subscriptions are `StreamSubscription<dynamic>?` | ✓ (verified `BciNotifier.dart` lines 22–29 — no edits needed) |
| `BciDataService` reducer only reads `heartRate`, `metricsAvailable`, `hasArtifacts` | ✓ (lines 42–47) — all three fields exist on the new `CardioData` |
| neiry SDK's `CardioData.timestamp` is `DateTime` | ✓ (`neiry_kit/lib/src/models/cardio_data.dart` line 21) — no conversion needed for our `CardioData.timestamp: DateTime` |
| Project-wide search for `BciCardioData` in `lib/` returns only the 4 files the plan touches | ✓ |
| No test file references `BciCardioData` or `cardioStream` | ✓ (searched `test/` and all `packages/*/test/`) |
| No doc file references `BciCardioData` | ✓ |

The plan's grep-and-delete checkpoint in Task 6 is the right discipline; the project-wide scan above confirms it will succeed.

## Critical Issues

None.

## Minor Issues / Nits

1. **Task 4, step 3 — `DeviceLocator` type annotation wording.** The field declaration is `final DeviceLocator _locator = DeviceLocator();` — that's two distinct symbols on one line: the type annotation `DeviceLocator` and the constructor invocation `DeviceLocator()`. The plan lists `DeviceLocator()` → `neiry.DeviceLocator()` but does not separately call out the type annotation, so the resulting line becomes `final neiry.DeviceLocator _locator = neiry.DeviceLocator();` — both halves need the prefix. The implementer would catch this from the analyzer the moment the alias is in place, but worth tightening the wording to "the field declaration on line 25 in full: `final neiry.DeviceLocator _locator = neiry.DeviceLocator();`" to remove any ambiguity. (`Device?`, `NfbClassifier?`, etc. are already unambiguous because they're written as bare type annotations.)

2. **Task 5 — explicit import recommended, not optional.** The plan says "Dart usually resolves the inferred field-access types transitively … but the explicit import is the safest fix if it doesn't". Since `BciDataService.dart` already explicitly imports its other models (`BciConnectionState`, `BciChannelQuality`), adding the explicit `import 'package:mind/Biometrics/Models/CardioData.dart';` up front is cheaper than gating it on analyzer feedback and matches the file's own import-style convention. Suggest making it a deterministic step rather than conditional. Non-blocking.

3. **Task 4, step 6 — `hrv: null` is the only field omitted but worth a one-line spec citation in the code comment.** The plan correctly defers HRV population per note 27, but the migrated `_onCardioState` will silently drop `c.stressIndex` and `c.kaplanIndex` from the SDK payload. Recommend the implementer add a TODO comment referencing `notes/27` so the deferred HRV wiring isn't forgotten. Optional, non-blocking.

## Positive Notes

- Plan correctly identifies that the field-access pattern (`data.heartRate`, `data.metricsAvailable`, `data.hasArtifacts`) is preserved on the new type, so `BciDataService` needs no logic change — this is the kind of cross-file consistency check that often gets missed.
- The neiry alias migration is enumerated exhaustively (fields, locals, subscription generics, classifier instantiations, mapper signatures, switch-case patterns, scan/calibration calls), which is the right discipline given the SDK's `CardioData` symbol clash.
- Dependency chain between tasks is correct: Task 5 depends on both Task 1 (event payload) and Task 4 (provider emit), and Task 6 depends on 1–5. The two-commit split (1–4 = switch, 5–6 = verify + delete) is a sensible reviewable atomic step.
- The plan explicitly scopes out the capability split (separating cardio from `IBciDeviceProvider`) to the next milestone — good discipline; mixing the two would balloon scope.
- Verified that the neiry SDK's `CardioData.timestamp` is already a `DateTime`, matching our model's field type — no risk of accidental `int`/`DateTime` mismatch.

PLAN_REVIEW_PASS
