# Code Review 2: A1 · LocatorPort + neiry adapter (behavior-preserving)

**Scope reviewed:** `git diff HEAD` / `git status`. Re-review after changes since review-1.

**Verdict:** 🟡 The locator/device seam itself is correct and clean (one prior finding fixed). **But the change set now includes out-of-scope debug logging in three places — including a hot-path log added to the milestone's own file — that violates the "behavior-preserving / byte-identical" guard and should be removed before commit.**

## Status of review-1 findings
- **Finding 1 (unconditional `unsupportedConnection` log) — FIXED.** `NeiryDeviceAdapter.connectionStateStream` now maps `unsupportedConnection → BciLinkStatus.down` **without logging**, and a doc comment (`NeiryDeviceAdapter.dart:54-60`) explicitly explains the log was omitted precisely because adapter-side logging would fire during the post-`disconnect()` noise window. The provider's `_onConnectionStatus` retains the `if (_device == null) return` guard. This is now genuinely behavior-preserving for the connection path. ✅
- **Finding 2 (resistance-mismatch log prefix `NeiryDeviceAdapter:`)** — unchanged; still cosmetic. ✅

## Re-verification
- `flutter analyze lib/Bci/ lib/BreathModule/ test/Bci/` → **No issues found**.
- `flutter test test/Bci/neiry_bci_provider_locator_port_test.dart` → **3/3 pass**.
- Locator seam (factory injection, `_resetLocatorSession` recreate, `scan()` mapping relocation, teardown gate untouched, `App.dart:193` unchanged) — all still correct, as in review-1.

## Findings

### 1. Hot-path debug log added to `NeiryBciProvider._onRrInterval` — out of scope and not behavior-preserving (medium)
`lib/Bci/NeiryBciProvider.dart` (in `_onRrInterval`):
```dart
void _onRrInterval(neiry.RRInterval rr) {
  logPrint('NeiryBciProvider: RR from SDK intervalMs=${rr.intervalMs} isArtifact=${rr.isArtifact}');
  ...
```
This line is new and **unrelated to the LocatorPort milestone**. It fires on **every RR interval** (a hot path, roughly once per heartbeat for the entire session), flooding the logs. The A1 milestone is explicitly "behavior-preserving / byte-identical"; adding per-beat logging to the provider is a behavioral deviation that does not belong in this change. Remove it before committing the milestone.

### 2. Out-of-scope debug logging in BreathModule tick services (medium — scope)
Two files unrelated to BCI/locator work are modified, each gaining a `package:mind/Logger.dart` import plus debug `logPrint` calls:
- `lib/BreathModule/HeartRateTickService.dart` — 3 logs (construction seed, `activated`, `grace expired`).
- `lib/BreathModule/SwitchableTickService.dart` — 3 logs (silent → fallback, `trySwitchTo`, rejected switch).

These belong to a breathing-session tick investigation, not the A1 LocatorPort/neiry-adapter seam. The milestone's hard guard is "single-resource scope (this provider's BCI locator)." Bundling unrelated instrumentation into this commit pollutes the milestone's history and its behavior-preserving claim. Recommend dropping these from this change (revert or move to a separate commit). They are not bugs — `logPrint` is the correct facade and they compile — but they are out of scope.

> Note: all three appear to be leftover/debugging instrumentation. If any are intentional and meant for a different branch/task, they should still be split out so the A1 commit stays scoped.

## Notes (non-findings)
- `(_device as NeiryDeviceAdapter).rawDevice` in `connect()` remains the documented `TODO(A3)` interim for classifier construction — correct in production; the smoke test deliberately never completes a `connect()`. (Same as review-1.)
- The `late final` `.map(...)` streams in `NeiryDeviceAdapter` are listened exactly once per adapter instance; a fresh adapter is built on every reconnect. No re-listen hazard.

## Conclusion
The LocatorPort/DevicePort seam is correct, type-clean, behavior-preserving, and the one substantive review-1 finding was properly fixed. The blocker for this milestone is **scope hygiene, not correctness**: three unrelated debug-logging additions (one on a hot path in the provider, four across two BreathModule files) must be removed so the change is the byte-identical locator seam the milestone specifies. After removing those, this is ready.
