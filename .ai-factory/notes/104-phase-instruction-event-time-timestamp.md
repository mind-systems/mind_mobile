# Phase Instruction Timestamp = Event Time, Not Send Time

**Date:** 2026-06-16
**Source:** conversation context

## Key Findings

- Breath phase instruction samples are timestamped at **send** time, not at the moment the phase actually started. For the first phase (`rest`), send happens only after the `activity:start` round-trip returns the correlation key, so `rest` lands ~1.2–1.5 s late (the spread is network jitter).
- Biometric samples carry **true measurement time** from SDK per-sample clocks (`BioSample` uses each domain model's `.timestamp`, never `DateTime.now()`). So on the analytics timeline the heart track starts before the phase track — phases are supposed to be the time reference, yet they arrive shifted.
- Fix is timestamp-source only: capture the transition time when the phase change is detected and carry it through to the sample, including across the pending/flush path. No change to delivery, readiness, eager-open, or `durationMs`.

## Details

### What exists today

`BreathModuleInstructionStream.sendSample` (`lib/BreathModule/Core/BreathModuleInstructionStream.dart:24-41`) builds the payload with:

```dart
'timestamp': DateTime.now().millisecondsSinceEpoch,
```

The timestamp is stamped inside `sendSample`, i.e. at the moment of the call.

The first phase path delays that call:
1. On Play the engine enters `rest`, but the correlation key (`moduleSessionId`) has not returned yet, so `BreathModuleStateChannel._handleInstruction` stores the state in `_pendingInstruction = state` (`BreathModuleStateChannel.dart:98-99`) — it keeps the `BreathSessionState` but **not** the transition time.
2. `activity:start` round-trips to the server (~1.2–1.5 s, jittered by the network).
3. The key arrives, `_flushPending` (`BreathModuleStateChannel.dart:105-110`) calls `sendSample`, which stamps `DateTime.now()` — now, at flush, a full round-trip after the phase actually began.

Subsequent phases call `sendSample` synchronously from `_handleInstruction` at the real transition, so they are already close to correct; the defect is concentrated in the buffered first phase, but the timestamp should be event-sourced uniformly so no future buffering reintroduces the skew.

### The change

Capture the transition timestamp at detection and thread it through:

- `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  - In `_handleInstruction`, at the point `phaseChanged` is confirmed, capture `final ts = DateTime.now().millisecondsSinceEpoch` — this is the true transition time.
  - Pass `ts` into `sendSample` on the direct path.
  - For the pending path, store the timestamp together with the state (e.g. carry `(BreathSessionState state, int ts)` in `_pendingInstruction` instead of just the state) so `_flushPending` reuses the captured `ts` rather than re-reading the clock.
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
  - `sendSample(String sessionId, String phase, int durationMs)` gains an `int timestampMs` parameter.
  - The payload uses the passed `timestampMs`; remove the internal `DateTime.now()` stamp (line 27).

### Guards

- Timestamp source only. Do not touch the readiness/eager-open work, the biometric path, the rate-limit/buffer, or the `durationMs` computation (`currentPhaseTotalDuration * currentIntervalMs`).
- The captured time is the device wall clock at the transition; reconciling device-clock vs SDK-clock heterogeneity across biometric sources is explicitly out of scope.

### Verify

- The first `rest` row in `session_stream_samples` has a timestamp matching the Play moment (within sub-100 ms of session start), not delayed by the `activity:start` round-trip.
- On the analytics timeline the phase track origin aligns with session start instead of trailing it by ~1.5 s.
