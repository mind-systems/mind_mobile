# Code Review: Stamp breath instructions on a monotonic offset axis (`{phase, tickCount, offsetMs}`, drop `durationMs`)

**Plan:** `.ai-factory/plans/56-stamp-breath-instructions-on-a-monotonic-offset-axis-payload-phase-tickcount-offsetms-drop-durationms.md`
**Files reviewed (in full):**
- `lib/BreathModule/Core/BreathModuleInstructionStream.dart`
- `lib/BreathModule/Core/BreathModuleStateChannel.dart`
- `test/BreathModule/breath_module_state_channel_test.dart`
- Surrounding context: `lib/Core/Grpc/InstructionSample.dart`, `lib/Core/Grpc/ModuleInstructionStream.dart`

**Verdict:** No bugs, security issues, or correctness problems found. The implementation matches the plan exactly and the test suite was updated to compile and assert the new contract.

---

## What was verified

### Payload contract (`BreathModuleInstructionStream.sendSample`)
- Signature is the agreed 5-arg form `(sessionId, phase, tickCount, offsetMs, timestampMs)`. `data = {'phase', 'tickCount', 'offsetMs'}`; `durationMs` is gone; `moduleId`/`instructionType` unchanged; wire `timestamp` is the caller-supplied reconstructed wall-clock. Correct.
- Type safety on the wire: `tickCount`/`offsetMs` are `int`, serialized by `ModuleInstructionStream._valueFrom` via `Value(numberValue: v.toDouble())`; `timestamp` via `Int64(sample.timestamp)`. All three pass through `Struct`/`StreamSample` without error. No proto edit needed — confirmed `data` is a free-form `Map<String, dynamic>` → `google.protobuf.Struct`.

### Monotonic origin (`BreathModuleStateChannel`)
- `_stopwatch..reset()..start()` and `_originWallClock = DateTime.now()` are set inside the `!_started` start branch, immediately before `_channel.start(...)` and `_started = true`. Because `_handleLifecycle` runs before `_handleInstruction` in the same `_onState` pass and only synchronous work happens between them, the first active phase (`rest`, emitted synchronously by `resume()`) reads `offsetMs ≈ 0`. Origin behavior is correct.
- `offsetMs = _stopwatch.elapsedMilliseconds` is captured at phase-change time; parked into `_pendingInstruction (state, offsetMs)`; `_flushPending` reuses `pending.offsetMs`. The readiness gate and parking logic are untouched, as required — a parked sample keeps its capture-time offset and reconstructs the same wire timestamp on flush.
- `_wireTimestamp(offsetMs) = originWallClock.millisecondsSinceEpoch + offsetMs` is monotonic with `offsetMs`, so `ModuleInstructionStream._drainOutbox`'s `timestamp` sort order is preserved (no regression versus the old `DateTime.now()` stamp).
- `reset()` stops/resets the stopwatch and nulls `_originWallClock` alongside the existing state reset; a subsequent active emission re-enters the start branch and re-initializes both. The `?? DateTime.now()` fallback in `_wireTimestamp` is unreachable under current control flow (dispatch requires `_started`, which guarantees `_originWallClock != null`) — harmless defensive code, as the plan notes.
- Stopwatch intentionally keeps running across pause (never stopped on the pause branch), matching the old `DateTime.now()` behavior and the continuous-axis contract. Confirmed not a regression.

### Test suite
- `_FakeInstructionStream.sendSample` updated to the 5-arg signature, so the `@override` is valid again — the whole file compiles. Captured tuple kept as `(sessionId, phase, tickCount)`; `offsetMs`/`timestampMs` are deliberately not captured, so no `Stopwatch`-driven non-determinism leaks into assertions (cleaner than the relaxed-assertion fallback the plan allowed).
- Every previously interval-derived assertion now sets a distinct `currentPhaseTotalDuration` and asserts that exact tick count (3/4/5/6/8/9/10/11). Traced the first dispatch test end-to-end (`pause(inhale)` → `breath(exhale, cpd=3)` → start branch nulls `_previousPhase` → `phaseChanged` true → `('sid','exhale',3)`); correct.
- The obsolete "currentIntervalMs == -1 passes through" test was repurposed to assert `tickCount` comes from `currentPhaseTotalDuration` regardless of `currentIntervalMs: -1` (`('sid','exhale',7)`), proving the `-1` poisoning is gone.
- No stale references to `durationMs`, the old 4-arg signature, or the old `ts` record field remain anywhere in the repo (grep-verified). The only `sendSample` consumers are the channel and this test.

---

## Non-blocking observation

- The `offsetMs` and reconstructed-`timestamp` arguments are not asserted by any test (the fake drops them). The core new behavior — first phase at `offsetMs ≈ 0`, monotonic non-negative offsets, `timestamp == originWallClock + offsetMs` — therefore has no direct coverage. This is consistent with the plan's "no new test files" setting and the non-determinism avoidance, so it is acceptable; flagging only as a future coverage gap should offset semantics regress.

REVIEW_PASS
