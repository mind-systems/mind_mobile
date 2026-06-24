# Test Plan: BreathModuleStateChannel offset-axis and pause-marker gap tests

## Context
`BreathModuleStateChannel` computes a monotonic `offsetMs` (from an injected `Stopwatch`) and a wall-clock `timestampMs` (from `_originWallClock` captured via an injected `clock`) for every instruction and boundary marker it dispatches. The existing test suite covers lifecycle and dispatch routing thoroughly but never asserts on the `offsetMs`/`timestampMs` fields of `sendSample`. This plan adds the offset-axis and timing assertions.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/BreathModule/breath_module_state_channel_test.dart`

## Target Spec File
`test/BreathModule/breath_module_state_channel_test.dart` (extend existing file)

## Source Under Test
`lib/BreathModule/Core/BreathModuleStateChannel.dart`

## Pre-flight Notes (read before writing tests)

These facts are confirmed against the current source/test and override anything stale in the milestone wording:

1. **No source changes required.** The constructor already accepts `Stopwatch Function() stopwatchFactory = Stopwatch.new` (line 37) and `DateTime Function() clock = DateTime.now` (line 38). The "Test Infra prerequisite" is already satisfied in the source — all injection points exist.
2. **The fake already captures the 5-tuple.** `_FakeInstructionStream.sendSampleCalls` is `List<(String, String, int, int, int)>` storing `(sessionId, phase, tickCount, offsetMs, timestampMs)` (test lines 57, 63–64). Do **not** rewrite the fake's tuple shape. Access `offsetMs` via `call.$4` and `timestampMs` via `call.$5`. The milestone's "extend the fake to capture the full 5-tuple" is already done — the real remaining infra work is the controllable `Stopwatch` fake plus `_make()` wiring (Task 1).
3. **Real `Stopwatch` cannot give deterministic offsets.** Its `elapsedMilliseconds` is wall-clock derived. A fake that `implements Stopwatch` with a settable elapsed value is required to assert exact offsets and monotonicity rather than fuzzy tolerances.
4. **Origin wall-clock is captured exactly once per started lifecycle.** `_originWallClock = _clock()` runs only inside the `!_started` start branch (line 90). `_wireTimestamp` reads `_originWallClock?.millisecondsSinceEpoch` and only falls back to `_clock()` when origin is null (line 145). So after a successful start, `clock` is not called again for subsequent instructions in the same lifecycle.
5. **Start does not depend on `moduleSessionId`.** The start branch (lines 86–94) runs on the first `wasPaused && isActive` transition regardless of whether a `ModuleState` has arrived. This is why the pending-flush scenario still has a valid `_originWallClock`.
6. **Marker tickCount semantics:** pause marker is emitted with `tickCount == 0` (line 106); the resume re-emit carries `state.currentPhaseTotalDuration` (line 98). Offsets for both come from `_stopwatch.elapsedMilliseconds` at emit time.
7. **Mind the status-unchanged short-circuit** (line 77) and the start branch resetting `_previousPhase`/`_previousExerciseIndex` to null (lines 93–94) when constructing emission sequences — copy the priming patterns already used in the Phase 9/10 groups.
8. **The start branch resets the stopwatch before any instruction is read.** Within a single `_onState` call the order is `_handleLifecycle` → `_handleInstruction`. On the start emission, `_handleLifecycle` runs `_stopwatch..reset()..start()` (line 89), zeroing the fake's `elapsedMs`, *before* `_handleInstruction` reads `elapsedMilliseconds` (line 127). A test cannot intervene between the reset and the read — they are in the same microtask. **Consequence:** the first post-start instruction always carries offset 0; any non-zero offset must be captured on a later, non-start emission after advancing the fake. This drives the sequencing in Tasks 2 (case 3) and 5.

## Tasks

### Phase 1: Test infrastructure (in-file)

- [x] **Task 1: Add a controllable `_FakeStopwatch` and extend `_make()` to inject `stopwatchFactory` + `clock`**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  This task adds plumbing only — no `test(...)` cases. It is a prerequisite for Tasks 2–6.
  Requirements:
  - Add a `_FakeStopwatch implements Stopwatch` fake with a mutable elapsed value (e.g. `int elapsedMs = 0;`), overriding `elapsedMilliseconds` to return it, and `reset()` (sets back to 0) / `start()` / `stop()` as no-ops or simple flags. Use `noSuchMethod` for the remaining `Stopwatch` members (mirror the existing fakes' `noSuchMethod` pattern). The test advances simulated time by mutating `elapsedMs` between emissions.
  - Note that `reset()` is called inside the source start branch (line 89); confirm the fake's `reset()` returns elapsed to 0 so post-start offsets are measured from session start.
  - Add an optional clock spy: a small counter-backed `DateTime Function()` returning a fixed `DateTime` (e.g. `DateTime.fromMillisecondsSinceEpoch(1_000_000)`) while counting invocations. A plain closure over a mutable counter is sufficient; no new top-level class is mandatory.
  - Extend `_make()` to accept optional `Stopwatch Function()? stopwatchFactory` and `DateTime Function()? clock`, forwarding them to the `BreathModuleStateChannel` constructor only when provided (so all existing tests keep their default real `Stopwatch`/`DateTime.now` behavior unchanged).
  - **`_Fixture` is a record typedef — records have no optional/defaulted fields**, so every `_make()` call must populate the new fields. Make them nullable: add `_FakeStopwatch? stopwatch` and an `int Function()? clockCallCount` (or equivalent counter accessor) to the `_Fixture` record, populated only when the caller opts into the fakes and left `null` otherwise. This stays backward-compatible because no existing test reads the new fields. The offset/timing tests opt in and read these; lifecycle tests keep passing nothing and get `null`.
  - Do not alter the existing `_Fixture` consumers' behavior; additions must be backward-compatible.

### Phase 2: Offset-axis assertions

- [x] **Task 2: Offset monotonicity across phase changes**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  New group, e.g. `BreathModuleStateChannel — offset axis`. Build with the injected `_FakeStopwatch`. Seed a `ModuleState(moduleSessionId: 'sid', ...)`, start a session, then drive multiple genuine phase changes, advancing `_FakeStopwatch.elapsedMs` between each emission.
  Test cases:
  - `should emit instructions with strictly increasing offsetMs when the stopwatch advances between phase changes`
  - `should emit instructions with non-decreasing (equal) offsetMs when the stopwatch does not advance between phase changes`
  - `should measure offsetMs from session start (first post-start instruction offset is 0 because the start branch resets the stopwatch; advance the fake before the next phase change to see a non-zero offset)`

- [x] **Task 3: Pause boundary marker offset and tickCount**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Same group. **Seed `ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active)` first** — `_emitMarker` drops the marker and returns early when `_moduleSessionId == null` (lines 67–71), so without a seeded module session no `sendSample` is recorded for the pause marker and the test has nothing to assert on. Then start a session (advance `elapsedMs` to a positive value) and transition active → pause so `_emitMarker('pause', 0, elapsedMs)` (line 106) fires. Locate the pause marker via `call.$2 == 'pause'`.
  Test cases:
  - `should emit a pause marker with offsetMs > 0 when pausing after the stopwatch has advanced past zero`
  - `should emit a pause marker with tickCount == 0 regardless of the current phase duration`
  - `should emit a pause marker whose timestampMs equals originWallClockMs + offsetMs`

- [x] **Task 4: Resume re-emit offset ordering vs pause marker**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Same group. Sequence: start → phase change → pause (advance `elapsedMs` to P) → advance `elapsedMs` to R (R > P) → resume to an active phase, which re-emits via `_emitMarker(phase.name, currentPhaseTotalDuration, elapsedMs)` (line 98). The resume marker is the actual phase name (e.g. `'exhale'`), not `'pause'` — filter accordingly.
  Test cases:
  - `should emit the resumed phase marker with offsetMs >= the pause marker offsetMs`
  - `should emit the resumed phase marker with tickCount equal to currentPhaseTotalDuration (not 0)`
  - `should dispatch exactly one sendSample on resume (the marker only, no duplicate instruction)` — the resume branch sets `_previousPhase = state.phase` (line 99) *before* `_handleInstruction` runs, so `phaseChanged` is false and no second instruction fires. Assert the count to guard against a regression where both the marker and an instruction dispatch.

### Phase 3: Timestamp / clock invariants

- [x] **Task 5: Pending flush reuses the offset and timestamp captured at instruction time**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  New group, e.g. `BreathModuleStateChannel — offset axis (pending flush)`. Do not seed `ModuleState` initially so `moduleSessionId` stays null and the instruction is buffered (lines 129–131).

  **Critical sequencing — the buffering phase change MUST be a non-start emission** (see Pre-flight Note 8). For an instruction to be buffered, `_handleInstruction` requires `_started == true` (line 121), which is only set by the start branch. But that same start branch runs `_stopwatch..reset()..start()` (line 89), zeroing the fake's `elapsedMs`, and the reset runs before the offset read within the same `_onState` microtask — a test cannot intervene between them. So the start emission always buffers offset 0, never `T1`. The capture of `T1` must happen on a **second** phase change after the session has started. Use this exact sequence:
  1. Prime (pause, inhale) — no `ModuleState` seeded.
  2. Emit breath/inhale → **starts** the session, resets stopwatch to 0, buffers offset 0 (sessionId still null).
  3. Advance `_FakeStopwatch.elapsedMs = T1`.
  4. Emit a **second** genuine phase change (e.g. breath/exhale) while still no `ModuleState` → lifecycle short-circuits (`breath == breath`, line 77), `_handleInstruction` overwrites `_pendingInstruction` with offset `T1` (same overwrite path as the Phase 10 test at test lines 1007–1031).
  5. Advance `_FakeStopwatch.elapsedMs = T2` (> T1).
  6. Push `ModuleState(moduleSessionId: 'sid', status: ModuleStateStatus.active)` → `_flushPending` (line 137) dispatches with the captured `T1`, not `T2`.

  Because `_originWallClock` is set at step 2 (start), `_wireTimestamp(T1)` resolves to `originWallClockMs + T1`, so the timestamp assertion holds.
  Test cases:
  - `should flush the pending instruction with the offsetMs captured at instruction time (T1), not the stopwatch value at flush time (T2)`
  - `should flush the pending instruction with timestampMs equal to originWallClockMs + capturedOffsetMs (T1), not recomputed from the flush-time offset`

- [x] **Task 6: Origin wall-clock captured once per lifecycle and wire-timestamp formula**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Same group as Task 2 (or a dedicated `... — wire timestamp` group). Use the clock spy from Task 1. Start a session and dispatch several instructions across phase changes within the same lifecycle (no reset between them).
  Test cases:
  - `should call the injected clock exactly once across a single started lifecycle even when multiple instructions are dispatched`
  - `should compute each instruction's timestampMs as originWallClockMs + that instruction's offsetMs`
  - `should re-capture the origin wall-clock (clock called again) on the next start after reset`
