# Handoff — instruction-stream-deep-investigation

## 1. Frame
We spent a full session investigating why breath phase instructions (especially the initial `rest` phase) are missing from the DB, made several implementation attempts that each broke something new, and ended by reverting to a clean baseline with only one correct fix applied — the `_previousPhase = null` reset on session start.

---

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — the one file with a real fix applied; controls lifecycle events and phase-change detection
- `.ai-factory/notes/100-behaviorsubject-replay-phasechanged-fix.md` — full spec for the null-reset fix: three-scenario lifecycle walkthrough of `_previousPhase`/`_previousExerciseIndex`, why BehaviorSubject replay poisons them, and what exactly the reset fixes
- `.ai-factory/handoffs/01-instruction-stream-fixes.md` — previous handoff with the original bug descriptions and the architecture of the stream pipeline

### Read on demand
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart` — rate-limiting and buffering layer between StateChannel and the gRPC sink; currently at HEAD (no changes)
- `lib/Core/Grpc/ModuleInstructionStream.dart` — gRPC stream lifecycle; currently at HEAD (no changes)
- `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart` — state machine; lines 126 and 150 show `currentIntervalMs: -1` emitted on session start transition; lines 282–377 show `currentIntervalMs: intervalMs` set on each real tick
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` — `currentIntervalMs` field: wall-clock ms between ticks, default `-1` before first tick; `currentPhaseTotalDuration`: phase duration in ticks (always positive)
- `mind_api/src/realtime/module-instruction-stream.grpc.controller.ts` — server gRPC handler; currently at HEAD (no diagnostic logs, no STREAM_READY)
- `mind_api/src/realtime/services/stream-engine.service.ts` — buffers and flushes samples to DB; currently at HEAD
- `mind_api/src/realtime/constants/stream-data-types.ts` — currently at HEAD (no STREAM_READY constant)

---

## 3. Current state

**Done (confirmed working, in uncommitted working tree):**
- **`_previousPhase = null` / `_previousExerciseIndex = null` reset** in `BreathModuleStateChannel._handleLifecycle` when `_started` first becomes true. This fixes the BehaviorSubject replay bug: before session starts, the replay call sets `_previousPhase` to the current phase (e.g. `rest`); without the reset, when the session actually starts with the same phase, `phaseChanged = false` and the first instruction is silently dropped.

**Confirmed broken / reverted:**
- All probe/ACK mechanism code (`stream_ready` probe, `_streamReady` flag, `openStream()` public method, `isStreamReady` getter) — tried three times, each attempt broke something different. Fully reverted from all files.
- All diagnostic logging added during investigation — reverted.
- `_durationMs()` helper method (was meant to fix `-15` duration) — reverted.
- Server: `STREAM_READY` constant, handler in controller, flush-summary log — all reverted to HEAD.

**Still broken / open:**
- **Initial `rest` instruction lost — gRPC race condition on first message**: the null fix causes `rest` to open the gRPC stream at T=0 (instead of `inhale` at T=15s). But `rest` is now the first message on that new stream and hits the same race condition: the server's NestJS gRPC handler runs an async JWT interceptor before `request.subscribe()` is called, so the first DATA frame can arrive before the server has subscribed to the Subject — `rest` is silently dropped. The null fix is still valuable: by opening the stream 15 seconds earlier, inhale and exhale arrive on an already-warmed stream and are received correctly. Without the null fix, inhale was the first message and was also lost (DB only showed exhale). Without a probe/ACK fix, rest will always be lost regardless of the null fix. The probe/ACK approach was correct in concept but failed in execution (see error log).
- **Duration `-15`**: when `rest` is stored (e.g. in session `a5aeffc0`), `durationMs = -15`. This is because `currentIntervalMs = -1` (sentinel for "not yet measured by ClockTickService") in the state emitted at the moment of session start transition (state machine resets it to -1 at lines 126/150 on the pause→active transition). The formula `currentPhaseTotalDuration * currentIntervalMs = 15 * (-1) = -15`. The fix is to treat `-1` as a sentinel and fall back to `1000`: `intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000`.

**Uncommitted working-tree state:**
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — modified (only the two null resets remain; everything else reverted to HEAD)
- All other files: clean (at HEAD)

---

## 4. Next step

Two separate bugs remain. Tackle them in order:

**Bug A — duration `-15`:** Apply the sentinel fix in `BreathModuleStateChannel._flushPending` and `_handleInstruction`. Replace `pending.currentPhaseTotalDuration * pending.currentIntervalMs` with a guarded expression: `final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000; return state.currentPhaseTotalDuration * intervalMs;`. This is a one-liner change with zero risk. Verify in DB: `rest` should show `durationMs: 15000`.

**Bug B — `rest` lost (race condition):** This requires the probe/ACK mechanism. The correct implementation is documented in the error log below — previous attempts had specific bugs that are now catalogued. Before implementing, read the error log carefully.

---

## 5. Working discipline
- **Prove with logs before fixing.** The user blocked two premature fixes in this session.
- **No commits without explicit user instruction.**
- **Stop and explain in Russian when asked** — user communicates in Russian, prefers long narrative explanations when confused.
- **One change at a time.** Every attempt to chain multiple fixes in one pass caused new breaks.
- **Show concrete evidence** (log lines, DB rows, `total=N` counters) before claiming a bug is real or a fix works.
- Do not speculate in the explanation — if you don't know, say so.

---

## 6. Error log

### Mistake 1 — probe/ACK: STREAM_READY handler placed after session guards
The server's `STREAM_READY` short-circuit was inserted AFTER the `!msg.sessionId` and `session.sessionId !== msg.sessionId` guards. The probe has no `sessionId` (empty string), so it hit `INVALID_ARGUMENT` / `SESSION_MISMATCH` and returned an error before reaching the STREAM_READY handler. The mobile received the error response, logged it silently, and `_streamReady` never became true — buffer never flushed.

**Correction:** `STREAM_READY` must be the **very first** check in the `next` handler, before any session validation. The probe must be handled before `!msg.sessionId` is checked.

### Mistake 2 — probe/ACK: deadlock when `_canSendNow()` gates on `isStreamReady`
When `isStreamReady = false`, `_canSendNow()` returned false → `_emit()` not called → `emit()` not called → `_openStream()` not called → probe never sent → `isStreamReady` never became true. Perfect deadlock.

**Correction:** When an item is buffered due to `!isStreamReady`, the code must **separately** trigger `_instructionStream.openStream()` to send the probe. The `openStream()` must be a public method that sends the probe independently of `emit()`.

### Mistake 3 — probe/ACK: `_readyController.add(null)` fired at end of `_openStream()` instead of on ACK
In the original HEAD code, `_readyController.add(null)` fires immediately at the end of `_openStream()`. This means `flushBuffer()` is called before the server is ready — the race condition is not solved, just shifted. Moving the `_readyController.add(null)` call to fire only when the first ACK arrives (inside the ACK case of `response.listen`) is the correct approach.

### Mistake 4 — `_durationMs()` method caused regression in session 7
Adding `_durationMs()` was correct in logic but coincided with a server restart between sessions 6 and 7. The instruction stream took >25 seconds to re-establish after server restart (gRPC reconnect backoff), causing all instructions to arrive after session interruption and be rejected by `NO_SESSION`. This looked like the code was broken, but the root cause was the timing of the server restart. The fix itself (`_durationMs`) is logically correct and should be re-applied.

### Mistake 5 — wrong explanation of `session_started` / `rest` going through "the same channel"
Initially stated that `rest` is lost because it's "the first message on a new stream." This is true. But also initially confused the reader by not clearly distinguishing that `session_started` is pushed **by the server** (ActivityEngine → StreamEngine, no network) while `rest` is pushed **by the mobile** via a separate gRPC instruction stream. They both end up in `session_stream_samples` but come from completely different sources. `session_started` never fails because it never crosses the network for instruction delivery.

### Mistake 6 — wrong explanation of `currentIntervalMs = -1`
Initially claimed "ticks have been running since the module opened, so by session start `currentIntervalMs = 1000`." The user correctly called this out. The real behavior: the state machine emits `currentIntervalMs: -1` **at the moment of the pause→active transition** (lines 126 and 150 in `BreathSessionStateMachine.dart`). This is a deliberate reset — the state machine says "I don't know the interval for this new phase yet." The first real tick after that sets `currentIntervalMs = 1000`. The `_pendingInstruction` captures the state at transition time, before the first tick.

---

## 7. Orientation

### `session_started` vs `rest` — completely different pipes
- `session_started` is pushed by **the server** inside `ActivityEngine.startActivity()` directly to `StreamEngine.push()`. Zero network involved.
- `rest`, `inhale`, `exhale` are sent by **the mobile** via the gRPC instruction stream (`ModuleInstructionStreamGrpcController`), which then pushes to `StreamEngine`.
- They both end up in `session_stream_samples` table, often in the same DB row (batched by the 5s periodic flush), but this is coincidence of timing, not architecture.
- This distinction explains why `session_started` is always reliable and `rest` is fragile.

### `moduleSessionId` vs breath session ID
- `moduleSessionId` = server-generated UUID for the `ModuleSession` entity, returned to mobile via the gRPC module state channel. Used as `sessionId` in all instruction stream samples.
- Breath session ID (`_sessionId` in `BreathModuleStateChannel`) = Drift DB UUID for the `BreathSession` record. Used only as `refId` in the start signal. Never used in instruction stream.

### `currentIntervalMs` vs `currentPhaseTotalDuration`
- `currentIntervalMs`: wall-clock milliseconds between ticks. Default `-1` (sentinel = not yet measured). Becomes `1000` after the first real clock tick from `ClockTickService`.
- `currentPhaseTotalDuration`: phase duration in **ticks** (always positive). For `rest` phase in exercise 0, this is `restDuration = 15`.
- Correct formula: `durationMs = currentPhaseTotalDuration * max(currentIntervalMs, 1000)` where the max guards against the `-1` sentinel.

### `BreathSessionStatus.rest` vs `BreathPhase.rest`
- Status `rest` = the exercise is in its inter-cycle rest period (between breathing cycles).
- Phase `rest` = the current breath phase is rest. Can be true for a rest-only exercise (exercise 0: `steps: [], restDuration: 15`) or during the inter-step rest of a normal exercise.

---

## 8. Domain model spine

### Instruction stream pipeline (settled — don't re-litigate)
```
Mobile BreathModuleStateChannel
  → detects phase change (phaseChanged = true)
  → queues in _pendingInstruction if moduleSessionId not yet known
  → flushes via BreathModuleInstructionStream.sendSample()
  → BreathModuleInstructionStream (rate-limit, buffer)
  → ModuleInstructionStream.emit() (gRPC sink)
  → server ModuleInstructionStreamGrpcController.next()
  → StreamEngine.push()
  → periodic flush (5s) or event-triggered flush → session_stream_samples DB table
```

### Session events pipeline (settled — completely separate)
```
Mobile BreathModuleStateChannel
  → _channel.start() / pause() / unpause() / end() / stop()
  → ModuleStateChannel (gRPC module state stream)
  → server ModuleStateGrpcController
  → ActivityEngine.startActivity() / pauseActivity() etc.
  → ActivityEngine calls StreamEngine.push() directly (no network for the push itself)
  → same periodic flush → same session_stream_samples table
```

### Race condition root cause (established — don't re-litigate)
NestJS gRPC bidirectional streaming uses an RxJS `Subject` internally. The server creates the Subject, pipes gRPC DATA frames into it, then calls the controller method with it. The controller calls `request.subscribe(next: ...)`. Because the `GrpcAuthInterceptor` runs async JWT validation between stream establishment and `request.subscribe()`, the first DATA frame can arrive and be pushed to the Subject before any subscriber exists. Hot Subject → message silently dropped.

Evidence: `total=2` when `inhale` arrives (push #1 = `session_started` from ActivityEngine, push #2 = `inhale`). `rest` was never pushed. Server `recv` log never fired for `rest`. `connectedStreams=3` confirmed the stream was physically established.

---

## 9. Hard rules
- Never commit without explicit user instruction.
- All files in English.
- No memory writes unless user says "remember this" / "запомни".
- Flutter binary: `/usr/local/bin/flutter`.
- Prove bugs with logs before fixing. Do not chain multiple fixes in one pass.

---

## 10. Cross-cutting contracts / invariants

| Contract | Location | Rule |
|---|---|---|
| `durationMs` formula | `BreathModuleStateChannel._handleInstruction` and `_flushPending` | Must be `currentPhaseTotalDuration * max(currentIntervalMs, 1000)`. Never use raw `currentIntervalMs` — it is `-1` for the initial state on session start. |
| `sessionId` in StreamSample | `BreathModuleInstructionStream.sendSample()` → `ModuleInstructionStream._toProto()` | Must be `moduleSessionId` (from `ModuleState`), NOT the breath session DB UUID. |
| `_previousPhase` / `_previousExerciseIndex` reset | `BreathModuleStateChannel._handleLifecycle` | Must be set to `null` when `_started` first becomes true (lines 68–69 in current file). Without this reset, BehaviorSubject replay poisons `phaseChanged` and the first instruction is silently dropped. |
| STREAM_READY probe position (for future probe/ACK impl) | `module-instruction-stream.grpc.controller.ts` | Must be the **first** check in the `next` handler — before `!msg.sessionId`, before `getActiveSession()`, before everything. Probe has no sessionId; any earlier guard will reject it. |
| `openStream()` must be called from buffer path (for future probe/ACK impl) | `BreathModuleInstructionStream.sendSample()` | When `!_canSendNow()` and item is buffered, must also call `_instructionStream.openStream()`. Without this, the stream never opens and the buffer never flushes (deadlock). |
| `_readyController.add(null)` timing (for future probe/ACK impl) | `ModuleInstructionStream._openStream()` and ACK handler | Must fire **inside the first ACK handler**, not at the end of `_openStream()`. Firing it at end of `_openStream()` means `flushBuffer()` runs before server has subscribed — same race, different location. |

---

## 11. Per-unit map with watch-points

| Unit | What it became | Watch-point |
|---|---|---|
| `BreathModuleStateChannel._handleLifecycle` | Added `_previousPhase = null; _previousExerciseIndex = null;` when `_started` first becomes true (lines 68–69) | Reset runs BEFORE `_handleInstruction` on the same tick (lifecycle called first in `_onState`). Do not swap the call order. |
| `BreathModuleStateChannel._handleInstruction` | At HEAD — no changes | The `phaseChanged` detection depends on `_previousPhase` being null after the reset. Verify that `_onState` calls `_handleLifecycle` before `_handleInstruction`. |
| `BreathModuleStateChannel._flushPending` / direct send | At HEAD — uses raw `currentPhaseTotalDuration * currentIntervalMs` | This gives `-15` for `rest` because `currentIntervalMs = -1` at session start. Fix is pending (Bug A in next step). |
| `ModuleInstructionStream` | At HEAD — no probe/ACK, `_readyController.add(null)` fires at end of `_openStream()` | Race condition for first message on new stream remains. Fix is pending (Bug B in next step). |
| `BreathModuleInstructionStream` | At HEAD — no `isStreamReady` gate, no `openStream()` call | Clean baseline. When re-adding probe/ACK, add `_instructionStream.openStream()` call in the `else` branch of `sendSample()`. |
| Server `module-instruction-stream.grpc.controller.ts` | At HEAD — no STREAM_READY handler, no diagnostic logs | When re-adding STREAM_READY: insert it as the **first** check, before `!msg.sessionId`. |
