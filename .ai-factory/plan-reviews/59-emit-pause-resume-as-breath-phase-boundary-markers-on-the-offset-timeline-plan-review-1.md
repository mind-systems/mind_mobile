# Plan Review: Emit pause/resume as `breath_phase` boundary markers on the offset timeline

**Plan file:** `59-emit-pause-resume-as-breath-phase-boundary-markers-on-the-offset-timeline.md`
**Target:** `lib/BreathModule/Core/BreathModuleStateChannel.dart` (single file)
**Risk Level:** 🟢 Low

## Verification against the codebase

Every concrete claim in the plan was checked against the source and holds:

- `_handleLifecycle(BreathSessionStatus status)` exists (line 56) and is called from `_onState` at line 49 with `state.status` — Task 1's signature widening to `_handleLifecycle(BreathSessionState state)` and deriving `status` locally is accurate.
- `_stopwatch` (line 23), `_wireTimestamp` (line 119), and `_moduleSessionId` (line 20) all exist as named.
- `BreathModuleInstructionStream.sendSample(String sessionId, String phase, int tickCount, int offsetMs, int timestampMs)` matches the plan's stated signature exactly (`BreathModuleInstructionStream.dart:10`). No signature change is needed, and `data.phase` is a free-form `String` (line 16), so `'pause'` is valid without touching the `BreathPhase` enum.
- The pause branch (`wasActive && status == BreathSessionStatus.pause`, lines 79–83) and the resume `else` arm (`wasPaused && isActive`, `_started` already true, lines 75–78) are exactly where Tasks 2 and 3 place their emits.
- `BreathSessionState.phase.name`, `.currentPhaseTotalDuration`, `.exerciseIndex`, `.status`, `.loadState` are all already referenced in the file, so no new imports are required (`BreathSessionState` is already imported on line 8).

## Correctness analysis

- **No double-emit on resume.** Task 3 sets `_previousPhase = state.phase` / `_previousExerciseIndex = state.exerciseIndex` *before* the trailing `_handleInstruction(state)` runs, forcing `phaseChanged == false` (line 99–101), so the explicit resume marker is not duplicated. This is correct, and the explicit set does real defensive work (not merely "harmless"): even if the paused tick had left `_previousPhase` in an unexpected state, the explicit assignment guarantees no double emit. Lines 51–53 re-assign the same values afterward — idempotent.
- **No emit on the pause transition path.** In the pause branch, `_handleInstruction` early-returns because `isActive` is false (line 97), so the `'pause'` marker is the only emission. Correct.
- **Continuous offset timeline holds.** `_stopwatch` is *not* stopped on pause (line 82 only calls `_channel.pause()`); it keeps running through the paused interval and is only reset on `reset()`/session start. So `pauseOffset = _stopwatch.elapsedMilliseconds` at pause and the larger value at resume bracket the real wall-clock pause duration — exactly the band mind_web needs.
- **Lifecycle axis preserved.** Tasks 2/3 keep `_channel.pause()` / `_channel.unpause()` intact and add the instruction-stream markers as a *separate* axis. Matches the existing two-axis design.

## Context Gates

### Architecture (`.ai-factory/ARCHITECTURE.md`) — PASS
The change is confined to the domain/infrastructure state-channel that bridges breath state → gRPC instruction stream. It introduces no new cross-layer dependency, no domain-model leak into the module, and no new import. Boundary rules are respected.

### Rules (`.ai-factory/RULES.md`) — PASS
The three project rules concern stateless module **Services**, not adding module state to `App.dart`, and constructor injection. `BreathModuleStateChannel` is none of these — it is an existing stateful channel with established lifecycle, and the plan adds no new external wiring or `App.dart` state. No violation.

### Roadmap (`.ai-factory/ROADMAP.md`) — WARN
This is feature-shaped work (a new visualization contract consumed by mind_web) but the plan references no ROADMAP milestone. Non-blocking, but consider adding a roadmap line for traceability with the corresponding `mind_api` note 49 / mind_web work.

## Non-blocking observations

1. **Dropped pause marker → unbalanced markers on web (edge case).** `_emitMarker` drops (rather than queues) when `_moduleSessionId` is still `null`, unlike `_handleInstruction`, which queues a `_pendingInstruction`. The plan's justification — pause/resume occur only after session start once the id is established — is true for the common case. The residual edge: a user who pauses within the brief window between `_channel.start()` and the server returning a `moduleSessionId` would have the `'pause'` marker dropped while a later resume marker (id now present) still succeeds, leaving mind_web with a resume boundary and no opening pause boundary. This is non-fatal (no crash, just a missing/unbalanced band) and acceptable for scope, but mind_web's rendering should tolerate an unmatched resume marker. Worth a one-line note for the web consumer.

2. **Cross-project deploy order is correctly flagged.** The plan's dependency note (server must ship `mind_api` note 49 first, removing the instruction pause-guard, else the resume/pause markers are rejected with `SESSION_PAUSED` because the instruction stream and lifecycle channel are independent and racy). This is the right call and removes the otherwise-real race between the `unpause()`/`pause()` lifecycle event and the marker on the instruction stream. Ensure the deploy actually lands before this ships end-to-end.

3. **No migration / proto / DTO changes needed** — confirmed. Reuses `instructionType: 'breath_phase'` and the free-form `data` map; nothing in Drift or proto is touched.

## Conclusion

The plan is accurate, minimal, and architecturally sound. File paths, method signatures, branch locations, and field names all verified against source. The two emissions are correctly placed and proven not to double-emit. The only items are a WARN on missing roadmap linkage and two non-blocking observations (web-side tolerance of an unbalanced marker, and the already-flagged deploy ordering).

PLAN_REVIEW_PASS
