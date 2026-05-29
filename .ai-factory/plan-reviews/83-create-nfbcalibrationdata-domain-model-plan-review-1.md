# Plan Review: Create `NfbCalibrationData` domain model

**Plan:** `83-create-nfbcalibrationdata-domain-model.md`
**Files Reviewed:** 1 plan, 4 reference files (`BciNfbData.dart`, `BciDeviceInfo.dart`, `BciCalibrationEvent.dart`, `ExerciseSet.dart`), ROADMAP Phase 24, RULES.md, ARCHITECTURE.md
**Risk Level:** 🟢 Low

## Summary

The plan is a single-file additive change that creates a pure-Dart domain model in `lib/Bci/Models/NfbCalibrationData.dart` and modifies no other code. It aligns precisely with ROADMAP Phase 24 Task 1 and the architectural conventions used by the neighbouring BCI models.

## Context Gates

- **ARCHITECTURE.md** — ✅ PASS. The plan respects the domain/module boundary: pure Dart, no `neiry_kit` import, no Flutter or Riverpod dependencies (only `package:flutter/foundation.dart` for `@immutable`, which matches `BciNfbData.dart` and `BciDeviceInfo.dart`). The model lives in `lib/Bci/Models/` alongside other domain projections.
- **RULES.md** — ✅ PASS. The three rules concern stateless module Services, App.dart purity, and constructor DI. None apply to a value-object model; nothing in the plan violates them.
- **ROADMAP.md** — ✅ PASS. The plan implements Phase 24 Task 1 exactly: field set, JSON serialization, `failReason` enum-like string, no other file touched. Subsequent Phase 24 tasks (carry through `BciCalibrationCompleted`, `importCalibration`, repository, App wiring) reference this model and would receive it correctly.

## Critical Issues

None.

## Minor Notes / Verifications

1. **Field-order consistency with subsequent tasks.** Phase 24 Task 2 (carry through `BciCalibrationCompleted`) and Task 3 (`importCalibration`) imply a reverse-mapping to `neiry.IndividualNfbData`. The plan specifies the field order (`calibratedAt`, `isValid`, `failReason`, then seven doubles) which matches the order they appear in `.ai-factory/notes/30-nfb-calibration-history.md` (referenced by the roadmap). The named-parameter constructor means call sites are robust to reorder, so this is purely a readability concern — no issue.

2. **`fromJson` numeric tolerance.** The plan correctly specifies `(json['<field>'] as num).toDouble()` for the seven `double` fields. This is the right choice — `jsonDecode` returns `int` for whole-number JSON literals (e.g. `0`, `10`), and a direct `as double` cast would throw. This is more defensive than `ExerciseSet.fromJson`, but justified because calibration values include integer-valued frequency boundaries.

3. **`calibratedAt` round-trip.** `toIso8601String()` + `DateTime.parse(...)` is the standard idiom and preserves timezone offset and sub-second precision. No issue.

4. **`failReason` as a string vs enum.** The plan chooses an enum-like `String` ("none" / "tooManyArtifacts" / "peakFrequencyAtBorder") rather than a Dart `enum`. This is intentional and consistent with note 30's serialization strategy and with Task 3's reverse mapping (`NfbCalibrationFailReason.values.firstWhere((e) => e.name == data.failReason)`), which depends on the string matching the SDK enum's `.name`. The Dartdoc requirement in the plan documents the closed set — sufficient at this layer. A future refactor to a typed enum is non-blocking.

5. **`@immutable` + all-final fields + `const` constructor.** Matches both reference files (`BciNfbData`, `BciDeviceInfo`). No equality/hashCode override is requested, which is consistent with the neighbours; if downstream code (the repository in Phase 24 Task 4) ever needs set-membership or deduplication, an `==`/`hashCode` override would be added then — out of scope here.

6. **Dartdoc on the class.** The Phase 17 post-review fix removed multi-line `///` docstrings from `IBciPairingService.dart` and `BciCalibrationProgressDTO.dart`, but those were inside `packages/bci_module/` (the presentation package). Domain models in `lib/Bci/Models/` (`BciNfbData`, `BciDeviceInfo`, `BciCalibrationEvent`) all carry class-level Dartdoc, so the plan's docstring requirement is consistent with the layer.

7. **No callers updated** — the plan explicitly defers consumer wiring to Phase 24 Tasks 2–5. Good scope discipline; the file compiles in isolation.

## Positive Notes

- Single-file scope is well-bounded — minimum surface area for a domain primitive.
- Field list is fully specified including order and serialization key names — implementation is mechanical.
- The plan calls out the cast-tolerance pattern (`as num).toDouble()`) explicitly, preventing a common JSON-decode bug.
- Pure-Dart constraint is stated twice (header + Task 1 first bullet) — domain/plugin boundary respected.
- Explicit reference to three pattern sources (`BciNfbData`, `BciDeviceInfo`, `ExerciseSet`) gives the implementer concrete templates to copy.
- Scope discipline ("Do not modify any other file") protects the additive milestone from accidental coupling.

PLAN_REVIEW_PASS
