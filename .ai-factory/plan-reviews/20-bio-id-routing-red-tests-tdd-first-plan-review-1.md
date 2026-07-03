## Plan Review Summary

**Plan:** Bio id-routing red tests (TDD-first) — `20-bio-id-routing-red-tests-tdd-first.md`
**Files Reviewed:** plan + specs (notes 17, 23), `BiometricStreamClient.dart`, `ModuleStateChannel.dart`, `BreathModuleStateChannel.dart`, `ModuleInstructionStream.dart`, all three target test files, generated protos, ROADMAP/RULES/ARCHITECTURE gates.
**Risk Level:** 🟢 Low — the plan is accurate and implementable; findings below are advisory, none blocking.

### Context Gates

- **Roadmap (PASS):** ROADMAP.md line 67 (`Bio id-routing red tests (TDD-first)`) matches the plan heading and content point-for-point (bio carries `root.id`; child end does not clear; global reset clears; phase stays child; late `SESSION_NOT_FOUND` swallowed). `Spec:` tag → `notes/23-…`, whose impl target `notes/17-…` is correctly referenced. Line 68 is the note-17 impl milestone this reddens against. Linkage intact.
- **Rules (PASS):** RULES.md rule "all dependencies injected via constructor; let the class manage its own subscription" is satisfied exactly by Task 1's design (`Stream<String?>? rootIdChanges` constructor param + private `_rootIdSub` cancelled in `dispose()`). The "no module state in App.dart" rule is respected — the seam stays unwired here; note 17 does the App.dart wiring.
- **Architecture (PASS):** no boundary violation — the two decoupled id sources (`BiometricStreamClient._currentSessionId` vs `BreathModuleStateChannel._moduleSessionId`) are correctly kept separate; the plan explicitly guards against conflating them.

### Verification of key assumptions (all confirmed against code)

- `ModuleStateChannel.rootIdChanges` exists and is `Stream<String?>` (`ModuleStateChannel.dart:37`) — Task 1's type match is correct.
- Current bio id source is lifecycle-driven: `ModuleSessionStarted/Resumed` set `_currentSessionId`, `Ended/Abandoned` null it + clear the ring (`:88-104`); gate at `:111`; inject at `:215-222`. All four RED/GREEN scenarios in Task 2 are logically sound:
  - **A (bio=root.id):** current tags `'child-A'`, asserts `'root-1'` → RED; note 17 sources root → GREEN. ✔
  - **B (child end no-clear):** current clears on `Ended` → gated no-op, no batch → RED; note 17 keeps id → GREEN. ✔
  - **C (global reset clears):** first "batch under root" step can't happen with the unwired seam → RED; note 17 → GREEN. ✔
  - **D (gate holds):** no-op now and after → guard-GREEN. ✔
- Golden-master `biometric_stream_client_test.dart` harness (`_FakeStub`/`_FakeConnection`/`_FakeResponseStream`, `readyTimeout: 1h`, `injectReady()`) matches what Task 2 copies. Plan's "do not edit it" instruction is correct.
- Task 3's phase-path fakes (`_FakeChannel`, `_FakeInstructionStream.sendSampleCalls`, `_FakeStopwatch`, `_state(...)`) exist and Phase-9 tests already exercise the exact dispatch path; the child id used by the phase path is `moduleState.moduleSessionId` (set at `BreathModuleStateChannel.dart:48`, sent at `:76/:141`), so asserting `sessionId == 'child-breath'` (and `!= 'root-1'`) is valid.
- Task 4's swallow guarantee is real: `ModuleInstructionStream._openStream` handles `StreamResponse_Event.error` by **logging only** (`:142-143`) — no teardown, no `disconnect`/`scheduleReconnect`. So the "no throw, stream stays up" characterization holds.

### Critical Issues

None.

### Notes (non-blocking — worth addressing while implementing)

1. **TDD-first milestone leaves `flutter test` red — state how the pipeline should treat it.**
   Tasks 2's three RED tests are, by design, committed failing until note 17 lands. The plan tells the implementer to "confirm the RED set on first run" but does not say how a downstream green-tests gate (code-review / verify / orchestrator) should treat an intentionally-failing suite. Two clean options: (a) explicitly document that the suite is expected-red between this milestone and note 17 (matching the note-22 precedent the plan cites), or (b) tag the RED tests (e.g. `@Tags(['red'])` / `skip: 'RED until note 17'`) so an unfiltered run stays green and note 17 removes the marker. Recommend the plan pick one so the milestone isn't misread as broken. (Comments alone do not stop `flutter test` from reporting failures.)

2. **Task 2 test C: "replay ring does not accumulate" is not observable via public API.**
   `_replayRing` is private, and `sendBatch`'s gate (`_currentSessionId == null`) returns *before* `_encodeAndAdd`, so nothing can enter the ring when the id is cleared anyway. The observable assertion is just "`stub.callCount` does not increase" (already in the plan). Drop or reframe the ring-accumulation clause to avoid an implementer reaching for a private field or a reflection hack.

3. **Task 4: name the concrete error type and the addError pitfall.**
   The error event is `StateErrorEvent` (imported from `module_state.proto` as `$2`), so the frame is `StreamResponse(error: StateErrorEvent(code: 'SESSION_NOT_FOUND', message: ...))`; `code` is a plain `String`, so the literal is valid. Crucially, this must be pushed as a **data frame** on `responseCtrl.add(...)`, **not** `responseCtrl.addError(...)` — the latter is a transport error that *does* tear the stream down (`:148-155`, and the existing "response stream errors" test asserts `disconnect/scheduleReconnect == 1`). To lock the swallow behaviour, drive `connect → makeReady → responseCtrl.add(error frame) → emit`, then assert the sample still reaches the wire and `disconnectCount == 0 && scheduleReconnectCount == 0`. Spelling this out prevents a false test that characterizes the wrong path.

4. **Task 3 (nit): the marker requires priming `_previousPhase`.**
   As every Phase-9 test does, emit a `paused inhale` before the `running exhale` so the phase actually changes and a marker is emitted (a first `running` emission resets `_previousPhase = null`, which also works). The plan's "drive a running state and a phase change" leaves this implicit; the existing file pattern makes it obvious, but note it so the test isn't a no-op.

### Positive Notes

- Line references in the plan and specs are exact and current (`:86-106`, `:111`, `:215-222`, `BreathModuleStateChannel.dart:47-51/:76`).
- Correctly scopes out `AllSessionsReset` (note 20) and tests "root gone" via `rootIdChanges(null)` — avoids coupling this milestone to an unbuilt event type.
- The seam is genuinely additive/no-op (optional nullable param), so App.dart and all existing tests compile and pass unchanged — the RED set is isolated to the new file.
- Strong emphasis on driving the real stateful clear-condition (not a pass-through double) for test B directly targets the m36 "clears on child end" regression the spec warns about.
- Golden-master file is explicitly protected; new scenarios go in a separate `biometric_stream_id_routing_test.dart`.

PLAN_REVIEW_PASS
