# Bump neiry_kit to the calibrator-invalidation fix (836699b)

**Date:** 2026-06-22
**Source:** conversation context + `.ai-factory/handoffs/07-teardown-all-objects-on-device-power-off.md`

## Key Findings

- The recalibration-after-reconnect failure is **not** primarily the locator caching (handoff 06's framing). Its true cause is a dangling **file-static `g_calibrator`** in the kit's native layer: on reconnect, `calibrateIndividual()` calls `nativeStopCalibration` first, which ran `clCNFBCalibrator_SetOnCalibrationStageFinishedEvent` on the **stale calibrator from the destroyed session** → scheduled work on a dead `async_scope` → `try_record_start()` → **recursive `abort` / uncatchable SIGABRT**.
- The catchable `PlatformException(255, "Calibration has already been started")` we saw on-device was only the milder symptom; the real failure escalates to a SIGABRT that no Dart `try/catch` can stop.
- Fixed **entirely inside `neiry_kit`** (native), committed `836699b`: a new `invalidate_calibrator()` nulls `g_calibrator`, and `nativeReleaseDevice` calls it before `clCDevice_Release`, so a post-reconnect stop no-ops. Verified on SM A705FN — no SIGABRT across reconnect+recalibrate.
- **This supersedes handoff 06's claim** "no kit *library* change is needed." A kit change WAS required; mobile must pull it. Phase 52 task 145 (locator recreate) alone would NOT have prevented this SIGABRT.

## Details

### Current state (`mind_mobile`)
- `pubspec.yaml` depends on `neiry_kit` (path/git dependency). The pinned revision predates `836699b`, so the in-app native plugin still has the dangling-`g_calibrator` bug regardless of any Dart-side change.

### Exact change
- Bump the `neiry_kit` dependency to a revision that includes `836699b` (`invalidate_calibrator()` on `nativeReleaseDevice`).
  - If `neiry_kit` is a `path:` dependency, ensure the checked-out kit working tree is at/after `836699b` (no `pubspec` change needed, but document the required commit).
  - If it is a `git:` dependency, update the `ref` to a commit/tag that contains `836699b`.
- Rebuild the Android native plugin (clean build) so the new `.so`/JNI is packaged: `flutter clean` then `flutter run --flavor dev -t lib/main_dev.dart`.
- This is a **prerequisite** for the locator-recreate (145): both land together so the reconnect+recalibrate path is whole (handoff 07 §4).

### Guards
- **Dependency mechanism (pinned):** `neiry_kit` is a **path dependency** — `pubspec.yaml:50` `path: ../neiry_kit`. No `pubspec` edit; just ensure the checked-out `../neiry_kit` working tree is at/after `836699b`, then `flutter clean` + rebuild so the new Android JNI/`.so` is packaged.
- **iOS (accepted, unverified):** `836699b` is **Android-only** (native `android/src/main/cpp/jni_nfb_calibrator.cpp`, `jni_device.cpp`). The iOS bridge (`ios/Classes/NfbCalibratorBridge.swift`) holds the calibrator as an **instance field**, not a file-static global, so the dangling-`g_calibrator` mechanism likely does not occur there — but this is **not tested** (no iOS device available). Ship the Android fix; treat iOS as known-unverified.
- Pure dependency/version change on the mobile side — do not re-implement the calibrator invalidation in `mind_mobile`; it lives in the kit.

### Verify
- Android only: calibrate → disconnect → reconnect → calibrate again completes with **no SIGABRT** and no `code 255`. This is the regression the kit fix targets.
