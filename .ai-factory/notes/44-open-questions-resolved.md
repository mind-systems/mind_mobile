# Roadmap Review — Open Questions Resolved (investigation results)

**Date:** 2026-05-31
**Source:** 4 parallel Explore agents over `neiry_kit`, `mind_api`, `mind_mobile` — resolving the open questions in note 43.
**Outcome:** Q1 and Q2 are now decided (concrete fixes below). Q4/Q5 decided (no `mind_api` change needed). Q3 + low items decided.

> **[CORRECTION 2026-05-31]** The original claim "No cross-project changes are required" was **wrong for Q2**. The calibration peak round-trip DOES need a `mind_api` proto/server change, because `NfbCalibrationRepository.refreshFromServer` replaces the local cache with server data and would overwrite the locally-captured peak. Superseded by **notes 53 + 60** (mind_api accepted it — their Phase 29). neiry_kit still needs no change.

---

## Q1 — BCI auto-reconnect: RESOLVED → concrete fix

**Verdict:** The SDK does NOT auto-reconnect, and the `Device` must be torn down and recreated after an unexpected drop. The current adapter's failure (leak + `StateError`) is a real bug.

**Evidence (neiry_kit):**
- `lib/src/api/device.dart:170` — `connect()` throws `StateError` if already connected; on an unexpected drop the SDK sets `_connected = false` (`device.dart:140-141`), so the object isn't "connected" anymore.
- `docs/guides/error-handling.md:80-93` — "SDK does not automatically reconnect"; the documented reconnect pattern is **manual**.
- `docs/guides/session-guide.md:131` — **classifiers are non-idempotent: creating a classifier twice on the same Device causes a fatal SIGABRT.** This is the decisive constraint — the live `NfbClassifier`/`CardioClassifier`/`EmotionsClassifier`/`MEMSClassifier` from the old connection MUST be disposed before any reconnect.
- Reference impl `example/lib/services/neiry_service.dart:242-299` — on disconnect it cancels subs, disposes all classifiers, disposes the Device, and **nulls `_device`**; reconnect calls `createDevice(serial)` fresh.

**Decision / fix (mind_mobile, `lib/Bci/NeiryBciProvider.dart`):** On the SDK `disconnected`/`unsupportedConnection` event in `_onNeiryConnectionState`, when `_device != null` (an unexpected drop, not our own `disconnect()`), run a teardown that mirrors `_cancelDeviceSubscriptions()` + device dispose, then emit `disconnected`. After this, `BciDeviceManager._attemptReconnect → connectDevice → provider.connect()` sees `_device == null` and naturally `createDevice()`s a fresh one — reconnect works.

Implementation cautions:
1. **Order:** null `_device` (and the classifier fields) *before* `_connectionStateController.add(disconnected)`, so the manager's reconnect listener can't race a still-non-null `_device`. Capture old device + classifiers into locals and dispose them fire-and-forget after nulling.
2. **Re-entrancy:** this runs inside `_connectionSub`'s own callback — do the heavy disposal in a `scheduleMicrotask`/unawaited path, not synchronously inside the handler.
3. **Idempotency vs explicit `disconnect()`:** guard with `if (_device == null) { emit; return; }` so a native event after our own teardown is a no-op.
4. Optional: the SDK docs suggest a ~2s settle delay before reconnect; `BciDeviceManager._attemptReconnect`'s scan already adds latency, so not strictly required.

**Status:** Confident fix — ready for a roadmap task. Recommend an on-device drop test (`/verify`) to confirm the manager's scan-then-reconnect actually re-pairs.

---

## Q2 — Calibration round-trip: RESOLVED → lossy; needs BOTH a mobile fix AND a mind_api change

> **[SUPERSEDED 2026-05-31]** This section originally concluded the fix was mobile-only. That was incomplete — `refreshFromServer` overwrites the local peak with server data, so the server must carry the field too. Authoritative specs: **note 53** (mobile) + **note 60** (mind_api's accepted contract, their Phase 29).

**Verdict:** DEFINITIVELY lossy. `individualFrequency` and `individualPeakFrequency` are two distinct fields.

**Evidence (neiry_kit):**
- C struct `clCIndividualNFBData` — `CapsuleClient.framework/Headers/CNFBCalibrator.h:37` (`individualFrequency`) and `:41` (`individualPeakFrequency`) are **separate struct members** with independent defaults.
- Dart model `lib/src/models/individual_nfb_data.dart:32-36` — both fields exist; peak is documented as a "Legacy alias" but `fromMap` (`:71-73`) reads each independently from native.
- Both platform bridges read/write them separately: iOS `ios/Classes/NfbCalibratorBridge.swift:89-90`, Android `android/src/main/cpp/jni_nfb_calibrator.cpp:115-116`.
- Loss point (mind_mobile): `lib/Bci/NeiryBciProvider.dart:399` sets neiry's `individualPeakFrequency` from the stored `data.individualFrequency` (the peak was never captured).

**Decision / fix (mind_mobile, `lib/Bci/Models/NfbCalibrationData.dart` + `NeiryBciProvider.dart`):**
1. Add `final double individualPeakFrequency;` to `NfbCalibrationData` (constructor + `toJson` key `'individualPeakFrequency'` + `fromJson`).
2. **Backward-compat in `fromJson`:** old persisted/synced records lack the key — default to `json['individualPeakFrequency'] ?? json['individualFrequency']` so existing local cache + server history don't break.
3. Capture: in `startCalibration`'s `CalibrationCompleted` mapping (~`NeiryBciProvider.dart:372`) read `data.individualPeakFrequency`.
4. Restore: in `importCalibration` (~`:399`) pass `data.individualPeakFrequency` instead of duplicating `individualFrequency`.

**Status:** Confident fix — ready for a roadmap task.

---

## Q4 / Q5 — Biometric stream lifetime + reconnect: RESOLVED (no server change)

**Q5 verdict (one-per-session vs app-lifetime):** Server **tolerates and expects** one app-lifetime stream multiplexing sessions. Keep current behavior.
- Evidence: `mind_api/proto/module_biometric_stream.proto:39-43` — `BioStreamAck` counters are "cumulative since this bidi connection was opened" (per-session teardown would make them meaningless). Server validates per-sample `session_id` keyed on `userId`, not on stream identity: `mind_api/src/realtime/module-biometric-stream.grpc.controller.ts:109-122`; buffers keyed by `sessionId` in `biometric-stream-engine.service.ts:85-104`.
- **Decision:** do NOT tear down the sink per session. **No `mind_api` change required.** (Optional, non-blocking: a one-line proto doc comment stating the app-lifetime-multiplexed expectation would aid future clarity — not needed for correctness.)

**Q4 verdict (reconnect coordination):** Recommended to wire `BiometricStreamClient` into `GrpcConnectionManager`, like `ModuleStateChannel`/`ModuleInstructionStream`, rather than reopening per-`sendBatch` uncoordinated.
- The other streams: listen to `connectionState`, open on `connected`, `confirmConnected()` on first message (resets shared backoff), `disconnect()+scheduleReconnect()` on error/done (`ModuleStateChannel.dart:53-105`, `ModuleInstructionStream.dart:50-138`).
- Proper fix (change points in `lib/Biometrics/BiometricStreamClient.dart`): add `GrpcConnectionManager` dependency; subscribe to `connectionState` (open-when-connected / teardown-on-disconnect); gate `_ensureSinkOpen` on `connected`; `confirmConnected()` after the first server message; `scheduleReconnect()` on error/done; cancel the sub in `dispose()`.
- **Decision:** This is the correct long-term design. **Note 42 Task 3 (a 2s reopen cooldown) is an acceptable interim** if we don't want the larger wiring now — it removes the 250ms thrash without the dependency. Pick one: ship Task 3 now (cheap) and schedule the full coordination later, or do the full coordination directly and drop Task 3.

---

## Q3 + low items — decided

3. **Q3 active timeline color → GOLD (`cs.tertiary`).** The active row is breath-progress feedback, part of the Phase 20 redesigned session (orb/shape/icons all gold); the cyan stays only on the central `ControlButton` (the interaction affordance). `BreathTimelineWidget.dart:214`: replace the `0xFF00D9FF` literal with `Theme.of(context).colorScheme.tertiary` (thread it in — `_TimelineItem` has a `BuildContext`).
4. **E1 mapper duplication → shared mapper in `lib/BciModule/`** (NOT the package — correcting the agent: the package cannot import the domain `BciSignalLevel`, so a package-side `BciChannelQualityMapper`/`.fromDomain` factory would violate the boundary). Put a small top-level `BciSignalQuality mapBciSignalLevel(BciSignalLevel)` + channel→DTO helper in a new `lib/BciModule/BciChannelQualityMapping.dart`; both services import it. Delivery layer (`lib/BciModule`) is exactly where domain→DTO conversion belongs.
5. **E2 VM lifecycle → align `BciPairingViewModel` to subscribe in `build()`** and move `startScan()` there too (canonical pattern: `BciDataViewModel`, `BreathSessionListViewModel` subscribe in `build()` + `ref.onDispose`). Removes the easy-to-forget external `initState()` call.
6. **E3 running-max normalization → KEEP as-is.** Accepted in Phase 23. If decay ever needed: cheapest robust option is a sliding-window ~99th percentile over the last ~100 samples per metric. No change now.
7. **A1 AudioCatalog/AudioTrack → KEEP as a seam.** `AudioCatalog` is DI'd into `BreathSoundCoordinator` (test-double friendly) and `AudioTrack` is part of the public surface; inlining removes the extension point for future network/buffer sources. No change.
8. **B1 dead cyan defaults → remove the defaults, require explicit `shapeColor`.** `BreathShapeWidget.dart:46` drop `?? const Color(0xFF00D9FF)` and make `shapeColor` required; `BreathShapePainter.dart:19` drop the default (painter has no context; the widget supplies it). Removes the misleading unreachable fallback.
9. **F1 idle batching churn → LEAVE as-is.** Negligible (no encode, bounded). Short-circuit only if profiling ever flags it.

---

## Cross-project requirements

**[CORRECTED 2026-05-31]** `mind_api`: **one change IS required for Q2** — add `individual_peak_frequency` to `nfb_calibration.proto` + entity + migration + mapping (filed as `mind_api/.ai-factory/notes/22`, accepted as their Phase 29; contract in note 60). The earlier "no change" claim missed that `refreshFromServer` replaces the local cache. `mind_api` remains unchanged for Q5. `neiry_kit`: no change (Q1/Q2 mobile-adapter fixes only).

## Net effect on the backlog
- **Promote to confident fixes** (were "verify first"): **Q1** (BCI reconnect teardown) and **Q2** (calibration peak field) — both now have concrete, evidence-backed specs.
- **New decided cleanups:** Q3 (gold), E1 (mapper in lib/BciModule), E2 (build() subscription), B1 (drop cyan defaults).
- **No change:** E3, A1, F1, Q5.
- **Open choice (one decision):** Q4 — interim cooldown (note 42 Task 3) vs full `GrpcConnectionManager` coordination.
