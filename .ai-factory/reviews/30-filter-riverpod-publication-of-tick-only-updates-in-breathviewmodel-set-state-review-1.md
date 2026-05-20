# Code Review: 30-filter-riverpod-publication-of-tick-only-updates

**Plan:** `.ai-factory/plans/30-filter-riverpod-publication-of-tick-only-updates-in-breathviewmodel-set-state.md`
**Diff scope (code):**
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` — new `equalsIgnoringTickFields(other)` method.
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — `set state` override now gates `super.state = value` through the helper while always firing `_stateController.add(value)`.
**Surrounding files read in full:** `BreathSessionViewModel.dart`, `BreathSessionState.dart`, `BreathSessionScreen.dart` (relevant ranges), `BreathSoundCoordinator.dart`, `BreathAnimationCoordinator.dart`, `OrbAnimationCoordinator.dart`, `BreathModuleStateChannel.dart`, `breath_session_star_toggle_test.dart`, `lib/BreathModule/BreathModule.dart`.
**Risk:** 🟢 Low.

---

## Correctness walk-through

### Filter semantics
`set state` now reads `super.state` (the last *published* state, possibly stale on `remainingTicks` / `currentIntervalMs`) and compares the incoming `value` via `equalsIgnoringTickFields`. The comparison ignores the two cadence fields by design, so previous-stale-tick-data on `super.state` is irrelevant to the decision. All other fields are compared by `==`; `timelineSteps` is compared by `identical(...)`, which is the right choice given task 28 establishes by-replacement mutation as the invariant. The helper's doc comment ties that invariant to the optimization and explicitly warns against a `listEquals` refactor — good forward defense.

### `_onEngineState` reads of `state`
`_onEngineState` reads `state.loadState`, `state.timelineSteps`, `state.isStarred`, `state.canStar`, `state.tickSource` from the (now possibly filter-stale) `super.state`. None of those are tick-cadence fields, and all of them are only mutated through `set state` calls that produce a structural difference (e.g. `_setupEngine` switches `loadState` from `loading` → `ready`, swaps `timelineSteps` identity, and refreshes `isStarred` / `canStar` / `tickSource` from the DTO; `toggleStar` flips `isStarred`). Structural mutations always publish through Riverpod, so the values reread here remain consistent. ✓

### `currentState` getter
`viewModel.currentState` returns the same `super.state`. The only call site is `BreathSoundCoordinator._initAudio` line 109: `_onStateChanged(viewModel.currentState)` runs once after the listener is attached, before any ticks have arrived — at that moment `super.state` was just published by `_setupEngine` and is fresh. After that, all `_onStateChanged` invocations come from the raw `viewModel.listen(...)` subscription, which the filter explicitly preserves. No external (`lib/`) consumer reads `BreathViewModel.currentState`. ✓

### Raw-stream consumers
- `BreathAnimationCoordinator._onStateChanged` reads `state.remainingTicks` and `state.currentIntervalMs` only from the stream-callback argument, not via getter. ✓
- `OrbAnimationCoordinator` subscribes via `viewModel.listen(_onStateChanged)`. ✓
- `BreathSoundCoordinator._onStateChanged` reads `state.currentIntervalMs`, `state.phase`, `state.status`, `state.tickSource` from the stream-callback argument. ✓
- `BreathModuleStateChannel._onState` / `_handleInstruction` reads `state.currentIntervalMs` from the stream-callback argument and forwards it via `_instructionStream.sendSample(...)`. ✓ The plan's verification note saying the channel "does not depend on `currentIntervalMs`" is technically misleading (it does read the field), but the supporting conclusion is correct — the channel subscribes via the raw stream, which always ticks. Not a code defect; only a minor inaccuracy in the plan's prose, already flagged in plan-review-2.

### Riverpod-watched paths in `BreathSessionScreen`
The screen's `ref.watch(breathViewModelProvider)` consumers read `state.loadState`, `state.timelineSteps`, `state.activeStepId`, `state.status`, `state.canStar`, `state.isStarred`. `_buildControlButton` reads `state.status` and `state.loadState`. None of these are tick-cadence fields, so filter-suppressed publications cannot make the screen render stale UI. The active-row countdown is wired to `remainingTicksNotifier` via `ValueListenableBuilder` (tasks 26/27), which is driven by `_remainingTicks.value = engineState.remainingTicks` inside `_onEngineState` — independent of the Riverpod publication path. ✓

### `toggleStar`
Optimistic write `state = state.copyWith(isStarred: newStarred)` differs in `isStarred` from `super.state` → filter publishes. Success write `state = state.copyWith(isStarred: dto.isStarred)`: if it matches the already-published value the filter skips (no extra rebuild — fine, listeners already saw the structural state). Failure rollback `state = state.copyWith(isStarred: !newStarred)` differs → filter publishes. All three test cases in `breath_session_star_toggle_test.dart` assert `vm.state.isStarred`, which is `super.state.isStarred`; that value is correctly maintained by the publication path. ✓

### First publication after `build()`
`_setupEngine` is the first call to `set state` post-`build()`. `super.state` is `BreathSessionState.initial()` (`loadState: loading`); the new value has `loadState: ready` → filter publishes. The "safe to read `super.state` inside setter" maintainer note is reflected verbatim in the docstring above the override. ✓

### Engine restart via `observeSession`
A session update triggers `_setupEngine(dto)` again, which builds a *new* `timelineSteps` list via `_buildTimelineSteps(dto)`. `identical(old.timelineSteps, new.timelineSteps)` → `false` → filter publishes. The screen re-renders the timeline with the new list. ✓

---

## Findings

### Blocking

None.

### Non-blocking observations

1. **Plan-prose inaccuracy about `BreathModuleStateChannel`** — the plan says the channel "does not depend on `currentIntervalMs`"; it actually reads the field at line 100 and forwards it. The conclusion that behavior is unchanged still holds because it subscribes via the raw stream. Cosmetic; the implementation is unaffected.

2. **Forward-defense gap (informational)** — a future contributor introducing `ref.watch(breathViewModelProvider.select((s) => s.remainingTicks))` or `… s.currentIntervalMs` would see stale values, since the filter intentionally suppresses publication for those fields. The doc comments on `equalsIgnoringTickFields` and on the setter call out the dual-channel design clearly enough that this should be discoverable; no further guard recommended given the alternatives (e.g. throwing on such access) would be heavier than the risk.

3. **Helper placement** — task 1 specified "directly after `copyWith`"; the implementation places it directly *before* `copyWith`. Functionally identical; no objection. Mention only because it deviates from the literal task wording.

---

## Verification suggestions (out of scope for code review, but worth running)

- `flutter analyze` on `packages/breath_module` — verifies no lint warnings about the new method.
- Existing star-toggle test (`breath_session_star_toggle_test.dart`) — should pass unchanged.
- Manual: run on the breath session screen and confirm via devtools that `BreathSessionScreen.build` no longer fires per second; the active timeline row's countdown still ticks (via `remainingTicksNotifier`).

---

## Verdict

The implementation matches the plan, the filter delivers the intended optimization (Riverpod publication is now gated, raw stream cadence is preserved), and the surrounding code's reads of `state` / `currentState` remain correct under filter-induced staleness on tick-cadence fields. No code-level defects found.

REVIEW_PASS
