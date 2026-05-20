# Plan Review: 30-filter-riverpod-publication-of-tick-only-updates

**Plan:** `.ai-factory/plans/30-filter-riverpod-publication-of-tick-only-updates-in-breathviewmodel-set-state.md`
**Files Reviewed:** plan + `BreathSessionViewModel.dart`, `BreathSessionState.dart`, `BreathSessionStateMachine.dart`, `BreathSessionScreen.dart`, `BreathAnimationCoordinator.dart`, `BreathSoundCoordinator.dart`, notes 11, `ARCHITECTURE.md`, `RULES.md`.
**Risk Level:** 🔴 High — one bug would silently make the optimization a no-op.

---

## Context Gates

- **ARCHITECTURE.md** — PASS. Changes are scoped to the ViewModel and its state model inside `packages/breath_module/`. No layer boundaries crossed: `set state` override stays inside the module; `equalsIgnoringRemainingTicks` is added to the state model that already lives in the package; no new Flutter / Riverpod imports leak into the domain. The note about "ViewModel is the module boundary" is respected.
- **RULES.md** — PASS. No App.dart edits, no new services, no new streams or subscriptions outside the existing `_stateController` / `ref.onDispose` pattern.
- **ROADMAP.md** — n/a (this is a perf/refactor follow-up to tasks 26/27/28 explicitly referenced in note 11; no roadmap milestone linkage required).

---

## Critical Issues

### 1. `currentIntervalMs` must be excluded from the equality check — otherwise the filter is a no-op

**File:** `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` (Task 1)

Task 1 instructs the helper to compare `currentIntervalMs` by `==`. But `currentIntervalMs` is set to the **measured interval between ticks** on every tick — see `BreathSessionStateMachine.dart` lines 276 (`_onBreathTick`), 313 (`_onRestTick`), 341 (`_startRest`), 371 (`_startNewCycle`):

```dart
currentIntervalMs: intervalMs,  // value supplied by TickData on every tick
```

`intervalMs` is the wall-clock delta between the previous and current tick — under the clock source it has timer jitter (often differs by 1–10 ms), and under the heart-rate source it varies by tens to hundreds of ms each beat. So `value.currentIntervalMs != currentState.currentIntervalMs` on virtually every tick → `equalsIgnoringRemainingTicks` returns `false` → `super.state = value` fires on every tick → **the screen still rebuilds every second**. The whole point of the plan is defeated.

`currentIntervalMs` is also a tick-cadence field consumed only by the raw-stream subscribers — there is no Riverpod consumer of it. Confirmed by grepping `currentIntervalMs` across the package: only `BreathAnimationCoordinator` (line 110–111, `motionEngine.setIntervalMs`) and `BreathSoundCoordinator` (line 73, debug). Both subscribe via `_stateController.stream` / `viewModel.listen(...)`, which the plan correctly keeps firing on every tick.

**Fix:** Rename the helper to convey both fields, e.g. `equalsIgnoringTickFields`, and exclude **both** `remainingTicks` and `currentIntervalMs` from the comparison. Update Task 1's field list to drop `currentIntervalMs`. Update Task 2's prose ("differs only in `remainingTicks`") to say "differs only in tick-cadence fields (`remainingTicks`, `currentIntervalMs`)". Update the comment-above-setter docs accordingly.

This is the only critical defect, but without this fix the plan delivers zero observable improvement.

---

## Minor Issues / Suggestions

### 2. Helper name should advertise the broader scope

Once `currentIntervalMs` is included, `equalsIgnoringRemainingTicks` is a misleading name. Recommend `equalsIgnoringTickFields(BreathSessionState other)` with a doc comment listing the two excluded fields and explaining why (cadence-only fields published on the raw stream, not for Riverpod consumers). This also avoids future confusion if more cadence-only fields are added.

### 3. Empty-publish hazard during `build()` — already safe, but worth a one-line note

The plan's "Note on reading current state" is correct: `set state` is only invoked after `build()` (via `_setupEngine`, `_onEngineState`, `toggleStar`, and the error branch in `initState`), so `super.state` is safe. Worth keeping that exact wording in the comment above the setter — the next maintainer will wonder.

### 4. `timelineSteps` identity check — confirmed correct, but add a `// ignore: prefer_const_constructors`-style nudge in a comment

`_onEngineState` (line 151) reuses `state.timelineSteps` by reference, so `identical(a.timelineSteps, b.timelineSteps)` correctly returns `true` on ticks. `_setupEngine` (line 113) builds a fresh list via `_buildTimelineSteps(dto)` on restart, so `identical(...)` correctly returns `false` and the publication fires. Plan task 1 already calls this out — good. Recommend adding a one-line comment in the helper explaining the identity choice ("list is mutated by-replacement only on restart per task 28"), since `identical` on a non-const `List` is unusual enough to invite a future "you should use `listEquals`" refactor that would silently break the optimization.

### 5. Task 3 audit — one consumer worth re-confirming

`BreathSessionScreen.dart:162` reads `final state = ref.watch(breathViewModelProvider);` and uses `state.status`, `state.canStar`, `state.loadState`, `state.timelineSteps`, `state.activeStepId`. None of these include `remainingTicks` or `currentIntervalMs`, so the filter is safe. Plan task 3 already accounts for this. ✓

Also re-confirm that `_buildControlButton(state, ...)` (line 228) does not inspect `remainingTicks` — a quick grep in the screen file shows it doesn't, but worth a deliberate check during task 3.

### 6. `tickSource` in the comparison — fine, but flag for future

`tickSource` is currently set only in `_setupEngine` (from `tickService.source`) and copied through in `_onEngineState`. It does not vary per tick today. Including it in the equality check is correct. If runtime tick-source switching is ever added (per `docs/breath/session/tick-sources.md`), the switch will produce a structural publication — the desired behavior.

---

## Positive Notes

- **Architectural framing is exactly right.** Filtering at the Riverpod publication layer while keeping the raw `_stateController.add(value)` firing per tick is the correct seam — it preserves the animation/sound/state-channel cadence and only narrows the Riverpod rebuild scope. Note 11's subscriber audit is faithfully reflected in the plan.
- **Tasks 26/27/28 dependency is acknowledged** (stable `timelineSteps`, `remainingTicksNotifier`) so the identity check on `timelineSteps` is valid.
- **Full-constructor vs copyWith hazard is respected** — the plan does not try to refactor `_onEngineState` to copyWith (which would re-introduce the nullable-clearing bug).
- **Scope is tight** — two files, no test churn, no schema/migration concerns, no proto changes, no cross-project coordination.
- **The "no rebuild on tick" exit criteria is verifiable** by running `flutter run --flavor dev -t lib/main_dev.dart` and checking that `BreathSessionScreen.build` no longer logs once per second under devtools — worth recording in a verify step even though the plan opts out of formal testing.

---

## Verdict

The plan is **almost** ready. The architecture, file paths, dependency ordering, and risk analysis are all correct. But Task 1 includes `currentIntervalMs` in the equality check, and because that field is reset to the measured tick interval on every emit, the filter as specified will never skip a publication. Fix that and the plan ships.

Required edits before implementation:
1. In Task 1, drop `currentIntervalMs` from the compare list; rename the helper to `equalsIgnoringTickFields` (or similar) and document the two excluded fields.
2. In Task 2 (and the inline comment), update the wording from "differs only in `remainingTicks`" to "differs only in tick-cadence fields (`remainingTicks`, `currentIntervalMs`)".
3. In Task 3, add `currentIntervalMs` to the list of fields the screen must not be observed reading from `ref.watch`.
