# Code Review: Always require calibration on every BCI connect

**Plan:** `19-always-require-calibration-on-every-bci-connect-remove-importcalibration-from-connectdevice.md`
**Files changed:** `lib/Bci/BciDeviceManager.dart`, `docs/bci/device-manager.md`, `docs/bci/nfb-calibration.md` (+ plan/review artifacts)
**Risk level:** 🟢 Low

## Scope

Single logical change: remove the cached-calibration auto-restore block from `BciDeviceManager.connectDevice()` so every connection transitions `connecting → impedance` and requires a fresh user-initiated calibration. Two doc edits track the behavior change.

## Correctness review

### `lib/Bci/BciDeviceManager.dart`
- The removed block (`var restored`, `latestValid(serial)` lookup, `importCalibration` try/catch) is fully excised with no orphaned references. `restored` was the only consumer of the lookup, and it is gone — no dead variable, no unused local.
- The post-connect transition is now unconditional `impedance` inside the existing `if (_state == BciConnectionState.connecting)` guard. The guard is still correct and still necessary: it protects against `disconnect()` racing with the awaited `_provider.connect()`. The updated comment accurately describes the remaining awaited call (`connect`), not the removed `importCalibration`.
- Preserved paths verified intact: `await _provider.connect(serial)`, `_connectedSerial = serial`, the fire-and-forget `_repository.registerDevice(serial)`, and the outer `catch → disconnected`.
- The `BciCalibrationCompleted` handler in `_subscribeProviderStreams` is untouched: `_nfbCalibrationRepository.record()` history recording and the `calibrating → ready` transition remain the sole path to `ready`. This is exactly the intended behavior — `ready` can no longer be reached without passing through `calibrating`.
- `_nfbCalibrationRepository` is still referenced by `record()` (calibration handler) and `refreshFromServer()` (in `startScan`), so the field and its import remain live — no analyzer "unused field/import" warning is introduced.
- `IBciDeviceProvider.importCalibration()` now has no app-code caller, but it is intentionally retained per the spec for a possible future opt-in restore flow. As an interface method it will not trigger an unused-element lint, so there is no build impact.

### Runtime / behavioral checks
- No migrations, schema, DTO, or wiring changes — purely an in-memory state-machine path removal.
- No new types, nullability, or async ordering concerns. The `if (_state == ...connecting)` guard behaves identically to before for the disconnect-mid-flight race.
- Auto-reconnect (`_attemptReconnect → connectDevice`) now also lands on `impedance` after a transient BLE drop, requiring fresh manual calibration. This is the literal, intended meaning of "every connect" and is consistent with the spec rationale (session-specific baselines).

### Docs
- `docs/bci/device-manager.md`: the "reused on subsequent connections" sentence is replaced with wording stating results are saved locally for history/analytics while calibration is performed manually on each connect. Accurate and consistent with the code.
- `docs/bci/nfb-calibration.md`: the `latestValid(serial)` bullet now clarifies it is available for analytics/future flows and is not called on connect. Intro (manual calibration each connect) was already accurate and remains so.

## Non-blocking observations (no action required)

1. Pre-existing stale reference in `docs/bci/nfb-calibration.md` line 37 names the handler `_subscribeCalibration`, but the actual method is `_subscribeProviderStreams`. This is unrelated to the milestone and out of scope; not introduced by this change.

## Conclusion

The change matches the plan exactly, removes only the intended code, leaves the recording/sync and state-machine `ready` paths intact, and introduces no dead code, type, or race issues. Docs are updated consistently with the new behavior.

REVIEW_PASS
