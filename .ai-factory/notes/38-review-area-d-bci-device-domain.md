# Code Review — Area D: BCI Device Domain (Phases 17, 19, 24)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `lib/Bci/{BciDeviceManager,NeiryBciProvider,NfbCalibrationRepository,BciDeviceRepository,BciNotifier}.dart` + models

## Verdict

Largest area, mostly solid: capability-mixin split is clean, all provider stream controllers are broadcast (so manager-subscribe + UI getter coexist safely), `connect()`'s failure path disposes partially-built classifiers, and the calibration repo's server-is-source-of-truth logic is correct. **But the auto-reconnect path appears non-functional**, and the calibration round-trip looks lossy. These two warrant a hands-on check before trusting the BCI reconnect story.

## Key Findings

- **[Medium-High] Auto-reconnect after an UNEXPECTED disconnect cannot succeed — and leaks the device.** On a native drop, `NeiryBciProvider._onNeiryConnectionState(disconnected)` only does `_connectionStateController.add(disconnected)`; it does **not** cancel device subscriptions or null `_device`. Only the explicit `disconnect()` / `_doDispose()` paths null `_device`. Meanwhile `connect()` hard-throws `StateError` when `_device != null`. So the chain `BciDeviceManager` connectionState-listener → `_attemptReconnect()` → `connectDevice(serial)` → `_provider.connect(serial)` always throws `StateError`, is caught, and falls back to `disconnected`. The entire `_suppressAutoReconnect` / `_attemptReconnect` machinery — which exists precisely for this scenario — is dead on arrival, and the stale `_device` + its classifier subscriptions are never torn down (leak). **Fix options:** (a) on the native `disconnected` event, run `_cancelDeviceSubscriptions()` + null `_device` inside the provider; or (b) make `connect()` replace a stale device (disconnect-then-connect); or (c) have the manager call `_provider.disconnect()` before `_attemptReconnect`. Needs a real on-device drop test.
- **[Medium] Lossy calibration round-trip on peak frequency.** Capture (`NeiryBciProvider.startCalibration`, `CalibrationCompleted`) maps only `data.individualFrequency` into `NfbCalibrationData` — neiry's separate `individualPeakFrequency` is dropped. Restore (`importCalibration`) then sets BOTH `individualFrequency` AND `individualPeakFrequency` from the single stored `data.individualFrequency`. If the SDK's two fields can differ, the restored calibration's peak frequency is corrupted on every reconnect-restore. Verify against `neiry_kit` semantics / note 30; if they can differ, `NfbCalibrationData` must carry both.

## Details

### Lower-severity findings
- **[Low] Corrupt-history is silently swallowed.** `NfbCalibrationRepository.history()` catches all decode errors and returns `const []` with no log — a corrupt prefs blob silently erases local calibration history. Add a `logPrint` in the catch.
- **[Low / doc] `IBciDeviceProvider.scan()` contract vs reality.** Interface doc says "one emission per scan call," but the impl `yield*`s `requestDevices(searchTime: 5)`, a stream that emits multiple device-list updates over the 5s window. The manager correctly handles repeated emissions; the doc is just inaccurate.
- **[Low / clarity] `_onNeiryConnectionState` maps neiry `connected → BciConnectionState.connecting`.** Intentional (impedance/calibration precede `ready`), and harmless because the manager only reacts to the `disconnected` transition from the provider's connectionState stream — but the naming reads as a bug at first glance. Worth a one-line comment.

### What's solid (verified)
- All nine provider `StreamController`s are `.broadcast()` — `BciDeviceManager` subscribes to `calibrationStream` internally while also re-exposing `signalQualityStream`/`batteryStream`/`calibrationStream` to the UI via getters; no single-subscription conflict.
- `connect()` failure path: the `catch` disposes each of the four classifiers (NfbClassifier/CardioClassifier/EmotionsClassifier/MEMSClassifier) guarded individually, then disconnects+disposes the device and nulls it before `rethrow`. Clean partial-construction recovery.
- `_cancelDeviceSubscriptions()` cancels all 11 subscriptions and disposes all four classifiers (MEMS explicitly, as required — the others would also be released by device dispose). Symmetric with `_subscribeDeviceStreams`.
- `BciDeviceManager.startScan()` forces a `scanning` emit bypassing the `_setState` dedup (Phase 18 bug fix present), resets `_suppressAutoReconnect`, fires `fetchKnownSerials()` + per-serial `refreshFromServer()` (Phase 23/24 wiring), and uses the synchronous pre-fetch `cachedSerials()` for auto-connect — matches the documented "cache must already have data" rule.
- `connectDevice()` guards the post-`importCalibration` state write with `if (_state == connecting)` to avoid clobbering a disconnect that raced the awaited import.
- Calibration record race (late event after reconnect-to-different-device) is explicitly documented and accepted.
- `NfbCalibrationRepository`: `record` prepends/truncates-to-20/persists then fire-and-forget server sync; `refreshFromServer` replaces local with server list (server authoritative); `latestValid` scans history for first `isValid`.

## Open Questions

- Does `neiry_kit`'s `Device` survive a native drop and reconnect on the *same* object (making the manager's create-new-device reconnect the wrong model), or must it be recreated (making the StateError the bug)? This determines whether the fix is in the provider's disconnect-cleanup or in the manager's reconnect strategy.
- Can `IndividualNfbData.individualFrequency` and `.individualPeakFrequency` differ in practice? If yes, the round-trip fix is mandatory.
