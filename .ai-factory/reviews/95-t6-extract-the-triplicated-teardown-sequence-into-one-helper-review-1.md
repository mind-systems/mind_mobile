# Code Review: T6 — Extract the triplicated teardown sequence into one helper

**Scope:** `lib/Bci/NeiryBciProvider.dart` (only source file changed). Plan/JSON/plan-review artifacts are docs, not reviewed for correctness.

**Verification performed:**
- Read the full changed file in context (lines 370–588) plus the three test suites that pin the behavior.
- `flutter test test/Bci/` → **all 70 tests pass**, with no test/assertion edits.
- `flutter analyze lib/Bci/NeiryBciProvider.dart` → **No issues found.**
- Confirmed `_cancelDeviceSubscriptions` is fully removed and has **no remaining callers** in source (only doc/plan/review mentions).

## Summary

The refactor is correct and meets the milestone's load-bearing constraint: the canonical teardown order (`stopStream → cancel ×10 → classifier dispose → device.disconnect → device.dispose → recreate`) now lives in exactly one place (`_runOrderedTeardown`), and all three sites delegate to it via `_captureAndNullDeviceState()` + `_runOrderedTeardown(...)`. The B2 ordering probe (exact 7-step list) and the B1 races/no-orphan/recreate invariants stay green. The two parameter axes (`forceStopStream`, `recreate`) faithfully model the drop / disconnect / terminal variation, and `_calibrationSub` non-cancel on drop + terminal-only cancel + no-recreate are all preserved.

No correctness, security, or runtime defects found (no missing migrations, type mismatches, or new races). The notes below are **non-blocking** behavior deltas that are intentional, plan-sanctioned, and not covered by any assertion — recorded here for reviewer awareness.

## Observations (non-blocking)

### 1. disconnect() device disconnect/dispose is now a single combined try-block (was two separate blocks)
`lib/Bci/NeiryBciProvider.dart:477-482`. Previously `disconnect()` wrapped `device.disconnect()` and `device.dispose()` in *separate* try/catch blocks, so `dispose()` ran even if `disconnect()` threw. The shared helper uses one combined block (matching the drop and terminal paths), so a throwing `device.disconnect()` now **skips** `device.dispose()` on the disconnect path. This is the only genuine semantic change for a real device (a throwing native disconnect would skip `nativeRelease`). It is explicitly accepted in Task 4 of the plan as convergence toward the canonical behavior, no test exercises a throwing disconnect on the `disconnect()` path, and the locator is still recreated via the `finally`. Acceptable, but worth a conscious sign-off.

### 2. `_device`/sub fields are now nulled at the start of disconnect() and _doDispose() (was after device disposal)
`_captureAndNullDeviceState()` nulls all 12 fields synchronously before the async teardown body. On the `disconnect()` path this narrows the `_onConnectionStatus` idempotency-guard window: a concurrent native `down` arriving during the helper's `stopStream` await now hits `_device == null` and is suppressed, rather than triggering a re-entrant `_teardownAfterUnexpectedDrop`. This is arguably an improvement (avoids a redundant second teardown) and is harmless — `_connectionSub` is cancelled inside the helper anyway. The drop path's clean-slate guarantee and the "double unexpected-drop" idempotency test both still pass.

### 3. _doDispose() stopStream now logs errors instead of swallowing silently
The terminal path passes `forceStopStream: false`, so a throwing `stopStream()` is now logged via `logPrint` (`:457`) rather than silently swallowed (`catch (_) {}`). Cosmetic only — no test inspects log output.

### 4. Log message text consolidated
`'unexpected drop dispose error'` / `'disconnect error'` / `'dispose error'` collapse to a single `'NeiryBciProvider: device teardown error'` (`:481`). Cosmetic; no test asserts on log text.

### 5. Calibration cancel reordered within _doDispose()
`_calibrationSub` cancel now runs *before* the helper (before `stopStream`) instead of after classifier dispose. `_calibrationSub` shares no state with the device/classifier/locator, no ordering probe covers it, and the plan notes this as behavior-neutral. Confirmed harmless.

## Verdict

Single-source-of-truth achieved, three sites delegate, suites green with zero assertion edits, analyzer clean. No defects requiring changes.

REVIEW_PASS
