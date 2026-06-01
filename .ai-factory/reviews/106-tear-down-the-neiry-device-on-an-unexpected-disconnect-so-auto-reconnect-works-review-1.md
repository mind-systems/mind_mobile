# Code Review: Tear down the neiry `Device` on an unexpected disconnect

**Scope:** `lib/Bci/NeiryBciProvider.dart` (the only code file changed)
**Reviewed against:** plan `106-tear-down-the-neiry-device-on-an-unexpected-disconnect-so-auto-reconnect-works.md` and the spec note `52-task-neiry-device-teardown-on-drop.md`.

## What the change does

In `_onNeiryConnectionState`, the `disconnected` and `unsupportedConnection` cases now:
1. Bail early via `if (_device == null) return;` (true no-op idempotency guard).
2. Call `_teardownAfterUnexpectedDrop()`, which **synchronously** captures the device + 4 classifiers + 10 device-stream subscriptions into locals, nulls all the corresponding fields, and schedules the heavy disposal (cancel subs, dispose classifiers, `disconnect()`+`dispose()` the device) on an `unawaited(Future.microtask(...))`.
3. Emit `BciConnectionState.disconnected` **after** the synchronous nulling.

## Correctness verification

I traced the full unexpected-drop → reconnect path through `BciDeviceManager`:

- **Load-bearing ordering holds.** `_teardownAfterUnexpectedDrop()` nulls `_device` synchronously before `_connectionStateController.add(disconnected)`. `BciDeviceManager`'s listener (`BciDeviceManager.dart:61`) reacts to the emit by calling `_attemptReconnect()` (unawaited), which scans (5 s) before `connectDevice → _provider.connect()`. By the time `connect()` runs, `_device == null`, so the `StateError` guard at `connect()` (`NeiryBciProvider.dart:148`) does not fire and a fresh device is created. ✅
- **No SIGABRT from non-idempotent classifiers.** The old classifiers are disposed on the captured locals; reconnect creates new classifiers on a *new* `Device` instance. Classifiers are never created twice on the same `Device`. ✅
- **Disposal/reconnect timing.** The microtask disposal is fast and completes well before the 5 s scan finishes, so the old device's `disconnect()`/`dispose()` runs before reconnect's `connect()` — no native resource contention on the serial. ✅
- **Subscription set is complete and matches `_cancelDeviceSubscriptions()`.** All 10 device-stream subs are captured and cancelled (`_connectionSub`, `_resistanceSub`, `_batterySub`, `_nfbSub`, `_nfbErrorSub`, `_cardioSub`, `_rrSub`, `_emotionsSub`, `_emotionsErrorSub`, `_memsSub`). `_calibrationSub` is correctly excluded (matching `_cancelDeviceSubscriptions()`); on reconnect, `startCalibration()` cancels it before re-listening, so no leak. ✅
- **Controllers stay open.** No `StreamController` is touched, so the manager keeps receiving post-reconnect data. ✅
- **Re-entrancy avoided.** Cancelling `_connectionSub` from within its own callback is deferred to a microtask, so no cancel-during-dispatch hazard. ✅
- **Idempotency / double-teardown safety.** If our own `disconnect()` runs concurrently or a second native event arrives, the captured-local + field-null pattern means each object is disposed at most once, and all `?.` calls are null-safe. The guard suppresses a redundant second `disconnected` emit; this is safe because our own `disconnect()` already cancels `_connectionSub` and emits its own `disconnected`, so no legitimate disconnected signal is lost. ✅
- **`unawaited` is imported** (`dart:async`, line 1) and already used elsewhere in the file. Compiles. ✅

## Non-blocking observations (no action required for this task)

- **Cancel calls in the microtask are not try/caught.** Same as the existing `_cancelDeviceSubscriptions()` (only `dispose()` calls are wrapped there). `StreamSubscription.cancel()` throwing is extremely unlikely, and since the body is `unawaited` an error would surface only as an unhandled async error — consistent with existing code, not a regression.
- **Pre-existing edge case, out of scope:** a native drop during `connectDevice`'s awaited `importCalibration` window (while `_state == connecting`) is ignored by the manager's reconnect listener (`BciDeviceManager.dart:65`), so no reconnect is scheduled and the manager can settle into `ready`/`impedance` with `_device == null`. This race exists independently of this change (the prior code left a stale non-null `_device` in the same scenario) and is not introduced or worsened by this diff. Flagging only for awareness; the task targets the drop-while-connected path.

## Verification note

Per the plan, the behavioral confirmation is an on-device drop test (power off the headband mid-session and confirm re-scan/re-pair with no `StateError` / SIGABRT). That cannot be exercised in static review and is left to `/verify`.

REVIEW_PASS
