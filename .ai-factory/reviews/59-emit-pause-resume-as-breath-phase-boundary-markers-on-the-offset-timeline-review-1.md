# Code Review: Emit pause/resume as `breath_phase` boundary markers on the offset timeline

**Reviewed change:** `lib/BreathModule/Core/BreathModuleStateChannel.dart` (single file)
**Scope:** Tasks 1–3 of the plan. Verified against the full file, not just the diff.

## Summary

The implementation matches the plan precisely and is correct. The two new emissions are placed in the right branches, the offset axis stays continuous through pause, and the explicit `_previousPhase`/`_previousExerciseIndex` set on resume prevents a double-emit. No migrations, proto, or DTO changes are involved (reuses `instructionType: 'breath_phase'` and the free-form `data` map). No blocking issues found.

## Correctness analysis

- **No double-emit on resume.** `_handleLifecycle` (resume branch, lines 86–90) emits the marker, then sets `_previousPhase = state.phase` / `_previousExerciseIndex = state.exerciseIndex`. The subsequent `_handleInstruction(state)` call in the same `_onState` pass computes `phaseChanged == false` (lines 113–115) and returns early. The marker is emitted exactly once. The trailing assignments in `_onState` (lines 51–53) are idempotent.
- **Single emit on pause.** In the `wasActive && status == pause` branch, `_handleInstruction` early-returns because `isActive` is false (line 111), so the `'pause'` marker (line 96) is the only emission on that tick. Correct.
- **Continuous offset timeline.** `_stopwatch` is not stopped on pause — line 95 calls only `_channel.pause()`. It keeps running through the paused interval (reset only in `reset()` / session start). So `pauseOffset = _stopwatch.elapsedMilliseconds` at pause and the larger value at resume correctly bracket the real wall-clock pause duration — the band mind_web needs.
- **Phase advance across pause is handled.** If the active phase differs at resume from the phase at pause, the resume branch emits the *current* `state.phase.name` at the resume offset and updates `_previousPhase`, so the next natural phase change still diffs and is not swallowed.
- **Two-axis design preserved.** `_channel.pause()` / `_channel.unpause()` (lifecycle / server PAUSED axis) are untouched; the instruction-stream markers are additive on the offset axis. Matches the plan's guard.
- **`tickCount` argument consistency.** The resume emit passes `state.currentPhaseTotalDuration` as the `tickCount` parameter, mirroring the existing `_handleInstruction` call (line 123). The pause emit passes `0`, as specified. This `currentPhaseTotalDuration`→`tickCount` mapping is a pre-existing convention in this file, not introduced here.
- **Imports / types.** No new imports needed — `BreathSessionState`, `BreathPhase`, `BreathSessionStatus` are already imported (line 8); `state.phase`, `.exerciseIndex`, `.currentPhaseTotalDuration` are already referenced elsewhere in the file.

## Non-blocking observations

1. **Dropped (not queued) pause marker before `moduleSessionId` arrives.** `_emitMarker` drops the marker and logs when `_moduleSessionId == null`, whereas `_handleInstruction` queues into `_pendingInstruction`. The plan accepts this because pause/resume occur after session start once the id is established. The residual edge case: a pause within the brief window between `_channel.start()` and the server returning a `moduleSessionId` drops the `'pause'` marker, while a later resume marker (id now present) still lands — leaving mind_web with a resume boundary and no opening pause boundary. Non-fatal (no crash; an unbalanced/missing band). mind_web rendering should tolerate an unmatched resume marker. Matches the plan-review's flagged observation.

2. **Resume branch has no `_ended` guard (pre-existing).** The resume `else` arm (lines 85–91) is not wrapped in `_started && !_ended` like the pause and complete branches. The new `_emitMarker` therefore inherits the same lack of an `_ended` guard as the pre-existing `_channel.unpause()` call. In practice the flow resets before going active again after completion, so this is not reachable in normal use; it is not a regression introduced by this change. No action required.

3. **Cross-project deploy order (already flagged in the plan).** End-to-end function depends on `mind_api` note 49 shipping first (instruction pause-guard removed); otherwise the resume marker is rejected with `SESSION_PAUSED` because on resume the server is still `isPaused=true`. This is a deploy-sequencing dependency, not a code defect. mind_web also needs a `phase='pause'` color (separate repo) — absent it, the band renders unstyled, not broken.

## Conclusion

The code is correct, minimal, and faithful to the plan. Branch placement, emission counts, the double-emit guard, and the continuous offset axis all check out. The only items are non-blocking observations already anticipated by the plan and plan-review.

REVIEW_PASS
