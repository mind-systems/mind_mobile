# BreathSession State Equality + ViewModel Publication — Test Batch

**Date:** 2026-06-17
**Source:** roadmap-decompose

## Key Findings

- Three closely related test groups, two new test files under `test/BreathModule/Presentation/BreathSession/`.
- `equalsIgnoringTickFields` excludes **three** fields — `remainingTicks`, `currentIntervalMs`, and `resetReason` — the ROADMAP_TESTS.md inline description erroneously listed only two; `resetReason` must be covered.
- The `timelineSteps` identity check (`identical(...)`) is load-bearing: swapping to `listEquals` would defeat the Riverpod tick-suppression optimization silently.
- Fakes for the ViewModel tests are already available in `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` (`_FakeTickService`, `_FakeCoordinator`, `_FakeSessionService`) — copy them inline; do not import across test files.

## Details

### File 1: `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart`

**Purpose:** pin the equality contract of `BreathSessionState.equalsIgnoringTickFields`.

**Helper:** `_state({...})` returning a fully-populated `BreathSessionState` with every field set to a non-default value so that a flip of any single field is observable.

**Test groups:**

#### Excluded fields return `true`
For each excluded field, build two states differing only in that field and assert `a.equalsIgnoringTickFields(b) == true`:
- `remainingTicks`
- `currentIntervalMs`
- `resetReason` ← must be included; the ROADMAP_TESTS.md description missed this one

#### Included scalar fields return `false`
For each included field, two states differing only in that field → `false`. Fields to cover:
`loadState`, `status`, `phase`, `exerciseIndex`, `activeStepId`, `isStarred`, `canStar`,
`totalPhases`, `currentPhaseIndex`, `currentPhaseTotalDuration`,
`currentExerciseShape`, `nextExerciseShape`, `tickSource`

#### `timelineSteps` identity semantics
- Same `List<TimelineStep>` reference → `true`
- Two separate `List<TimelineStep>` instances with identical content → `false`
  (the `identical(...)` check is intentional; this test pins it so any future swap to `listEquals` fails loudly)

---

### File 2: `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart`

**Purpose:** verify the dual-channel publication contract and the `timelineSteps` identity invariant.

**Setup:**
- Inline fakes: `_FakeTickService` (injectable `StreamController<TickData>`) + `_FakeSessionService` + `_FakeCoordinator` — copy from `breath_session_star_toggle_test.dart`.
- Build a `BreathSessionDTO` with one exercise of two steps (inhale 2 ticks, exhale 2 ticks).
- Construct a `ProviderContainer` overriding `breathViewModelProvider` with the fakes.

**Test groups:**

#### Riverpod publication filtered on tick-only updates
1. Call `vm.initState()` and await async pump.
2. Add a counting listener via `container.listen<BreathSessionState>(breathViewModelProvider, ...)` with `fireImmediately: false`.
3. Drive `tickService.tick()` calls that only advance `remainingTicks` (no phase change) — assert `count == 0`.
4. Drive enough ticks for the phase to flip — assert `count` increments by exactly 1.

#### Raw `vm.stream` fires on every update including tick-only
- Subscribe to `vm.stream` before driving ticks.
- Same tick sequence as above — assert subscriber received one event per tick.

#### `remainingTicksNotifier` advances on every tick
- Attach a `ValueNotifier` listener to `vm.remainingTicksNotifier`.
- Drive ticks — assert the listener fired on each tick where the value changed and `notifier.value` matches `engineState.remainingTicks`.

#### `timelineSteps` identity preserved across ticks
- After `vm.initState()`, capture `final captured = vm.currentState.timelineSteps`.
- Drive several `tickService.tick()` calls — after each, assert `identical(vm.currentState.timelineSteps, captured) == true`.
- Call `vm.restartEngine()` — assert `identical(vm.currentState.timelineSteps, captured) == false` (only `_setupEngine` builds a new list).

## Open Questions

- `_FakeTickService` needs a public `void tick()` method and a `StreamController<TickData>` — verify the fake in `breath_session_star_toggle_test.dart` already exposes both, or extend it.
- `BreathSessionDTO` minimum shape for a two-step exercise — read `BreathSessionDTO` + `BreathStep` constructors before building the test fixture.
