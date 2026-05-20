# Code Review: Stop reallocating `timelineSteps` per tick in `BreathViewModel._onEngineState`

**Plan file:** `.ai-factory/plans/28-stop-reallocating-timelinesteps-per-tick-in-breathviewmodel-onenginestate.md`
**Risk Level:** 🟢 Low

## Scope of changes

Two files modified (matching the plan exactly):

- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — `_onEngineState` no longer rebuilds `timelineSteps`; reuses `state.timelineSteps` by reference. `_remainingTicks.value = engineState.remainingTicks;` retained.
- `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart` — `_buildList` computes `activeIndex` once; `itemBuilder` derives `isCompleted`; `_TimelineItem` gains a `required this.isCompleted` field and renders `'0'` for completed rows in the inactive `Text` branch.

No new tests (plan opted out). No other files touched.

## Correctness

### `BreathSessionViewModel.dart` (lines 139–162)

- Deleted block correctly removes `previousActiveId`, `newActiveId`, `remaining`, the `updatedSteps` declaration, and the `if (newActiveId != null) { … }` rebuild. ✓
- `_remainingTicks.value = engineState.remainingTicks;` placed before the state assignment — same ordering relative to `state = …` as before, so listener-notification timing is unchanged. ✓
- `timelineSteps: state.timelineSteps` reuses the same `List<TimelineStep>` reference that `_setupEngine` installed on the latest session setup. Reference equality is preserved across every tick within a session. ✓
- Full constructor preserved — `copyWith` is still unsuitable because of the nullable fields (`resetReason`, `currentExerciseShape`, `nextExerciseShape`). ✓
- `_setupEngine` still rebuilds `timelineSteps` from scratch on restart/observe (lines 113–137), so a session edit or restart correctly publishes a fresh list. No stale-list pinning across sessions. ✓
- `TimelineStep` import retained (used by `_buildTimelineSteps`). ✓

### `BreathTimelineWidget.dart` (lines 131–165, 179–199, 235)

- `activeIndex` is computed once per `_buildList` invocation (line 132–134). When `activeStepId == null`, `activeIndex = -1` (rather than calling `indexWhere` with a null target), which short-circuits the comparison cleanly. ✓
- `isCompleted = activeIndex >= 0 && index < activeIndex` correctly handles all states:
  - Pre-start (`activeStepId == null` or no match) → `activeIndex < 0` → all rows `isCompleted = false` → all show original duration. Matches old "no rewrite yet" behavior. ✓
  - Mid-session → rows before active render `'0'`, active row renders the live `ValueListenableBuilder<int>`, rows after render original duration. Matches the old per-tick rewrite. ✓
  - Pause / complete → state-machine preserves `activeStepId`, so completed rows continue to render `'0'`. Matches today. ✓
- Separator rows short-circuit at line 146–148 before `_TimelineItem` is constructed, so the new `isCompleted` field never affects separator rendering. ✓
- `_TimelineItem` correctly declares `required this.isCompleted` (line 195) and the only consumer is the inactive `Text` branch at line 235 — `Text(isCompleted ? '0' : '${step.duration ?? 0}', style: textStyle)`. The active `ValueListenableBuilder<int>` branch is unchanged. ✓

### Subtle improvement — pre-existing widget-side check now no-ops cleanly

`BreathTimelineWidgetState.didUpdateWidget` rebuilds the GlobalKey map when `widget.steps != oldWidget.steps` (line 46). Previously, `state.timelineSteps` was a fresh list every tick → identity check failed → `_updateKeys()` ran per tick. After this change, `state.timelineSteps` is reference-equal across ticks within a session → `_updateKeys()` is skipped per tick (still runs once per session/restart). Small additional perf win, no behavior change.

### Slightly more robust than the prior implementation

The old code only rewrote the **immediately previous** active step to `duration: 0`. If the engine ever jumped over a step (e.g. transitioned from step N → N+2 between ticks), the skipped step N+1 would have continued to display its original duration. The new derivation marks **all rows with `index < activeIndex`** as completed, so any skipped step displays `'0'` correctly. This is a strict robustness improvement; in normal sequential playback the visible outcome is identical to today.

## Runtime risks

- **Stream-listener ordering on `_setupEngine`:** `_stateMachine!.stateStream.listen(_onEngineState)` is set up at line 111 *before* the initial `state = BreathSessionState(...)` at line 118. If the state machine emitted synchronously on subscribe, `_onEngineState` would read `state.timelineSteps` from the *previous* state (initial empty list on first run, prior session's list on restart). However, this was true before the change as well (the old code also read `state.timelineSteps`), and `Stream.listen` on a `StreamController.broadcast` does not deliver synchronously. No regression, no new failure mode.
- **Active-step transition frame:** when `engineState.activeStepId` changes, `_remainingTicks.value` is set to the new step's full duration before `state` is updated. The currently-active `ValueListenableBuilder` (still bound to the old row in the current frame's widget tree) would rebuild with the new value. Both updates schedule rebuilds in the same microtask, so Flutter coalesces them in the next frame — by the time the frame paints, `state.activeStepId` is the new id and the listenable is bound to the new row. This matches the prior ordering exactly. No visible glitch.
- **Type safety / null safety:** `widget.activeStepId` is `String?`; `step.id` is `String?`. The `indexWhere` predicate `(s) => s.id == widget.activeStepId` evaluates `null == String?` cleanly. Separators have `step.id == null` but `widget.activeStepId` is non-null when present (guarded by the outer ternary), so separators never spuriously match.
- **State publication frequency:** as noted in plan-review-2, this change only removes the O(N) `.map().toList()` per tick; `state = BreathSessionState(...)` still fires every tick, so screen-level rebuilds still happen at 1 Hz. That's a follow-up milestone, not a regression here.

## Plan adherence

Both tasks (Phase 1 + Phase 2) implemented verbatim per the plan. No scope creep, no unrelated edits. The two checkboxes are marked `[x]` and the diff matches each bullet.

## Verdict

The implementation is correct, surgical, and faithfully matches the plan. The UX is preserved through a UI-side derivation that is strictly more robust than the prior per-tick mutation. The change removes the documented O(N) per-tick allocation in `_onEngineState` without behavior regression.

REVIEW_PASS
