# Plan: Add `BreathLifecycle` + `isLive`, derived from status + `_hasStarted`

## Context
Add a purely-additive keep-alive signal to the breath session output schema: a computed `BreathLifecycle lifecycle` enum + `bool isLive` getter, derived at every emit from the existing `(status, _hasStarted)` — without touching progression math or `status` semantics. Spec: `.ai-factory/notes/05-breath-derive-lifecycle-islive.md`.

## Settings
- Testing: yes (milestone mandates red contract tests first → green)
- Logging: minimal
- Docs: no

## Key Facts (from recon)
- `BreathSessionState` lives in `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart` and is re-exported wholesale by `packages/breath_module/lib/breath_module.dart` (`export 'src/BreathSession/Models/BreathSessionState.dart'`). **No barrel edit needed** — adding `BreathLifecycle` to that file exports it automatically.
- `BreathSessionStateMachineState` lives in `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart` (also re-exported by the barrel).
- The state machine has **no single `_emit` construction point** — every emission builds a full `BreathSessionStateMachineState(...)` constructor. Construction sites that must compute `lifecycle`: `_initialRestState` (`:117`), `_initialBreathState` (`:141`), `pause` (`:167`), `resume` (`:191`), `complete` (`:216`), `_onBreathTick` (`:278`), `_onRestTick` (`:315`), `_startRest` (`:343`), `_startNewCycle` (`:373`). `_hasStarted` is an instance field in scope at all of them.
- ViewModel full-constructor sites that must carry `lifecycle` through: `BreathSessionViewModel.dart` `_setupEngine` (`:152`) and `_onEngineState` (`:189`). All other ViewModel writes use `copyWith` and never change `status`, so a `?? this.lifecycle` passthrough stays consistent there.
- `_hasStarted` flips to `true` at the end of `resume()` (`:205`), **after** the emit — so the first `resume()` emits with `_hasStarted == false` still observable inside the constructor; derive from the post-resume target. (See derivation note in Task 2.)
- Test harness: `test/BreathModule/Support/BreathActivityHarness.dart` exposes a placeholder `bool get isLive => false` (lines 62-64) explicitly reserved for this milestone. Tests record states via `harness.states`.
- Existing contract/characterization tests: `test/BreathModule/Support/breath_activity_boundary_characterization_test.dart` (golden master — must stay green) and the harness/fakes under `test/BreathModule/`.
- **`BreathSessionState` has external full-constructor call sites in 3 test files** that pass no `lifecycle` and would fail to compile if the field were `required`. A single compile error anywhere under `test/` fails the entire `flutter test` target — so a `required` field would block the TDD red→green flow (the red suite couldn't compile, and the golden master couldn't stay green). The 5 call sites:
  - `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart` — `:29` (the `_state()` helper), `:72`, `:98`
  - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `:569` (a `const BreathSessionState(...)`)
  - `test/BreathModule/breath_module_state_channel_test.dart` — `:111` (a state-builder helper)
  These are **not** modified by this plan — Task 2 gives `lifecycle` a default so they keep compiling untouched (see Task 2).
- `BreathSessionStateMachineState` has **no** external full-constructor callers (only its 9 in-file emit sites + its own `copyWith`), so `required` is safe there.

## Derivation Rule (single source of truth)
From `(status, _hasStarted)`:
- `status == complete` → `BreathLifecycle.completed`
- `status ∈ {breath, rest}` → `BreathLifecycle.running`
- `status == pause && _hasStarted` → `BreathLifecycle.paused`
- `status == pause && !_hasStarted` → `BreathLifecycle.notStarted`

`isLive == lifecycle ∈ {running, paused}` — true through manual pause, false for not-started and completed.

## Tasks

### Phase 1: Red contract tests

- [x] **Task 1: Add red `lifecycle` / `isLive` contract tests**
  Files: `test/BreathModule/Presentation/BreathSession/breath_lifecycle_islive_test.dart` (new)
  Using `BreathActivityHarness` + fakes (same setup pattern as `breath_activity_boundary_characterization_test.dart`: `await harness.init(); await pumpEventQueue();`), assert the lifecycle transition table on `harness.states.last` (or `.first` for initial):
  - Initial (pre-resume) state → `lifecycle == BreathLifecycle.notStarted`, `isLive == false`.
  - After `resume()` → `lifecycle == BreathLifecycle.running`, `isLive == true`.
  - After a `pause()` that follows a `resume()` → `lifecycle == BreathLifecycle.paused`, `isLive == true` (keep-alive window holds through manual pause).
  - After `complete()` → `lifecycle == BreathLifecycle.completed`, `isLive == false`.
  - A `rest`-phase running emit → `lifecycle == BreathLifecycle.running`. **The harness default session (`makeSession([makeExercise()])`) is inhale=2/exhale=2 with no rest step, so it never emits a `rest` status** — build a custom rest-bearing DTO (e.g. a rest-only first exercise via `makeSession`/`makeExercise`) passed to `BreathActivityHarness(session: ...)`, then `resume()` → `status == rest` → `running`.
  These reference `BreathLifecycle` / `isLive`, which do not exist yet — the suite is red (compile/assertion failure) until Phase 2 lands. That compile-red is the intended TDD red signal.

### Phase 2: Make green — additive production change

- [x] **Task 2: Add `BreathLifecycle` + `lifecycle` field + `isLive` to `BreathSessionState`** (unblocks Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  - Declare `enum BreathLifecycle { notStarted, running, paused, completed }` alongside the existing enums (top of file, near `:5`).
  - Add `final BreathLifecycle lifecycle;` field and a getter `bool get isLive => lifecycle == BreathLifecycle.running || lifecycle == BreathLifecycle.paused;`.
  - Add the field to the const constructor with a **default, not `required`**: `this.lifecycle = BreathLifecycle.notStarted`. This is the blocking fix from plan-review-1: the 5 pre-existing external call sites (3 test files, incl. the `const` site at `enriched_state_test:569`) keep compiling untouched, so the test target compiles and the TDD red→green flow is reachable. Production correctness is unaffected — every production emit site sets `lifecycle` explicitly (Tasks 3-4), so the default is only ever observed by those pre-existing tests (which don't assert on `lifecycle`). It also matches the milestone's "purely additive" guard — existing constructions stay valid. The default value (`notStarted`) is consistent with `factory BreathSessionState.initial()` (`:60`, status `pause`, not started); no edit to `.initial()` is required since it already omits the field and inherits the default (optionally pass it explicitly for clarity).
  - Add `BreathLifecycle? lifecycle` param to `copyWith` (`:112`) with `lifecycle: lifecycle ?? this.lifecycle`.
  - Add `lifecycle == other.lifecycle` to `equalsIgnoringTickFields` (`:95`) — it is a structural field and must trigger Riverpod publication (note §Details).
  Keep `status` and all existing fields/semantics untouched.

- [x] **Task 3: Compute `lifecycle` at every emit in `BreathSessionStateMachine`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
  - Add `final BreathLifecycle lifecycle;` to `BreathSessionStateMachineState` (`:13`), as `required this.lifecycle` in its constructor (`:29`), and as a `?? this.lifecycle` passthrough in its `copyWith` (`:44`).
  - Add a private helper `BreathLifecycle _lifecycleFor(BreathSessionStatus status, bool hasStarted)` implementing the derivation rule above; call it from each full-constructor emit. Pass the **status being emitted** (not `_state.status`) and the appropriate `_hasStarted`:
    - `_initialRestState` / `_initialBreathState`: status `pause`, `_hasStarted == false` → `notStarted`.
    - `pause`: status `pause`, current `_hasStarted` → `paused` if started else `notStarted`.
    - `resume`: status is `rest`/`breath`; `_hasStarted` is still `false` on first resume but target is `running` regardless → pass `running`-yielding status (status ∈ {breath,rest} maps to `running` independent of `_hasStarted`, so `_hasStarted` value is irrelevant here). Keep the existing `_hasStarted = true` assignment after the emit unchanged.
    - `complete`: status `complete` → `completed`.
    - `_onBreathTick` / `_onRestTick` / `_startRest` / `_startNewCycle`: status `breath`/`rest` → `running`.
  - **Do not touch** progression counters or `_onTick`/`_advanceExercise` logic — only each emitted struct gains the field. `_hasStarted` stays (its removal is milestone 09).
  - Acceptable smaller-surface alternative (plan-review-1 minor note): derive `lifecycle` once centrally in `_emit` from `newState.status` + `_hasStarted` instead of at each of the 9 sites — it yields the identical result (at `resume()`, `status ∈ {breath,rest}` → `running` independent of `_hasStarted`). Either approach is correct; the per-site helper is the default for consistency with the existing full-constructor style.

- [x] **Task 4: Carry `lifecycle` through `BreathViewModel` full-constructor sites** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  - In `_setupEngine` (`:152`) add `lifecycle: initialEngineState.lifecycle,` to the full `BreathSessionState(...)`.
  - In `_onEngineState` (`:189`) add `lifecycle: engineState.lifecycle,` to the full `BreathSessionState(...)`.
  - Leave all `copyWith`-based writes (tickSource, loadState/error) as-is — they don't change `status`, so the carried `lifecycle` stays correct.

- [x] **Task 5: Wire the harness `isLive` placeholder to real state** (depends on Task 4)
  Files: `test/BreathModule/Support/BreathActivityHarness.dart`
  - Replace the placeholder `bool get isLive => false;` (`:64`) with a derivation from the latest recorded state: `bool get isLive => states.isNotEmpty && states.last.isLive;`. Update the surrounding doc comment (`:62-63`) to state it now reflects the live lifecycle signal.
  - Run the full breath test suite: the new Task 1 suite goes green, and the golden master (`breath_activity_boundary_characterization_test.dart`) stays green (`status` semantics unchanged).

## Commit Plan
- **Commit 1** (after tasks 1-5): "Add derived BreathLifecycle and isLive to breath session state"
  - The change is atomic — the red tests (Task 1) cannot compile or pass until the additive field lands (Tasks 2-4) and the harness is wired (Task 5). Commit once the suite is green.
