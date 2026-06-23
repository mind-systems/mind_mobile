# Plan: Bump `neiry_kit` to include `836699b` (calibrator SIGABRT fix)

## Context
Ensure the checked-out `../neiry_kit` path dependency includes `836699b` (`invalidate_calibrator()` nulling `g_calibrator` on `nativeReleaseDevice`) and rebuild so the fixed Android JNI/`.so` is packaged — closing the recalibrate-after-reconnect SIGABRT. Prerequisite for task 145.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Confirm kit revision

- [x] **Task 1: Verify `../neiry_kit` includes `836699b`**
  Files: `../neiry_kit` (working tree, no edits)
  `neiry_kit` is a path dependency — `pubspec.yaml:50` `path: ../neiry_kit`. Do NOT edit `pubspec.yaml`. Run `git -C ../neiry_kit merge-base --is-ancestor 836699b HEAD && echo OK` to confirm the checked-out kit tree contains the fix commit. If it does not, check out a revision at/after `836699b` before proceeding. (As of writing, kit HEAD already contains `836699b`.) Confirm `../neiry_kit/android/src/main/cpp/jni_device.cpp` calls `invalidate_calibrator()` (or equivalent) before `clCDevice_Release`, and that `jni_nfb_calibrator.cpp` defines it nulling `g_calibrator`.

### Phase 2: Rebuild with fixed native plugin

- [x] **Task 2: Clean and rebuild so the new Android JNI/`.so` is packaged** (depends on Task 1)
  Files: build artifacts only (no source edits)
  Run `flutter clean` to drop the stale native plugin build, then rebuild the dev flavor: `flutter run --flavor dev -t lib/main_dev.dart` (or `flutter build apk --flavor dev -t lib/main_dev.dart`). This guarantees the recompiled `neiry_kit` `.so`/JNI carrying `836699b` is bundled into the APK rather than a cached pre-fix artifact. No Dart-side change is required — the calibrator invalidation lives entirely in the kit; do not re-implement it in `mind_mobile`.

## Notes
- **iOS (accepted, unverified):** `836699b` is Android-only. The iOS bridge (`ios/Classes/NfbCalibratorBridge.swift`) holds the calibrator as an instance field, not a file-static global, so the dangling-`g_calibrator` mechanism likely does not occur there — but this is not tested (no iOS device). Ship the Android fix; treat iOS as known-unverified.
- **Verification (Android only):** calibrate → disconnect → reconnect → calibrate again completes with no SIGABRT and no `PlatformException(255, "Calibration has already been started")`. This is the regression the kit fix targets.
- This is a prerequisite for task 145 (locator recreate); both land together so the reconnect+recalibrate path is whole.
