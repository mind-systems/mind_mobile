# Roadmap Review — Confident Fix Tasks (atomic)

**Date:** 2026-05-31
**Source:** code review of roadmap phases 12–25 (notes 35–41)
**Scope:** self-contained fixes with no open product/SDK question. Each is one file boundary, one concern, one reason to revert. Ordered by impact.

## Summary

Six atomic fixes I'm confident in. One Medium functional bug (meditation repeat-session data loss), two Moderate hardenings (audio race, biometric reconnect thrash), three Low cleanups (backoff overflow guard, stale battery, debug logs). The two highest-impact findings (BCI auto-reconnect, calibration round-trip) and all decision-dependent items are in note 43, not here.

---

## Task 1 — [Medium] Re-arm the meditation state-channel so repeat sessions are tracked

**Current state:** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` uses one-shot `_started`/`_ended` flags that never reset. The session UI (`MeditationSessionViewModel.start()/stop()`) is a re-pressable toggle on a persistent VM, so a user can run Start→Stop→Start without leaving the screen. On the 2nd `active`, `!_started` is false → `_channel.start()` is skipped; `_ended` is true → idle branch is a no-op; `dispose()`'s `_started && !_ended` is false → no `stop()`. The 2nd+ sessions emit no lifecycle events, and since `BiometricStreamClient._currentSessionId` was cleared on the 1st `end`, no biometrics record either. The breath equivalent re-arms via `reset()`; meditation dropped it.

**Target:** in `_onState`, the `active → idle` branch currently does `_channel.end(); _ended = true;`. Change it to `_channel.end(); _started = false; _ended = false;` — re-arming both flags so the next `idle → active` fires a fresh `start()`. Verify the dispose guard still holds: after re-arm while idle, `_started == false` → dispose correctly skips `stop()`; if the user goes active again then navigates away, `_started == true && !_ended` → `stop()` fires. Keep the `status == _previousStatus` dedup and the `idle→active` start branch untouched.

**Files:** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` only.

---

## Task 2 — [Moderate] Guard `AudioOneShot.play()` against an in-flight `load()`

**Current state:** `packages/mind_audio/lib/src/audio_one_shot.dart`: `load()` awaits `setAudioSource`; `play()` fires `seek(0).then(play)` with no guard. In `BreathSoundCoordinator._onStateChanged` a tick-source change (heart↔timer toggle, Phase 22) fires `_oneShot.load(src)` unawaited while `_onTick` may call `_oneShot.play()` concurrently — `setAudioSource` racing `seek`/`play` on the same player can produce a glitched or no-op tick.

**Target:** add `bool _loading = false;` to `AudioOneShot`. Set it `true` at the start of `load()` and `false` in a `finally` around the `await _player.setAudioSource(source)`. In `play()`, `return` early when `_loading` is true (a single tick dropped during the brief buffer swap is acceptable). No public API change; no caller change.

**Files:** `packages/mind_audio/lib/src/audio_one_shot.dart` only.

---

## Task 3 — [Moderate] Rate-limit `BiometricStreamClient` stream reopen

**Current state:** `lib/Biometrics/BiometricStreamClient.dart`: `sendBatch` (every ≤250 ms during a session) calls `_ensureSinkOpen()` at the top; after `onError`/`onDone` tears the sink down (`_sink = null`), the next batch reopens immediately. During a server/transport outage this re-opens `streamData` every 250 ms with no cooldown — network/battery thrash. Samples that can't send already fall into the bounded replay ring.

**Target:** add a reopen cooldown. Field `DateTime? _lastOpenAttempt;`. In `_ensureSinkOpen()`, before creating a new `StreamController`, if `_lastOpenAttempt != null && DateTime.now().difference(_lastOpenAttempt!) < const Duration(seconds: 2)` → `return` without opening (samples then enqueue to the replay ring via the existing `_sink == null` branch in `_encodeAndAdd`). Set `_lastOpenAttempt = DateTime.now()` at the point an open is attempted. Keep the existing replay-ring drain on a successful open. (`DateTime.now()` is correct here — this is wall-clock retry control, not a physiological sample timestamp.)

**Files:** `lib/Biometrics/BiometricStreamClient.dart` only. (This is the conservative, self-contained version; the larger "ride on `GrpcConnectionManager` backoff" option is a design question in note 43.)

---

## Task 4 — [Low] Cap the gRPC reconnect backoff exponent

**Current state:** `lib/Core/Grpc/GrpcConnectionManager._nextDelay()` computes `base = _initialDelay * math.pow(2, _reconnectAttempt)` and only clamps the result afterward. `_reconnectAttempt` increments on every schedule and resets only on `confirmConnected()`. After ~50+ failed attempts `pow(2, attempt)` overflows the `Duration` microsecond int64 before the clamp.

**Target:** clamp the exponent at the source: `final exp = math.min(_reconnectAttempt, 6); final base = _initialDelay * math.pow(2, exp);`. `2^6 = 64 s` already exceeds `_maxDelay` (30 s), so behavior is unchanged within the normal range. Leave the `_reconnectAttempt++` increment as-is (still useful for the log line).

**Files:** `lib/Core/Grpc/GrpcConnectionManager.dart` only.

---

## Task 5 — [Low] Clear stale battery on disconnect in the pairing reducer

**Current state:** `lib/BciModule/BciPairingService._reduceStateChanged`, the `disconnected` branch clears `stage`/`isScanning`/`isConnecting`/`isBluetoothPermissionDenied`/`calibration`/`channels`/`errorMessage` but not `batteryPercent`, so the pairing header can show a stale percentage after the device drops. `BciDataService` already clears it on disconnect — the two reducers are inconsistent.

**Target:** add `batteryPercent: null` to the `disconnected` branch's `copyWith` (`BciPairingState.copyWith` already uses the `_undefined` sentinel, so passing `null` actually clears it). Optionally mirror into the `bluetoothPermissionDenied` branch for full parity.

**Files:** `lib/BciModule/BciPairingService.dart` only.

---

## Task 6 — [Low] Remove leftover `[Sound]` debug instrumentation

**Current state:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` still carries the `_ts()` timestamp helper and multiple `if (kDebugMode) debugPrint('${_ts()} [Sound] ...')` lines across `initialize`, `_onStateChanged`, and `_onTick`. Phase 16 already stripped the equivalent `[BREATH-PROBE]` logs; these are the same class of throwaway instrumentation.

**Target:** delete the top-level `_ts()` function and every `[Sound]` `debugPrint` line. Keep the `package:flutter/foundation.dart` import (still needed for `ValueNotifier`). No behavior change.

**Files:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` only.

## Open Questions

None — these six are decision-free. Everything requiring a product call, SDK verification, or architectural choice is in note 43.
