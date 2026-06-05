# Handoff — instruction-stream-fixes

## 1. Frame
We traced and fixed three bugs in the breath session instruction stream pipeline (wrong phase durations, missing first-phase instructions, and the initial `rest` phase never reaching the server); the chat is compacted but the knowledge is durable in the changed files — rehydrate from them, don't trust memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — the central coordinator: lifecycle events, phase-change detection, pending-instruction queue, and the two bugs fixed here (duration field, phaseChanged false-negative)
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` — rate-limiting, buffering, and the new `isStreamReady` gate that prevents the first-message race condition
- `lib/Core/Grpc/ModuleInstructionStream.dart` — gRPC stream lifecycle; now sends a `stream_ready` probe on open and fires `_readyController` only after the probe ACK

### Read on demand
- `mind_api/src/realtime/module-instruction-stream.grpc.controller.ts` — server handler; now logs every sample recv/push/drop, and short-circuits `stream_ready` probe without storing it
- `mind_api/src/realtime/services/stream-engine.service.ts` — no logic changes; added phase/event summary to flush log line
- `mind_api/src/realtime/constants/stream-data-types.ts` — added `STREAM_READY = 'stream_ready'`
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` — `currentPhaseTotalDuration` (ticks) and `currentIntervalMs` (ms/tick) — the two fields relevant to duration math

## 3. Current state

**Done:**
- **Bug 1 — wrong `durationMs` (always 1000ms):** `BreathModuleStateChannel` was passing `state.currentIntervalMs` (tick cadence = 1000 ms) instead of `state.currentPhaseTotalDuration * state.currentIntervalMs` (phase length in ms). Fixed at lines 100 and 107 of `BreathModuleStateChannel.dart`.
- **Bug 2 — first phase of exercise 0 never sent:** `_previousPhase` and `_previousExerciseIndex` were set during a BehaviorSubject replay (status=pause, before session start). When the session actually started with the same phase/exercise, `phaseChanged = false` → silent skip. Fixed by resetting both to `null` inside `_handleLifecycle` when `_started` first becomes true.
- **Bug 3 — initial `rest` instruction never reaches server:** The `rest` instruction is the very first message sent on a newly opened gRPC stream. The server's NestJS gRPC handler has a race condition (async JWT interceptor runs before `request.subscribe()` is called), so the first DATA frame is lost. Fix: `_openStream()` now sends a lightweight `stream_ready` probe immediately; `_readyController` fires only after the probe ACK; `BreathModuleInstructionStream._canSendNow()` gates on `isStreamReady`, so `rest` is buffered and flushed only once the server is confirmed ready.
- **Diagnostic logging added** (both sides): `BreathModuleStateChannel` logs skip-reason, send, queue, flush; `BreathModuleInstructionStream` logs emit/buffer path; `ModuleInstructionStream` logs stream-open; server controller logs `recv`/`pushed`/`drop <REASON>`; `StreamEngine` flush log now includes sample summary `[rest, inhale, ...]`.

**In-flight:**
- Bug 3 fix has **not yet been tested** with live logs. The probe/ACK round-trip needs to be verified: server should log `recv: type=stream_ready`, return an ACK, mobile should log `stream ready (probe acked)`, then the buffered `rest` should appear in DB.
- The diagnostic logging added during investigation is still in the codebase. Once bugs are confirmed fixed it should be removed or reduced.

**Uncommitted working-tree state:**
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — modified (bugs 1+2 fixed, diagnostic logs)
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` — modified (isStreamReady gate, diagnostic logs)
- `lib/Core/Grpc/ModuleInstructionStream.dart` — modified (probe send, _streamReady flag, readyController moved to first ACK)
- `mind_api/src/realtime/module-instruction-stream.grpc.controller.ts` — modified (diagnostic logs, stream_ready short-circuit)
- `mind_api/src/realtime/services/stream-engine.service.ts` — modified (flush log summary)
- `mind_api/src/realtime/constants/stream-data-types.ts` — modified (added STREAM_READY)

## 4. Next step
Run the app + API, start a breath session, and check: (a) server logs show `recv: type=stream_ready` followed by `recv: type=breath_phase phase=rest`; (b) DB contains a `rest` row for exercise 0; (c) subsequent phases (inhale, exhale) still appear correctly. If confirmed, strip the diagnostic logging and commit all six files.

## 5. Working discipline
- Investigate and prove with logs before fixing — the user blocked two premature fixes during this session.
- No commits without explicit user permission.
- No guessing: add targeted logs, get evidence, then fix.
- Stop and report findings; don't chain fixes across multiple layers without showing intermediate results.

## 6. Error log
- **Wrong hypothesis: pending-instruction overwrite.** Initially assumed the missing phases were caused by `_pendingInstruction` being a single field (overwritten by each new phase while `moduleSessionId` was null). Logs showed no `queuing` messages → hypothesis wrong. The real cause was `phaseChanged = false` due to BehaviorSubject replay.
- **Wrong hypothesis: server-side filtering.** Assumed the `rest` instruction was received by the server but filtered. `total=2` when inhale pushed (push #1 = session_started, push #2 = inhale) proved rest was never received. The drop happens before the `next` handler.
- **Debug log placed before `_openStream()` call was insufficient** for the stream-readiness issue; needed to add server-side `recv` logging to pinpoint the boundary.

## 7. Orientation
- **`currentIntervalMs` vs `currentPhaseTotalDuration`:** `currentIntervalMs` = wall-clock ms between ticks (always 1000 for ClockTickService). `currentPhaseTotalDuration` = phase length in *ticks*. Correct `durationMs` = product of both. Do not confuse them.
- **`moduleSessionId` vs breath session ID:** `moduleSessionId` is the server-generated UUID for the `ModuleSession` entity (returned via gRPC state channel). The breath session ID (`_sessionId` in `BreathModuleStateChannel`) is the Drift DB UUID of the `BreathSession`. The instruction stream `sessionId` field uses `moduleSessionId`.
- **`BreathSessionStatus.rest` vs `BreathPhase.rest`:** Status `rest` means the exercise is in its inter-cycle rest period (no steps). Phase `rest` means the current breath phase is rest. Both can be true simultaneously for a rest-only exercise (exercise 0).

## 8. Domain model spine
- **Instruction stream flow:** Mobile `BreathModuleStateChannel` → `BreathModuleInstructionStream` (buffer/rate-limit) → `ModuleInstructionStream` (gRPC sink) → server `ModuleInstructionStreamGrpcController` → `StreamEngine.push()` → periodic flush → `session_stream_samples` DB table. Settled; don't re-litigate the layer split.
- **Phase duration units:** All exercise step/rest durations are stored in *ticks* throughout the Dart model (`ExerciseStep.duration`, `BreathExerciseDTO.restDuration`, `currentPhaseTotalDuration`). Conversion to ms happens only at the send site: `ticks × currentIntervalMs`. Settled.
- **Stream readiness gate:** `isStreamReady` becomes true only after the server ACKs the `stream_ready` probe. `_canSendNow()` in `BreathModuleInstructionStream` must check this flag; without it the first real instruction races with the server's subscription setup. Settled.

## 9. Hard rules
- Never commit without explicit user instruction.
- All generated/edited files must be in English.
- No automatic memory writes unless user says "remember this" / "запомни".
- Flutter binary: `/usr/local/bin/flutter`.

## 10. Cross-cutting contracts / invariants

| Contract | Where it lives | Rule |
|---|---|---|
| `durationMs` in `breath_phase` payload | `BreathModuleStateChannel.dart:100,107` | Must be `currentPhaseTotalDuration * currentIntervalMs`, never bare `currentIntervalMs` |
| `sessionId` field in `StreamSample` proto | `BreathModuleInstructionStream` → `ModuleInstructionStream` | Must be `moduleSessionId` (from `ModuleState`), not the breath session DB UUID |
| `stream_ready` probe | `ModuleInstructionStream._openStream()` | Sent with no `sessionId` / `moduleId`; server must ACK without pushing to `StreamEngine` |
| `_readyController.add(null)` timing | `ModuleInstructionStream` | Fires inside the first ACK handler, not at the end of `_openStream()` |
| `_previousPhase` / `_previousExerciseIndex` reset | `BreathModuleStateChannel._handleLifecycle` | Must be set to `null` when `_started` first becomes true; otherwise BehaviorSubject replay poisons `phaseChanged` |

## 11. Per-unit map with watch-points

| Unit | What it became | Watch-point |
|---|---|---|
| `BreathModuleStateChannel._handleInstruction` | Sends correct `durationMs`; first phase after session start always detected | Verify `_previousPhase = null` reset runs before `_handleInstruction` is called for the start-tick (it does: lifecycle runs first in `_onState`) |
| `BreathModuleStateChannel._handleLifecycle` | Resets `_previousPhase` / `_previousExerciseIndex` to null on first start | Only fires reset when `!_started`; does NOT reset on resume/unpause — correct |
| `BreathModuleInstructionStream._canSendNow` | Guards on `isGrpcConnected && isStreamReady && rate-limit` | If stream is reconnected mid-session, `isStreamReady` resets to false; `rest` could be lost again if a phase happens to land at reconnect time — not fixed yet |
| `ModuleInstructionStream._openStream` | Sends `stream_ready` probe; `_streamReady = false` until first ACK | Probe has no `sessionId` — server must not attempt `session.sessionId !== msg.sessionId` check for it (currently `stream_ready` is short-circuited before that check — correct) |
| Server `stream_ready` handler | Returns ACK immediately, skips `streamEngine.push()` | Must remain before the `isPaused` check and the `streamEngine.push()` call; do not move it |
| Server `recv`/`pushed` debug logs | Added for diagnosis | Remove or downgrade after bug 3 confirmed fixed |
| `StreamEngine` flush log | Now includes `[rest, inhale, ...]` summary | Keep — useful for ongoing observability |
