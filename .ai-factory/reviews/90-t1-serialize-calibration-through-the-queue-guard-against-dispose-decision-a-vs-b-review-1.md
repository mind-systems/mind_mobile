# Code Review: Serialize calibration through the queue + guard against dispose (T1)

**Plan:** `90-t1-serialize-calibration-through-the-queue-guard-against-dispose-decision-a-vs-b.md`
**Files reviewed (in full):** `lib/Bci/NeiryBciProvider.dart`, `test/Bci/neiry_bci_provider_command_queue_test.dart`, plus surrounding context: `lib/Bci/SerialCommandQueue.dart`, `lib/Bci/BciDeviceManager.dart`, `lib/Bci/BciNotifier.dart`.
**Verification:** `flutter analyze` (changed files) → clean; `flutter test test/Bci/` → **63/63 pass** (was 61; B1 `locator_device_races` + B2 `full_teardown` green, no assertion edits; 2 new post-dispose tests pass).
**Risk Level:** 🟢 Low

## Summary

The implementation faithfully applies Option A: all three calibration methods (`startCalibration` `:275`, `startQuickCalibration` `:314`, `importCalibration` `:345`) now return `_queue.enqueue(() async { ... })` with a leading `if (_disposed) return;`, and a new `_emitCalibration` helper (`:366`) guards every controller add against `_disposed || _calibrationController.isClosed`. The change is correct, compiles clean, and preserves the required invariants.

## Correctness analysis

- **Add-after-close crash (a) — closed.** Two independent mechanisms cover it:
  - *Post-dispose call:* `dispose()` runs `_doDispose()` which sets `_disposed = true` and calls `_queue.close()` synchronously before its first `await`. Any subsequent `startCalibration`/`startQuickCalibration`/`importCalibration` enqueue is rejected with `QueueClosedException` and the command body never runs — so no `_calibrationController.add` is attempted, and the SDK static call is never invoked.
  - *Late streaming event:* the long-lived `calibrateIndividual()` subscription emits outside the queue slot, but every emit now routes through `_emitCalibration`, which returns early once `_disposed` is set or the controller is closed. `_disposed` is set at the very top of `_doDispose`, so events arriving anywhere in the dispose window are dropped silently. Correct.
- **Lifecycle race (b) — closed for the future-based paths.** `startQuickCalibration` and `importCalibration` `await` their SDK work *inside* the queue slot, so a drop-triggered teardown command (enqueued by `_teardownAfterUnexpectedDrop`) is serialized strictly after them — no concurrent native device teardown. For the full `startCalibration` subscription path, race (b) is only *partially* closed (the subscription outlives the slot), but this is the inherent, accepted consequence of the "do not cancel `_calibrationSub` in the drop path" constraint, and the `_emitCalibration` guard still prevents any crash. Consistent with spec note `165`. Not a defect.
- **No self-deadlock (queue CONSTRAINT 1).** Each command awaits only `_calibrationSub?.cancel()` and a static `neiry.NfbCalibrator.*` future/stream — never another `_queue` operation. Verified. Safe.
- **Preserved constraint — drop path untouched.** The diff's only `_calibrationSub?.cancel()` edits are the two inside the calibration methods (now awaited and indented into the closure). `_teardownAfterUnexpectedDrop` (`:382`) and `_doDispose`'s terminal cancel (`:549`) are unchanged — resume-after-reconnect behavior is intact.
- **Caller impact — safe.** `BciDeviceManager.startCalibration`/`startQuickCalibration` already wrap the provider call in `try/catch` + `logPrint` + state reset, so the new `QueueClosedException` on a post-dispose call is caught and logged, not surfaced as a crash. `importCalibration` has no caller in `lib/`. No manager changes needed.
- **Type/analyzer.** Dropping `async` from the method signatures and returning `Future<void>` from `enqueue<void>(...)` type-checks correctly; analyzer reports no issues.

## Test quality

- The two new tests correctly exploit that `_queue.close()` is synchronous within `dispose()`, so the post-dispose enqueue rejects *before* running the body — which is also why the real `neiry.NfbCalibrator` SDK is never touched in the test environment. The `try/on QueueClosedException` + `isA<QueueClosedException>()` assertion is the right shape (no bare `await` that would surface the rejection as a failure), and the double microtask flush matches the established pattern in the existing dispose tests.
- No leaked subscriptions: since the command body never runs post-dispose, no `calibrateIndividual().listen(...)` is created.

## Observations (non-blocking)

1. The `if (_disposed) return;` at the top of each command is effectively redundant with the queue rejection (both `_disposed = true` and `_queue.close()` happen synchronously together in `_doDispose`), but it is harmless defense-in-depth and worth keeping for clarity.

## Conclusion

The change meets all done-when criteria: all three calibration methods are queue-serialized and dispose/closed-controller guarded, the add-after-close crash is eliminated, the drop-path constraint is preserved, and `flutter analyze` + `flutter test test/Bci/` are fully green with B1/B2 unchanged. No bugs, security issues, or correctness problems found.

REVIEW_PASS
