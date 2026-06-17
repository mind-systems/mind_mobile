# Test Plan: BreathSession state equality and ViewModel publication tests

## Context
Pin down two untested invariants in `packages/breath_module`: the field-selective equality contract of `BreathSessionState.equalsIgnoringTickFields` (which fields are ignored vs. structural), and the dual-channel publication contract of `BreathViewModel` (Riverpod publication suppressed on tick-only updates, while the raw stream and `remainingTicksNotifier` fire every tick, and `timelineSteps` reference identity is preserved across ticks but invalidated by `restartEngine()`).

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`

## Target Spec Files
- `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`
- `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`

## Source Under Test
- `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` — `equalsIgnoringTickFields`
- `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` — `set state`, `_setupEngine`, `_onEngineState`, `restartEngine`, `remainingTicksNotifier`, `stream`

All types (`BreathSessionState`, `TimelineStep`, `SetShape`, `TickSource`, `ResetReason`, `BreathSessionStatus`, `BreathPhase`, `SessionLoadState`, plus VM/DTO/service interfaces) are exported from `package:breath_module/breath_module.dart` — import only the barrel.

---

## Implementation Notes (read before writing cases)

**Equality file — `_state({...})` helper.**
Build a fully-populated `BreathSessionState` with every field set to a *non-default* value so flipping any single field is observable. Default values to AVOID (so a flip is visible): `loadState` ≠ default → use `SessionLoadState.ready`; `status` → `BreathSessionStatus.breath`; `phase` → `BreathPhase.exhale`; `exerciseIndex: 3`; `activeStepId: 'step-x'`; `isStarred: true`; `canStar: true`; `resetReason: ResetReason.newCycle`; `totalPhases: 5`; `currentPhaseIndex: 2`; `currentPhaseTotalDuration: 7`; `currentExerciseShape: SetShape.circle`; `nextExerciseShape: SetShape.square`; `tickSource: TickSource.heartbeat`; `remainingTicks: 9`; `currentIntervalMs: 1000`.
- **Critical:** `equalsIgnoringTickFields` includes `identical(timelineSteps, other.timelineSteps)`. For every scalar comparison, BOTH states must share the **same `timelineSteps` list instance**, otherwise the identity check alone forces `false` and the scalar assertion is meaningless. Give `_state` a `timelineSteps` parameter defaulting to one module-level shared `final` list, and have `copyWith` carry it by reference (it does). Use `_state().copyWith(field: newValue)` to produce the single-field variant — `copyWith` preserves the `timelineSteps` reference.
- Note `copyWith` cannot clear `resetReason` to null (uses `??`). The excluded-`resetReason` case needs two states with *different non-null* reasons (e.g. `newCycle` vs `rest`), or build the second state via the full constructor. Both still ⇒ `true`.

**Publication file — driving the engine.**
- Copy `_FakeTickService`, `_FakeCoordinator`, `_FakeSessionService`, `_makeDTO`, and `_makeContainer` inline from `breath_session_star_toggle_test.dart`. Do not import across test files.
- **Critical — neutralize the `observeSession` re-setup.** The star-toggle fake returns `observeSession(id) => Stream.value(dto)`. In `initState` (`BreathSessionViewModel.dart:115`) that subscription fires once asynchronously and calls `_setupEngine(dto)` a **second time**, which builds a *new* `timelineSteps` list (new reference), constructs a *fresh paused* `BreathSessionStateMachine`, and emits a structural `set state`. Left unhandled this makes every publication/identity test flaky: it can replace the captured `timelineSteps` before any tick (breaks Task 7), reset the engine to paused after `resume()` so ticks hit a paused machine (breaks Tasks 4/5/6), and offset the Riverpod baseline count (breaks Task 4). **Fix: in the copied `_FakeSessionService`, override `observeSession` to return `const Stream.empty()`** — the live-update behavior is not exercised by this suite. (The `restartEngine()` path in Task 7 still deliberately rebuilds the list; that is the only intended re-setup.)
- The DTO from `_makeDTO()` is one exercise: inhale 2 ticks + exhale 2 ticks (`cycleDuration = 4`, `repeatCount = 1`).
- The state machine starts in `BreathSessionStatus.pause`; `_onTick` returns early while paused. **Tests must call `vm.resume()` after `initState()`** before ticks have any effect.
- **`resume()` is itself a structural publication** (`status: pause→breath`): it pushes one Riverpod publication and one raw-`stream` emit, and `_setupEngine` at init pushes another raw-`stream` emit. So any per-tick count/collection must establish its baseline **after `resume()` settles** — attach the Riverpod listener / start collecting `vm.stream` events / reset counters only then.
- **Canonical ordering for every publication test:** `read notifier → await vm.initState() → await pumpEventQueue() → vm.resume() → await pumpEventQueue() → attach listener or reset count/collection → drive ticks (pump after each)`.
- Tick cadence after `resume()` (each `tickService.tick()` = one engine emit while running):
  - tick 1 → phase stays `inhale`, `remainingTicks 2→1` (tick-only, no structural change)
  - tick 2 → phase flips `inhale→exhale` (structural change)
  - tick 3 → phase stays `exhale`, `remainingTicks 2→1` (tick-only)
  - tick 4 → cycle ends → `_advanceExercise` → `complete` (structural: status→complete)
- Pump async steps with `await pumpEventQueue()` (from `flutter_test`) — `initState`, the stream subscriptions, and `tickService` are all async broadcast streams. `pumpEventLoop` is **not** a real symbol; the pure-Dart alternative is `await Future(() {})`.
- `_remainingTicks`/`stream`/`set state` are only valid after `build()`; always `container.read(breathViewModelProvider.notifier)` then `await vm.initState()` first.

---

## Tasks

### Phase 1: `breath_session_state_equality_test.dart`

- [x] **Task 1: Excluded fields are ignored (`equalsIgnoringTickFields` returns `true`)**
  Files: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`
  Two states differing only in one excluded field (shared `timelineSteps` reference) must compare equal. Test cases:
  - `should return true when only remainingTicks differs`
  - `should return true when only currentIntervalMs differs`
  - `should return true when only resetReason differs` (e.g. `newCycle` vs `rest`; build via full constructor since copyWith cannot vary it freely)
  - `should return true when remainingTicks, currentIntervalMs and resetReason all differ together`
  - `should return true when comparing a state to an otherwise-identical copy` (baseline sanity: same reference timeline, identical scalars)

- [x] **Task 2: Included scalar fields are structural (`equalsIgnoringTickFields` returns `false`)**
  Files: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`
  For each included scalar, two states differing only in that field (shared `timelineSteps` reference) must compare unequal. Test cases (one `it` per field):
  - `should return false when only loadState differs`
  - `should return false when only status differs`
  - `should return false when only phase differs`
  - `should return false when only exerciseIndex differs`
  - `should return false when only activeStepId differs`
  - `should return false when only isStarred differs`
  - `should return false when only canStar differs`
  - `should return false when only totalPhases differs`
  - `should return false when only currentPhaseIndex differs`
  - `should return false when only currentPhaseTotalDuration differs`
  - `should return false when only currentExerciseShape differs`
  - `should return false when only nextExerciseShape differs`
  - `should return false when only tickSource differs`

- [x] **Task 3: `timelineSteps` identity semantics**
  Files: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`
  Pins the intentional `identical(...)` check (a `listEquals` refactor must fail loudly). Test cases:
  - `should return true when timelineSteps is the same list reference` (all other fields equal too)
  - `should return false when timelineSteps are two separate lists with identical content` (build two distinct `List<TimelineStep>` with equal elements; every other field equal)

---

### Phase 2: `breath_view_model_publication_test.dart`

> Apply the **Canonical ordering** (see Implementation Notes) in every task below, and use the `observeSession → const Stream.empty()` fake override. All baselines are established after `resume()` settles.

- [x] **Task 4: Riverpod publication is suppressed on tick-only updates**
  Files: `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`
  Order: `initState → pump → resume → pump → attach container.listen<BreathSessionState>(breathViewModelProvider, ..., fireImmediately: false) (or reset counter) → drive ticks`. Count listener invocations. Test cases:
  - `should not publish to Riverpod when a tick only advances remainingTicks` (drive tick 1 only → listener count == 0)
  - `should publish to Riverpod exactly once when the phase flips` (drive ticks 1 then 2 → count increments by exactly 1 on the phase flip)
  - `should publish to Riverpod when status transitions to complete` (drive through tick 4 → a structural publication occurs for the complete transition)

- [x] **Task 5: Raw `vm.stream` fires on every update including tick-only**
  Files: `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`
  Subscribe to `vm.stream` (broadcast) and collect emitted states; establish the baseline **after `resume()` settles** so the init/resume emits don't pollute the per-tick count. Test cases:
  - `should emit on vm.stream for every tick including tick-only updates` (drive ticks 1–3 → one stream event per processed tick, including the tick-only ticks Riverpod suppressed; count from post-resume baseline)
  - `should not emit on vm.stream while paused` (drive ticks without calling resume → engine returns early, no new stream events beyond setup)

- [x] **Task 6: `remainingTicksNotifier` advances on every tick**
  Files: `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`
  Attach a listener to `vm.remainingTicksNotifier` (a `ValueListenable<int>`) after `resume()` settles. Test cases:
  - `should update remainingTicksNotifier on each tick where the value changes` (drive ticks 1–3 → listener fires per value change)
  - `should keep remainingTicksNotifier value in sync with the engine remainingTicks` — compare `notifier.value` against the **latest `vm.stream` emission's** `remainingTicks` (the raw/engine channel, which fires every tick), NOT `vm.currentState.remainingTicks`. On tick-only ticks the Riverpod-published `vm.currentState` is intentionally stale (publication suppressed), so comparing to it would fail on exactly the ticks this suite verifies.

- [x] **Task 7: `timelineSteps` reference preserved across ticks, invalidated by `restartEngine()`**
  Files: `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`
  Order: `initState → pump (so the observeSession re-setup, now empty, is a no-op) → capture final captured = vm.currentState.timelineSteps → resume → pump`. Test cases:
  - `should preserve the timelineSteps reference across multiple ticks` (drive several ticks → after each, `identical(vm.currentState.timelineSteps, captured)` is `true`)
  - `should rebuild the timelineSteps list on restartEngine` (call `vm.restartEngine()` → `identical(vm.currentState.timelineSteps, captured)` is `false`, since only `_setupEngine` builds a new list)
