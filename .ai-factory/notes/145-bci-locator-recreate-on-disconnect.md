# Recreate the SDK DeviceLocator session on every disconnect

**Date:** 2026-06-22
**Source:** conversation context + `.ai-factory/handoffs/06-bci-device-session-reset-on-reconnect.md`

## Key Findings

- The vendored Capsule SDK caches `clCDevice` **per serial inside the `clCDeviceLocator`**. `clCDevice_Release` does **not** evict it. Reconnecting through the same locator returns the **identical `clCDevice`** with all its session-scoped native state intact — a reconnect is *not* a fresh state machine. Proven on-device (SM A705FN): the native device pointer is **identical** across disconnect→reconnect (`dev=0x776e1a4160` before and after).
- **Scope correction (handoff 07):** this locator recreate is for a **clean reconnect session**, NOT the fix for the recalibration crash. The `PlatformException(255, "Calibration has already been started")` was the catchable symptom of a kit-internal dangling `g_calibrator` that escalates to a recursive SIGABRT — that root cause is fixed inside `neiry_kit` (`invalidate_calibrator()`, commit `836699b`), pulled via note 148. Task 145 alone would NOT have prevented that crash.
- Why still needed: even with the kit fix, reconnecting through the same locator hands back a stale per-serial device. Recreating the locator is the only way to get a genuinely fresh `clCDevice`/session on reconnect. (The separate hardware-power-off teardown is already handled and verified — the SDK emits `disconnected` ~7 s late — so no extra trigger work is needed.)

## Details

### Current state (`lib/Bci/NeiryBciProvider.dart`)
- `final _locator = neiry.DeviceLocator();` (~line 35) — a process-wide singleton created **once** and never disposed/recreated.
- `_device = await _locator.createDevice(serial);` (~154) — every connect (initial and reconnect) goes through this same locator → same cached device for the same serial.
- All teardown paths dispose classifiers + `_device.disconnect()` + `_device.dispose()` but **never touch `_locator`**:
  - `connect()` failure cleanup (~162–185)
  - `_teardownAfterUnexpectedDrop()` microtask (~432–515; device disconnect/dispose ~508–513)
  - `disconnect()` (~565–596)
  - `_doDispose()` (~606–626)
- Both reconnect routes hit the bug: explicit `BciDeviceManager.disconnect()` → user reconnect, and `_attemptReconnect()` after an unexpected drop — both reuse the same locator/serial.

### Exact change
- Make `_locator` **mutable** (`neiry.DeviceLocator _locator = neiry.DeviceLocator();` — drop `final`).
- In every disconnect/teardown path, **after** `_device?.dispose()` and `_device = null`, recreate the session:
  ```dart
  try { await _locator.dispose(); } catch (_) {}   // StateError on double-dispose
  _locator = neiry.DeviceLocator();                // fresh native session
  ```
  Apply to `disconnect()` and `_teardownAfterUnexpectedDrop()` (both reconnect routes). The `connect()` failure-cleanup path should also reset so a failed connect leaves a clean locator.
- `_doDispose()` is **terminal** — dispose the locator there but do **not** recreate it (provider is being destroyed). Guard against disposing the locator twice across overlapping paths.
- `DeviceLocator.dispose()` already does the full native teardown (cancel scan → `clCDeviceLocator_Destroy` → reset the Dart singleton so the next `DeviceLocator()` is fresh); it calls `_checkNotDisposed()` first, so a double dispose throws `StateError` — wrap in try/catch.

### Guards
- `BciDeviceManager._attemptReconnect()` calls `_provider.scan()` → `_locator.requestDevices()`. After recreate, `scan()` must read the **new** `_locator` — never cache a locator reference; always read the field at call time.
- Do not recreate the locator in `_doDispose()` (terminal path).
- Do not introduce a second `DeviceLocator()` anywhere else — it is a process-wide singleton.

### Verify
- Pointer-identity test (handoff 06 §3): with temporary native/Dart logging of the device pointer at create+release, the reconnect pointer must now **differ** from the pre-disconnect pointer (this is task 145's own success signal).
- Functional (requires the kit bump, note 148): calibrate → disconnect → reconnect → calibrate again **succeeds** with no SIGABRT and no code-255; applies to both clean-disconnect and unexpected-drop reconnect. The no-crash outcome is delivered by `836699b`; task 145 ensures the reconnected session is fresh.

## Open Questions
- Exact ordering inside `_teardownAfterUnexpectedDrop()`'s microtask: confirm `_locator.dispose()` runs after the device `disconnect()/dispose()` and after fan-in subscriptions are cancelled, to respect existing SDK teardown invariants (`neiry_kit/docs/guides/teardown.md`).
