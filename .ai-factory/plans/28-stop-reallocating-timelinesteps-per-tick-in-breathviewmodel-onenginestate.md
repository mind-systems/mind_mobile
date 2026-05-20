# Plan: Stop reallocating `timelineSteps` per tick in `BreathViewModel._onEngineState`

## Context
Removes the per-tick `.map().toList()` rebuild of `timelineSteps` inside `_onEngineState`. The active step's countdown is already published via `remainingTicksNotifier` (previous milestone) and consumed by the active `_TimelineItem` via `ValueListenableBuilder`, so the steps list can stay structurally stable for the entire session.

### Addressing the review (plan-review-1)
The current per-tick rebuild also rewrites the **previously active** step with `duration: 0` so completed rows display `0` instead of their original duration (e.g. `4`). Freezing `state.timelineSteps` removes this affordance — completed rows would render their original duration after the change.

**Decision:** preserve today's UX (completed rows display `0`) via a UI-side derivation, not via list mutation. The active-step index is computed once per `BreathTimelineWidget.build`, which only re-runs on structural state changes — not per tick — so the cost is amortized across an entire phase. This is option (2) from the review: "add a tiny step to preserve the completed-→-0 affordance without per-tick reallocation."

The broader screen-rebuild fix (publication filter / `ref.watch(...select(...))` in `BreathSessionScreen`) is explicitly out of scope here — it will be a separate follow-up milestone. This plan only removes the O(N) per-tick allocation in `_onEngineState`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Drop the per-tick step rebuild

- [x] **Task 1: Remove `.map().toList()` rebuild of `timelineSteps` in `_onEngineState`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  In `_onEngineState` (currently lines 139–178):
  - Delete the local variables `previousActiveId`, `newActiveId`, `remaining`, the `List<TimelineStep> updatedSteps = state.timelineSteps;` declaration, and the entire `if (newActiveId != null) { … }` rebuild block (current lines 140–154 inclusive).
  - Replace the `_remainingTicks.value = remaining;` assignment with `_remainingTicks.value = engineState.remainingTicks;` so the notifier still receives every tick verbatim.
  - In the subsequent `state = BreathSessionState(...)` constructor, change `timelineSteps: updatedSteps` to `timelineSteps: state.timelineSteps` so the list reference built once in `_setupEngine` is reused verbatim for the entire session. All other constructor arguments stay as today.
  - Keep the existing `TimelineStep` import — `_buildTimelineSteps` still references the type.
  - Keep the full-constructor pattern (do not switch to `copyWith`) — `copyWith` cannot clear nullable fields like `resetReason`, `currentExerciseShape`, `nextExerciseShape` when the engine emits `null`.
  After the change, `_onEngineState` performs zero list allocations per tick. The active step's countdown UI is driven exclusively by `remainingTicksNotifier`, and `BreathSessionState.remainingTicks` keeps mirroring the engine for the raw-stream consumers (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`, `BreathSoundCoordinator`, `BreathModuleStateChannel`). `_setupEngine` continues to rebuild `timelineSteps` from scratch on session start/observe/restart, so frozen-list reuse does not pin a stale list across restarts.

### Phase 2: Preserve the "completed row → 0" affordance in the UI

- [x] **Task 2: Derive `isCompleted` in `BreathTimelineWidget` and render `0` for completed rows**
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  Goal: keep today's visual — completed steps show `0`, upcoming steps show their original duration, the active step shows the live countdown — without touching `timelineSteps` per tick.
  Changes:
  - In `_buildList(bool isPausedOrComplete)`, before the `return ListView.builder(...)`, compute once: `final activeIndex = widget.activeStepId == null ? -1 : widget.steps.indexWhere((s) => s.id == widget.activeStepId);`.
  - Inside `itemBuilder`, after the existing `final isActive = step.id == widget.activeStepId;`, add: `final isCompleted = activeIndex >= 0 && index < activeIndex;`.
  - Pass `isCompleted: isCompleted` to the new `_TimelineItem` constructor parameter (see below).
  - Add a `final bool isCompleted;` field to `_TimelineItem`, a `required this.isCompleted` constructor parameter, and update the inactive `Text` branch (current line 227) from `Text('${step.duration ?? 0}', style: textStyle)` to `Text(isCompleted ? '0' : '${step.duration ?? 0}', style: textStyle)`. The active branch (`if (isActive && remainingTicksListenable != null) ValueListenableBuilder<int>(...)`) is unchanged.
  - Separator rows are unaffected — they short-circuit before `_TimelineItem` is built. No other display logic changes.
