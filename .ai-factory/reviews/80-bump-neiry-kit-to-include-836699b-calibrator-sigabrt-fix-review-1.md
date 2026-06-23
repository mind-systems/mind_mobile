# Code Review: Bump `neiry_kit` to include `836699b` (calibrator SIGABRT fix)

## Scope

`git diff HEAD` / `git status` show the only changes in `mind_mobile` are planning
artifacts:

- `.ai-factory/plans/80-...-calibrator-sigabrt-fix.md`
- `.ai-factory/plans/80-...-calibrator-sigabrt-fix.json`
- `.ai-factory/plan-reviews/80-...-plan-review-1.md`

There are **no Dart, native, build-config, or `pubspec` source changes** in this
repo. That is correct for this milestone: `neiry_kit` is a path dependency
(`pubspec.yaml:50` → `path: ../neiry_kit`), so the fix arrives by the checked-out
kit tree advancing past `836699b` plus a clean rebuild — not by any edit here.
The plan explicitly forbids a `pubspec` edit and forbids re-implementing the
calibrator invalidation in `mind_mobile`; both constraints are honored.

## Verification of the deliverable

- `git -C ../neiry_kit merge-base --is-ancestor 836699b HEAD` → **YES**. The
  checked-out kit (HEAD `a514f86`) contains the fix commit. Task 1's prerequisite
  is genuinely satisfied, not just asserted.
- Working trees are clean: `mind_mobile` has only the three staged plan files;
  `neiry_kit` is clean and up to date with `origin/master`.
- The fix itself is sound. `invalidate_calibrator()`
  (`jni_nfb_calibrator.cpp:98`) nulls `g_calibrator` **without** calling any
  `clCNFBCalibrator_*` on the stale pointer, and `nativeReleaseDevice`
  (`jni_device.cpp:275`) invokes it *before* `clCDevice_Release`. A subsequent
  post-reconnect `nativeStopCalibration` then sees `g_calibrator == nullptr`
  (`jni_nfb_calibrator.cpp:81`) and no-ops, which is exactly the SIGABRT path the
  milestone targets.

## Notes / non-blocking observations

- **Task 2 (clean rebuild) is not verifiable from repository state.** The
  recompiled `.so`/JNI is a build artifact, not committed. The correctness of
  this milestone at runtime depends on `flutter clean` + rebuild having actually
  re-bundled the post-`836699b` native plugin; a stale cached `.so` would silently
  reintroduce the crash with no diff to show for it. This is inherent to the
  task, not a defect — flagged so the on-device verification (calibrate →
  disconnect → reconnect → calibrate, no SIGABRT / no `code 255`) is treated as
  the real acceptance gate.
- **Out of scope (kit, pre-existing):** `g_cal_mutex` exists
  (`jni_nfb_calibrator.cpp:34`) but neither `nativeStartCalibration`,
  `nativeStopCalibration`, nor `invalidate_calibrator()` lock it around
  `g_calibrator` access. A data race between device-release and a concurrent
  stop/callback is theoretically possible. This predates and is unrelated to this
  milestone's diff and lives in `neiry_kit`, not `mind_mobile`; noted only for
  follow-up, not as a finding against these changes.

## Conclusion

No code changes in `mind_mobile` to fault, the dependency prerequisite is
confirmed present, and the shipped kit fix is correct. No defects in the changes
under review.

REVIEW_PASS
