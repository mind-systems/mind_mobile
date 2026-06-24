# Plan: Serialize calibration through the queue + guard against dispose (T1)

## Context
The three calibration methods in `NeiryBciProvider` (`startCalibration`, `startQuickCalibration`, `importCalibration`) run **outside** the `SerialCommandQueue` and have no dispose guard, causing an add-after-close crash (`Bad state: Cannot add event after closing`) and a lifecycle race against device teardown. This milestone routes all three through `_queue.enqueue(...)` and adds a closed-controller/dispose guard.

## Decision (A vs B)
**Resolved: Option A (recommended by spec `165-bci-serialize-calibration-through-queue.md`).** Route all three calibration methods through `_queue.enqueue(...)` **and** add a `_disposed`/closed-controller guard. This closes both failure modes — (a) add-after-close crash and (b) the lifecycle race — whereas Option B (guard only) closes (a) but leaves (b) open. Option A is queue-safe per the queue's CONSTRAINT 1: a calibration command only awaits the static `neiry.NfbCalibrator.*` futures/stream, never another `_queue` operation, so there is no self-deadlock.

## Settings
- Testing: yes (regression test for the crash; keep B1/B2 suites green)
- Logging: minimal (preserve existing `logPrint` call sites; no new logging)
- Docs: no

## Tasks

### Phase 1: Serialize + guard the calibration methods (Option A)

- [x] **Task 1: Add a guarded calibration-emit helper**
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add a private method `void _emitCalibration(BciCalibrationEvent event)` that returns early when `_disposed || _calibrationController.isClosed`, otherwise calls `_calibrationController.add(event)`. This is the "closed-controller guard" half of Option A — it protects every emit path (including the long-lived `startCalibration` subscription whose events arrive outside the queue slot) against an add on a closing/closed controller. Place it near the calibration methods (after `importCalibration`, before `disconnect`).

- [x] **Task 2: Route `startCalibration` through the queue + guard** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart` (method at `:275`)
  Wrap the body in `return _queue.enqueue(() async { ... })`. Inside the command, first `if (_disposed) return;`, then `await _calibrationSub?.cancel();` before assigning the new `neiry.NfbCalibrator.calibrateIndividual().listen(...)` subscription. Replace both `_calibrationController.add(...)` calls and the `onError` add with `_emitCalibration(...)`. The command body sets up the subscription and returns quickly (the subscription persists outside the slot, which is correct — its events are now guarded by `_emitCalibration`). Do **not** await the subscription itself (that would never complete).

- [x] **Task 3: Route `startQuickCalibration` through the queue + guard** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart` (method at `:311`)
  Wrap the body in `return _queue.enqueue(() async { ... })`. Inside: `if (_disposed) return;`, then keep the existing `await _calibrationSub?.cancel(); _calibrationSub = null;`, then the `try { await neiry.NfbCalibrator.calibrateIndividualQuick(); ... }` block. Replace the success and `catch` `_calibrationController.add(...)` calls with `_emitCalibration(...)`. Note: this command holds the queue slot for the full quick-calibration duration — that serialization against `disconnect()`/teardown is intentional and closes lifecycle race (b). This is queue-safe (CONSTRAINT 1): it awaits only the static `neiry` future.

- [x] **Task 4: Route `importCalibration` through the queue + guard** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart` (method at `:339`)
  Wrap the body in `return _queue.enqueue(() async { ... })`. Inside: `if (_disposed) return;`, then keep the existing `neiry.IndividualNfbData(...)` construction and `await neiry.NfbCalibrator.importCalibrationData(neiryData);`. No `_emitCalibration` needed here (this method does not emit calibration events).

### Phase 2: Verify

- [x] **Task 5: Add a regression test for post-dispose calibration safety** (depends on Tasks 2-4)
  Files: `test/Bci/neiry_bci_provider_command_queue_test.dart`
  Add a characterization test (or a focused new group) asserting that calling `startQuickCalibration()` (and/or `startCalibration()`) **after** `dispose()` no longer throws `Bad state: Cannot add event after closing`. Build the provider with the existing fake locator/device/classifier ports already used in this suite; call `dispose()`, await `_queue.idle` equivalent / a microtask flush, then invoke a calibration method and assert no add-after-close error surfaces (the enqueue is rejected with `QueueClosedException`, which the test may expect and tolerate). Then run the full BCI suite and the analyzer to confirm nothing regressed:
  - `/usr/local/bin/flutter analyze`
  - `/usr/local/bin/flutter test test/Bci/` (B1 = `neiry_bci_provider_locator_device_races_test.dart`, B2 = `neiry_bci_provider_full_teardown_test.dart` must stay green)

## Constraints & guards (must preserve)
- **Do NOT cancel `_calibrationSub` in the drop path.** `_teardownAfterUnexpectedDrop` (`:382`) deliberately leaves `_calibrationSub` and the controllers alive so reconnect can resume (comment at `:380`). Only `_doDispose` (terminal, `:549`) cancels it. The fix must not add a calibration-sub cancel to the drop path.
- **Do NOT touch `SerialCommandQueue`'s three CONSTRAINTs** or its `close()`/`enqueue()` semantics.
- **Caller impact is safe:** `BciDeviceManager.startCalibration`/`startQuickCalibration` (`:237`/`:251`) already wrap the provider call in `try/catch` + `logPrint` + state reset, so a post-dispose `QueueClosedException` is caught and logged, not crashed. `importCalibration` has no current caller. No manager changes required.
- **Out of scope:** the 11-field neiry↔domain mapping duplicated across `startCalibration`/`startQuickCalibration` is a separate extraction task (note `171-bci-extract-calibration-mapping`). Do not extract it here.

## Done-when
- All three calibration methods are queue-serialized and dispose/closed-controller guarded (Option A).
- A post-dispose calibration call (or a late calibration event) no longer throws `Bad state: Cannot add event after closing`, and no `_calibrationSub` leaks.
- `flutter analyze` is clean and `flutter test test/Bci/` is fully green (B1/B2 unchanged).
