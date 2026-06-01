# Plan: Tear down the neiry `Device` on an unexpected disconnect so auto-reconnect works

## Context
On a native (unexpected) BLE drop, `NeiryBciProvider` must dispose the live `Device` and its four classifiers and null `_device` *before* emitting `disconnected`, so `BciDeviceManager`'s auto-reconnect calls `connect()` on a clean slate instead of hitting the `StateError` guard (and avoids the SIGABRT from recreating non-idempotent classifiers on a reused `Device`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Teardown on unexpected drop

- [x] **Task 1: Add async teardown helper for an unexpected drop**
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add a private method (e.g. `void _teardownAfterUnexpectedDrop()`) that performs the heavy teardown of the captured device + classifiers fire-and-forget, mirroring the disposal shape of the existing `_cancelDeviceSubscriptions()`:
  - Capture the current `_device`, `_nfbClassifier`, `_cardioClassifier`, `_emotionsClassifier`, `_memsClassifier`, and the 11 `StreamSubscription` fields (`_connectionSub`, `_resistanceSub`, `_batterySub`, `_nfbSub`, `_nfbErrorSub`, `_cardioSub`, `_rrSub`, `_emotionsSub`, `_emotionsErrorSub`, `_memsSub` — note `_calibrationSub` is *not* part of the device-stream set, matching `_cancelDeviceSubscriptions()`) into locals, then immediately null the fields (see Task 2 for ordering).
  - Schedule the actual disposal on a microtask / `unawaited` future (NOT synchronously inside the connection-state callback) to avoid re-entrancy while `_connectionSub`'s own callback is on the stack. Cancel each captured subscription, `dispose()` each captured classifier (each wrapped in try/catch + `logPrint` like the existing code), then `disconnect()` + `dispose()` the captured device in a try/catch.
  - Do not touch the `StreamController`s — they stay open so reconnect can resume emitting.

- [x] **Task 2: Rewire `_onNeiryConnectionState` disconnected/unsupported cases** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `_onNeiryConnectionState`, change the `disconnected` and `unsupportedConnection` cases so that when `_device != null` (an unexpected drop, not our own `disconnect()` which already nulled `_device`):
  1. Capture device + classifiers + subscriptions into locals and **synchronously null `_device`, the four classifier fields, and the subscription fields BEFORE** `_connectionStateController.add(BciConnectionState.disconnected)`. The null-before-emit ordering is load-bearing — if the manager's reconnect sees a non-null `_device`, `connect()` throws `StateError`.
  2. Emit `BciConnectionState.disconnected` (keep the existing `logPrint` for the unsupported case).
  3. Kick off the async disposal of the captured locals via the Task 1 helper.
  Add an idempotency guard at the top of the teardown path: `if (_device == null) return;` — a **true no-op**, NOT `{ emit; return; }`. The real-drop path already emitted `disconnected` synchronously; the guard only fires for a second native event in the window before the async teardown cancels `_connectionSub`, or after our own `disconnect()` already nulled `_device` — a second `disconnected` there is redundant noise.
  Leave the `connected` case unchanged. Keep `disconnect()`, `_cancelDeviceSubscriptions()`, and `_doDispose()` untouched.

## Verify
On-device drop test (`/verify`): connect the headband, then power it off mid-session → confirm `BciDeviceManager` re-scans and re-pairs with no `StateError` and no SIGABRT.
