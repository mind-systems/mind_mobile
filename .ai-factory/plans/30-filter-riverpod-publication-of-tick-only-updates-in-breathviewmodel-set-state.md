# Plan: Filter Riverpod publication of tick-only updates in `BreathViewModel.set state`

## Context
Tick-only state changes (`remainingTicks` advancing once per second, and `currentIntervalMs` being refreshed with the measured wall-clock delta on every tick) currently call `super.state = value`, which forces every Riverpod consumer of `breathViewModelProvider` to rebuild even though no visible structural field changed. The fix: keep the raw `_stateController.add(value)` channel firing every tick (animation/sound/state-channel coordinators depend on it), but skip `super.state = value` when the incoming value differs from the current `state` only in tick-cadence fields (`remainingTicks`, `currentIntervalMs`). See `.ai-factory/notes/11-breath-session-tick-render-scope.md`.

`currentIntervalMs` must be excluded too: it is supplied by `TickData` on every tick (`BreathSessionStateMachine` lines 276/313/341/371) and varies by milliseconds under the clock source and tens-to-hundreds of ms under heart-rate, so leaving it in the equality check would make the filter a no-op. Grep confirms only `BreathAnimationCoordinator` and `BreathSoundCoordinator` read it, and both subscribe via the raw stream — no Riverpod consumer of `currentIntervalMs` exists.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Tick-equality helper + filtered publication

- [x] **Task 1: Add an `equalsIgnoringTickFields` helper on `BreathSessionState`**
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  Add an instance method `bool equalsIgnoringTickFields(BreathSessionState other)` on `BreathSessionState` that returns `true` iff every field except the two tick-cadence fields (`remainingTicks`, `currentIntervalMs`) is equal to `other`. Compare the following by `==`: `loadState`, `status`, `phase`, `exerciseIndex`, `activeStepId`, `isStarred`, `canStar`, `resetReason`, `totalPhases`, `currentPhaseIndex`, `currentPhaseTotalDuration`, `currentExerciseShape`, `nextExerciseShape`, `tickSource`. Compare `timelineSteps` by `identical(...)` — the list is mutated by-replacement only (stable across ticks per task 28, swapped in `_setupEngine` on restart), so identity match is the cheap correct check. Do NOT include `remainingTicks` or `currentIntervalMs` in the comparison. Place the method directly after `copyWith`. Keep it pure Dart, no Flutter imports.
  Add a doc comment on the method listing the two excluded fields and explaining why (cadence-only fields published on the raw stream, not relevant to Riverpod consumers) and noting why `timelineSteps` uses `identical(...)` rather than `listEquals` ("list is mutated by-replacement only on restart per task 28; a `listEquals` refactor would silently break the optimization").

- [x] **Task 2: Filter the Riverpod publication inside `set state` override** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Replace the body of the `set state` override (currently lines ~79–84). New behavior:
  1. Read the current state via `super.state` before assigning.
  2. If `value.equalsIgnoringTickFields(super.state)` is `true`, skip `super.state = value` so Riverpod listeners do not rebuild on pure tick-cadence updates.
  3. Otherwise (structural change), call `super.state = value` as before.
  4. In both branches, always call `_stateController.add(value)` when `!_stateController.isClosed`, so raw-stream consumers (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`, `BreathSoundCoordinator`, `BreathModuleStateChannel`) keep receiving every tick.

  Note on reading "current state": `set state` is only invoked after `build()` completes (via `_setupEngine`, `_onEngineState`, `toggleStar`, and the error branch in `initState`), so `super.state` is safe to read inside the setter. Keep that exact note in the comment above the override — the next maintainer will wonder.

  Add a brief comment above the override pointing to `.ai-factory/notes/11-breath-session-tick-render-scope.md` and explaining the dual-channel intent: the raw stream emits every update (preserving animation/sound coordinator cadence); Riverpod publication is filtered so structural changes flow through `super.state = value` but updates that differ only in tick-cadence fields (`remainingTicks`, `currentIntervalMs`) do not trigger Riverpod listener rebuilds.

- [x] **Task 3: Verify behavior on the screen consumers** (depends on Task 2)
  Files: (read-only verification, no edits expected)
  Walk the call sites once more to confirm nothing regresses:
  - `BreathSessionScreen` — should no longer rebuild on per-second tick updates; structural updates (`status`, `phase`, `activeStepId`, `timelineSteps` identity change on restart, `isStarred`, `tickSource`, etc.) still publish. The screen reads `state.status`, `state.canStar`, `state.loadState`, `state.timelineSteps`, `state.activeStepId` — none are tick-cadence fields, so the filter is safe. Re-confirm that `_buildControlButton(state, ...)` does not inspect `remainingTicks` or `currentIntervalMs`.
  - `BreathAnimationCoordinator` and `OrbAnimationCoordinator` — receive every tick via `viewModel.listen(...)` on `_stateController.stream`; `setRemainingPhaseTicks` and `setIntervalMs` cadence is preserved.
  - `BreathSoundCoordinator` — same raw-stream subscription; debug-print cadence preserved.
  - `BreathModuleStateChannel` — reads from `_stateController.stream`; it does not depend on `remainingTicks` or `currentIntervalMs`, so behavior is unchanged.
  - `_TimelineItem` countdown — already moved off `state` onto `remainingTicksNotifier` (tasks 26/27), so it keeps ticking via the `ValueNotifier` channel independent of Riverpod publication.

  If any consumer is found that reads `remainingTicks` or `currentIntervalMs` via `ref.watch(breathViewModelProvider)` (rather than via the raw stream or `remainingTicksNotifier`), flag it — that would be the one place that needs migration to the notifier channel.

  Verify exit criteria by running `flutter run --flavor dev -t lib/main_dev.dart` on the breath session screen and confirming via devtools that `BreathSessionScreen.build` no longer fires once per second; structural transitions (start/pause/phase change/complete) still rebuild as expected.
