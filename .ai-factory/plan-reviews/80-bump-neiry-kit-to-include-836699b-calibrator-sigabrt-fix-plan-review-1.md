# Plan Review: Bump `neiry_kit` to include `836699b` (calibrator SIGABRT fix)

**Plan:** `80-bump-neiry-kit-to-include-836699b-calibrator-sigabrt-fix.md`
**Files Reviewed:** 1 plan + codebase verification
**Risk Level:** 🟢 Low

## Verification Performed

Every concrete claim in the plan was checked against the actual trees:

| Claim | Result |
|-------|--------|
| `pubspec.yaml:50` → `path: ../neiry_kit` (path dependency) | ✅ Exact match (line 49–50) |
| `836699b` is an ancestor of `../neiry_kit` HEAD | ✅ `merge-base --is-ancestor` passes; HEAD is `a514f86` |
| `836699b` = calibrator SIGABRT fix | ✅ "Fix recalibration SIGABRT by clearing stale calibrator pointer on device release" |
| `android/src/main/cpp/jni_device.cpp` calls `invalidate_calibrator()` before `clCDevice_Release` | ✅ Lines 274–275: `invalidate_calibrator(); clCDevice_Release(dev);` |
| `jni_nfb_calibrator.cpp` defines `invalidate_calibrator()` nulling `g_calibrator` | ✅ Lines 98–99 |
| iOS `NfbCalibratorBridge.swift` holds calibrator as instance field, not file-static global | ✅ Line 27: `private var calibrator: OpaquePointer?` |

All file paths, line references, commit hash, and the architectural distinction (Android file-static `g_calibrator` vs iOS instance field) are correct.

## Context Gates

- **Architecture:** No boundary/dependency concern. The fix lives entirely in `neiry_kit` (native plugin); the plan explicitly forbids re-implementing it in `mind_mobile`, which respects the module boundary (`lib/Bci/` is a consumer of the kit, not the owner). WARN: none.
- **Rules:** Plan correctly honors "never edit `pubspec.yaml` manually" and "use full flutter path / pub add" conventions — it touches no manifest and adds no dependency. No violation.
- **Roadmap:** Plan is explicitly framed as a prerequisite for task 145. Linkage is stated. WARN: none.

## Critical Issues

None. The plan is accurate and the underlying code state matches its assumptions.

## Observations (non-blocking)

- **The plan is effectively a no-op-by-source / build-and-verify task.** Since kit HEAD already contains `836699b` (confirmed), Task 1 will pass immediately and Task 2 is purely a `flutter clean` + rebuild to flush a possibly-stale cached `.so`. This is correct and appropriately scoped — just be aware there is no source diff to produce.
- **Stale-artifact risk is the real target, and the plan handles it correctly.** `flutter clean` before rebuild is the right move; native plugin `.so` artifacts under `build/` and Gradle caches can otherwise survive a kit source change. Consider also that Gradle may cache the compiled native lib outside Flutter's `build/` — if the rebuilt APK still SIGABRTs, a `./gradlew clean` / `~/.gradle` cache check is the next step (worth keeping in mind during verification, not a plan defect).
- **iOS path is correctly marked accepted-unverified.** The architectural reasoning (instance field can't dangle like a file-static global) is sound and now independently confirmed. Shipping Android-only is reasonable.
- **Verification criteria are concrete and testable** (calibrate → disconnect → reconnect → calibrate, no SIGABRT, no `PlatformException(255)`), which is exactly what a build-only plan needs to be falsifiable.

## Positive Notes

- Pinned the exact commit and gave a deterministic check (`merge-base --is-ancestor`) rather than a vague "make sure it's updated."
- Correctly identified that no Dart-side change is needed and explicitly prohibited duplicating the fix in the app layer.
- Honored project rules: no `pubspec.yaml` edits, path dependency left intact.

PLAN_REVIEW_PASS
