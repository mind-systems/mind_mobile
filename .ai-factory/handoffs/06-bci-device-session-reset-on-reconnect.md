# Handoff — BCI device session reset on reconnect

## 1. Frame
A reconnect bug was caught in mind_mobile and root-caused over a half-day debug session in the `neiry_kit` plugin. The short version: **a "disconnect" that only releases the `Device` is a half-teardown — the native SDK keeps the whole device session alive and hands it back, unchanged, on the next connect.** That stale session causes wrong behaviour after reconnect (e.g. a repeated calibration attempt fails with `Calibration has already been started`, and stale per-session events/UI state bleed into the new connection). This note carries the finding, the evidence, the diagnostic method, and the concrete mobile-side fixes. Chat is compacted — knowledge is durable in the files referenced here; rehydrate from them.

**Does changing neiry_kit auto-fix mind_mobile? No.** The fix lives in the consumer's device-lifecycle layer (`NeiryBciProvider` / `BciDeviceManager`), which owns the `DeviceLocator`. The kit cannot destroy a consumer-held singleton locator on a device disconnect, and cannot change the vendored native SDK's per-serial device caching. mind_mobile must apply the fixes itself — and it is confirmed affected (see §3).

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `lib/Bci/NeiryBciProvider.dart` — owns the SDK `DeviceLocator` + device + classifiers. The locator fix goes here. Key spots: `final _locator = neiry.DeviceLocator();` (~line 35), `_locator.createDevice(serial)` (~154), and every disconnect/teardown path — disposes classifiers + `_device.disconnect()` + `_device.dispose()` but **never touches `_locator`** (~164–181, ~496–519, ~549–597, ~624–625).
- `lib/Bci/BciDeviceManager.dart` — canonical domain state machine + reconnect. `disconnect()` (~255) sets `BciIdle` (good) but goes through `_provider.disconnect()` which reuses the session. `_attemptReconnect()` (~263) → `connectDevice(serial)` → same cached device. Calibration-event handler (~76–105) already carries a comment admitting a stale-event "thin race" after disconnect→reconnect (~84–86).
- `lib/Bci/BciNotifier.dart` — `BehaviorSubject _subject` (~19) re-emits the **last** event to any new subscriber; subscriptions to all manager streams (~32–95). Nothing clears the retained value on disconnect → stale session data replays after reconnect.

### Read on demand
- `neiry_kit/lib/src/api/device_locator.dart` — `DeviceLocator.dispose()` already does the full native teardown (cancel scan → native `clCDeviceLocator_Destroy` → reset the Dart singleton so the next `DeviceLocator()` is a fresh native session). Process-wide singleton; `dispose()` calls `_checkNotDisposed()` first, so a double dispose throws `StateError`.
- `neiry_kit/example/lib/services/neiry_service.dart` — reference: its `disconnect()` is being changed to dispose + recreate the locator. Same pattern mobile needs.
- `neiry_kit/docs/guides/teardown.md` — existing SDK teardown invariants / ordering rules (prior crash-hardening work).

## 3. Current state

**Done (root cause proven):**
- The vendored Capsule SDK caches `clCDevice` **per serial inside the `clCDeviceLocator`**. `clCDevice_Release` does **not** evict it. Reconnecting through the same locator returns the **identical `clCDevice`** and all of its session-scoped native state — reconnect is *not* a fresh state machine.
- Several session-scoped SDK objects expose **no per-object reset/stop** API. So once the session holds stale state, the only lever to clear it is destroying the locator.
- **Evidence (on-device logs, SM A705FN):**
  ```
  connect:     nativeCreateDevice  locator=0x776e1a4000 serial=820566 -> dev=0x776e1a4160
  disconnect:  nativeReleaseDevice dev=0x776e1a4160
  reconnect:   nativeCreateDevice  locator=0x776e1a4000 serial=820566 -> dev=0x776e1a4160   ← SAME pointer
  re-op:       sameInstanceAsPrev=1, state still "calibrated" → operation rejected ("already been started", code 255)
  ```
- **mind_mobile is affected (verified by reading the code):** `NeiryBciProvider._locator` is a `final` singleton created once; no disconnect path disposes/recreates it. Both explicit `disconnect()` and `_attemptReconnect()` go back through the same locator → same cached device → stale session.

**How it was found / how to verify your fix:**
- Add temporary native (or Dart-side) logging of the device pointer/handle at create + release. The tell is a **stale identity across disconnect→reconnect**: same `clCDevice` pointer = session reused. After the fix, the reconnect pointer must be **different** and any "is this session already initialised/calibrated" query must read false on the fresh device.

**In-flight (neiry_kit side):** planned fix to the example `NeiryService.disconnect()` (dispose + recreate locator). No kit *library* change is needed — `DeviceLocator.dispose()` already exposes the capability.

**Uncommitted working-tree state:** mind_mobile — none (handoff only, no edits made here).

## 4. Next step
Three fixes in the mind_mobile BCI layer, in priority order:

1. **Recreate the locator session on disconnect** (`NeiryBciProvider`): make `_locator` mutable; at the end of every disconnect/teardown path (after `_device?.dispose()`), `await _locator.dispose();` then `_locator = neiry.DeviceLocator();`. Guard the provider's own dispose path against double-dispose. This is the core fix — without it the next two are cosmetic.
2. **Reset session-derived UI/domain state on disconnect** (`BciNotifier` / `BciDeviceManager`): `BciDeviceManager.disconnect()` already resets `_state → BciIdle`, but `BciNotifier._subject` is a `BehaviorSubject` that still replays the **last** `BciNfbUpdated` / `BciCardioUpdated` / `BciCalibrationEventReceived` / `BciSignalQualityUpdated` to any widget that subscribes after reconnect. On disconnect, clear/neutralise the retained value (emit a reset/idle event, or recreate the subject) so the new session does not show the previous session's data.
3. **Cancel/rebind SDK stream subscriptions across the session boundary** (`BciDeviceManager._calibrationSub` etc.): the existing "late-arriving event after disconnect→reconnect" comment (~84–86) is exactly this bug — a still-live subscription on a reused session replays a stale terminal event into the new state machine. Once (1) gives a fresh session per connect, cancel the per-session subscriptions on disconnect and rebind them on connect so no stale event survives the boundary.

Verify with the pointer-identity test from §3.

## 5. Working discipline
- Do not auto-commit; confirm / show diff before committing. Stop and ask on ambiguity.
- All generated/edited files in English.

## 6. Error log (what we chased down the wrong path first — don't repeat)
- **Assumed `stopCalibration` (or any "stop") resets the SDK session.** It does not — the native stop only detaches callbacks; the SDK has no reset/abort for the session-scoped objects. Don't build a fix around a non-existent reset call.
- **Assumed disconnect→reconnect already gives a fresh session.** It does not — proven by the identical `clCDevice` pointer across the cycle. Releasing the device ≠ resetting the session.
- **Saw a "phantom completion": a stale terminal event with the *previous* run's data arriving right after a failed re-op.** Root cause was an event-stream subscription not cancelled on the terminal event (only on dispose), so it replayed a buffered event on the next run. Lesson: cancel SDK event subscriptions on terminal/disconnect, not just in `dispose()`. (This is the general form of mind_mobile's `_calibrationSub` "thin race".)

## 7. Orientation (traps)
- **"Release the device ≠ reset the session."** Disposing `Device` + classifiers does not reset the SDK session; the locator caches the device and its state. Only destroying the locator yields a fresh native state machine. This single trap is the whole bug.
- **`BehaviorSubject` replays stale state.** `BciNotifier._subject` re-emits its last value to new listeners. After reconnect, a freshly-built screen sees the *previous* session's last event unless the retained value is cleared on disconnect.
- **"Classifiers are recreated each connect" ≠ "the session is reset."** Rebuilding consumers on top of a reused session does not clear the session's stale state.
- **Both reconnect paths hit it** — explicit `disconnect()`→user reconnect AND `_attemptReconnect()` after an unexpected drop go through the same locator/serial → same cached device.

## 8. Domain model spine
- **The `clCDeviceLocator` is the SDK session boundary.** Device lifetime ⊂ locator lifetime. A clean reconnect requires a fresh locator, not just a released device. The SDK returns the same cached device for the same serial within one locator. Don't re-litigate "just recreate the device" — it returns the same object. Pointer: `neiry_kit/lib/src/api/device_locator.dart`; evidence in §3.
- **Two layers of stale state, both must be reset on disconnect:** (a) native session — fixed by locator teardown; (b) Dart-side cached/replayed state (`BehaviorSubject` retained value, per-session subscriptions) — fixed in `BciNotifier`/`BciDeviceManager`.

## 9. Hard rules
- No auto-commit; confirm-before-execute; English files.

## 10. Cross-cutting invariants checklist
- On **disconnect**: dispose classifiers → `device.disconnect()`/`dispose()` → **`locator.dispose()` + recreate** → reset Dart-side session state (clear `BehaviorSubject` retained value, cancel per-session subscriptions).
- On **connect**: build everything off the **fresh** locator; rebind per-session subscriptions.
- A `DeviceLocator` is a process-wide singleton — `dispose()` resets it; the next `DeviceLocator()` is fresh; never `dispose()` it twice (throws `StateError`).
- Invariant to assert in tests/logs: the device identity (native pointer / handle) **differs** across a disconnect→reconnect cycle.
