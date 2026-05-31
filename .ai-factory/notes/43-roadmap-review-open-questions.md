# Roadmap Review — Open Questions & Deferred Items

**Date:** 2026-05-31
**Source:** code review of roadmap phases 12–25 (notes 35–41)
**Scope:** everything NOT in note 42 — findings that need an on-device check, an SDK fact, a product decision, or are low-value cleanups. Kept in one place as a working checklist.

## 🔴 High impact — verify before fixing

### Q1. BCI auto-reconnect after an unexpected disconnect (note 38)
The whole `_suppressAutoReconnect` / `_attemptReconnect` path appears non-functional: `NeiryBciProvider._onNeiryConnectionState(disconnected)` only pushes an event — it never cancels device subscriptions or nulls `_device` — while `connect()` hard-throws `StateError` when `_device != null`. So `_attemptReconnect → connectDevice → provider.connect()` always throws and falls back to `disconnected`, and the stale `_device` + classifier subs leak.
- **Decision needed:** does `neiry_kit`'s `Device` survive a native drop and reconnect on the *same* object (→ the manager's "scan + create new device" reconnect is the wrong model), or must it be recreated (→ the fix is to tear down `_device` + subs on the native `disconnected` event so `connect()` can succeed)?
- **Why deferred:** the fix location depends on this SDK fact; cleaning up `_device` blindly inside `_onNeiryConnectionState` while the SDK may still hold it is risky. Needs a real on-device drop test (`/verify`).
- **Likely fix once confirmed:** in the provider's native-`disconnected` handler run `_cancelDeviceSubscriptions()` + null `_device` (stops the leak and unblocks `connect()`), OR make `connect()` disconnect-then-connect a stale device.

### Q2. Lossy NFB calibration round-trip (note 38)
Capture (`NeiryBciProvider.startCalibration`) stores only `data.individualFrequency` into `NfbCalibrationData`; neiry's separate `individualPeakFrequency` is dropped. Restore (`importCalibration`) sets BOTH neiry fields from the single stored `individualFrequency`.
- **Decision needed:** can `IndividualNfbData.individualFrequency` and `.individualPeakFrequency` differ in practice?
- **If yes:** `NfbCalibrationData` must carry both (add a field + `toJson`/`fromJson` + capture mapping + restore mapping); otherwise every reconnect-restore corrupts the peak frequency.
- **If they're aliases / always equal:** no change; add a code comment recording that.

## 🟠 Medium — product / architecture decision

### Q3. Active timeline row color (note 36)
`BreathTimelineWidget.dart:214` still renders the OLD cyan `const Color(0xFF00D9FF)` for the active step, while the Phase 20 redesign turned the orb/shape/icons warm gold. The active countdown looks cyan against a gold screen.
- **Decision:** gold (`cs.tertiary`, consistent with the redesign) or cyan accent (`cs.primary`, consistent with the central control button which deliberately stayed cyan)? Either way, replace the hardcoded literal with the theme reference.

### Q4. Biometric stream reconnect — bigger architecture (note 40)
Note 42 Task 3 ships a conservative cooldown. The larger question: should `BiometricStreamClient` reconnect ride on `GrpcConnectionManager.connectionState` / its exponential backoff instead of managing its own bidi stream independently? Today it's fully uncoordinated with the rest of the gRPC reconnect machinery.

### Q5. Biometric bidi stream lifetime (note 40)
The sink is **not** closed on `ModuleSessionEnded`/`Abandoned` (only sessionId + replay ring are cleared), so one bidi stream spans multiple sessions, each wire `BioSample` carrying its own `session_id`.
- **Decision:** does the server tolerate one app-lifetime stream multiplexing sessions, or does it expect a fresh stream per session? If the latter, tear down `_sink` on session end.

## 🟡 Low — optional cleanups / debatable

- **C1 (note 37):** `HomeGrpcReconnected` can fire on the very first connect (`disconnected→connecting→connected`), causing one redundant `_loadInitialData()` if Home mounts before the initial connect settles. Suppress until a prior `connected` was seen — or leave it (harmless extra fetch).
- **C2 (note 37):** a single connection drop increments `_reconnectAttempt` ~twice (both `ModuleStateChannel` and `ModuleInstructionStream` call `disconnect()+scheduleReconnect()`). Self-correcting via `confirmConnected`; backoff just grows per-stream-error, not per-drop.
- **E1 (note 39):** `_mapLevel` + channel→DTO mapping is duplicated verbatim in `BciPairingService` and `BciDataService`. Extract a shared `BciChannelQualityDTO.fromDomain` factory.
- **E2 (note 39):** two BCI VMs, two subscription lifecycles — `BciDataViewModel` subscribes in `build()`, `BciPairingViewModel` requires an explicit `initState()` call. Align on one pattern (the deferral exists only because pairing also fires `startScan()`).
- **E3 (note 39):** `BciDataViewModel` running-max normalization never decays — a single outlier permanently compresses every bar for the screen session. A decaying/percentile ceiling would be more robust if bars are seen to "die" after a glitch.
- **A1 (note 35):** `AudioCatalog` + `AudioTrack` are near-vestigial after the FLAC migration (`AssetAudioCatalog.sourceFor` is one line; `AudioTrack` wraps a single `String`). Inline now, or keep as a seam for future network/TTS sources?
- **B1 (note 36):** two dead cyan default fallbacks in `BreathShapeWidget.dart:46` and `BreathShapePainter.dart:19` — always overridden by `cs.tertiary` from the screen. Harmless but stale.
- **D1 (note 38):** `NfbCalibrationRepository.history()` silently swallows decode errors (corrupt prefs → empty history, no log). Add a `logPrint` in the catch. Trivial; fold into Q1's PR if touched.
- **F1 (note 40):** idle batching churn — `BiometricBatcher` keeps buffering + arming 250 ms timers while the BCI is connected with no active session (samples dropped before encode by `sendBatch`). Negligible; short-circuit only if it ever shows up in profiling.

## Notes
- Items C1, C2, E1–E3, A1, B1, D1, F1 are not bugs that affect users today — they're robustness/tidiness. Pick up opportunistically when touching the relevant file.
- Q1 and Q2 are the only items that can cause real BCI data/UX problems and are worth scheduling deliberately.
