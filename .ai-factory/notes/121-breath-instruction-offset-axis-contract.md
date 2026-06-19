# Breath instructions on a monotonic offset axis; payload `{phase, tickCount, offsetMs}`

**Date:** 2026-06-19
**Source:** conversation context

## Key Findings

- The breath-session timeline is misaligned because the geometry axis is a **cross-clock subtraction**: mind_web computes `secFromStart(event.timestamp, startedAt)` = `clientDateTimeNow − serverStartedAt` (`mind_web/src/pages/SessionsPage/transforms.ts:4`). Client `DateTime.now()` and server `startedAt` are different physical clocks → the whole phase timeline drifts.
- `BreathModuleStateChannel._handleInstruction`/`_flushPending` send `durationMs = currentPhaseTotalDuration * currentIntervalMs`. At the origin emit `currentIntervalMs == -1` (seeded in `BreathSessionState.initial()` / the state-machine initial states), so `durationMs` is negative (the observed `-15`).
- Fix: the canonical timeline is **monotonic offset-from-origin (ms)**, owned by the mobile client. Each sample carries `data.offsetMs`; the wire `int64 timestamp` is demoted to a single wall-clock stamp for sort/bookkeeping only.
- `durationMs` must not be sent at all — phase duration is derivable from the gap between successive offsets (mind_web already computes bar width that way). The only intrinsic phase metadatum is the **tick count** (`currentPhaseTotalDuration`, misnamed — it is a count of ticks, not ms).
- **No proto change**: `StreamSample.data` is a free `google.protobuf.Struct` explicitly meant to evolve without proto edits; the server stores `data` verbatim into jsonb. Server and `mind_api` are untouched.

## Details

### Current state
- `lib/BreathModule/Core/BreathModuleStateChannel.dart:98` — `ts = DateTime.now().millisecondsSinceEpoch`; lines 104/111 — `sendSample(sessionId, state.phase.name, state.currentPhaseTotalDuration * state.currentIntervalMs, ts)`.
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart:10` — `sendSample(String sessionId, String phase, int durationMs, int timestampMs)` → emits `InstructionSample(timestamp: timestampMs, data: {'phase': phase, 'durationMs': durationMs})`.
- `proto/module_instruction_stream.proto` — `StreamSample { session_id, int64 timestamp, module_id, instruction_type, Struct data }`. `data` is untyped by design.
- `BreathSessionStateMachine.resume()` (`packages/breath_module/.../BreathSessionStateMachine.dart:182`) already emits the first active state (`status=rest`, the correct phase) **synchronously at the start tap** — so the first `rest` instruction is produced at origin, not on the first tick. The remaining defect is purely the axis (cross-clock) and `durationMs` (`-1`).

### The change
1. `BreathModuleStateChannel`: add `Stopwatch _stopwatch` and `DateTime? _originWallClock`. In `_handleLifecycle`, at the `!_started` start branch (immediately around `_channel.start()`, line 66 — **before** `_handleInstruction` runs in the same `_onState` pass), do `_stopwatch..reset()..start()` and `_originWallClock = DateTime.now()`. In `reset()` also reset the stopwatch.
2. Stamp each instruction with `offsetMs = _stopwatch.elapsedMilliseconds` instead of `DateTime.now()`. Because `resume()` emits at the start tap, the first `rest` lands at `offsetMs ≈ 0`.
3. `BreathModuleInstructionStream.sendSample` → `(String sessionId, String phase, int tickCount, int offsetMs)`; `data = {'phase': phase, 'tickCount': tickCount, 'offsetMs': offsetMs}`. Drop `durationMs` and the `* currentIntervalMs` product. `tickCount = state.currentPhaseTotalDuration`.
4. Keep populating the wire `InstructionSample.timestamp` with a wall-clock ms (e.g. `_originWallClock + offsetMs`, or `DateTime.now()`) so server-side sort/dedup and the (interim) old web path keep working.

### Cross-repo coupling (must coordinate, not in this repo)
- mind_web `transforms.ts` must switch `parsePhases`/`toSeries` to read `data.offsetMs` (drop `secFromStart` and the `startedAt` argument; x-axis `min:0`). Until that ships, web loses the duration label but its existing `timestamp`-based bars keep rendering (no worse than today). This is the mind_web counterpart task — track it in mind_web's roadmap.

### Guards
- No proto edit; no `mind_api` change.
- Do NOT touch the readiness gate (note 114) or the `_pendingInstruction` parking around the async `moduleSessionId` round-trip — `offsetMs` is captured at phase time and survives parking exactly like the old `ts` did.
- Keep `moduleId='breath'`, `instructionType='breath_phase'`.

## Open Questions

- Should the wire `timestamp` be `originWallClock + offsetMs` (a clean reconstructed wall-clock) or a fresh `DateTime.now()` at send? The former keeps timestamp monotone with offset; pick it unless server dedup needs true receive-adjacent time.
  **Resolution:** wire `timestamp = originWallClock + offsetMs`, computed at phase-capture time — NOT `DateTime.now()` at send. A sample can sit in `_pendingInstruction` until `moduleSessionId` arrives; stamping at send would drift from `offsetMs`. The reconstructed `(timestamp, offsetMs)` pair stays consistent and monotone, and the bookkeeping-only server needs no true receive-time.
