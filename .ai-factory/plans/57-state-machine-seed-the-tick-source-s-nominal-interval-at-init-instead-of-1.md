# Plan: State machine: seed the tick source's nominal interval at init instead of `-1`

## Context
The breath state machine seeds `currentIntervalMs: -1` at the origin, so animation/audio have no cadence until the first tick lands. This milestone exposes a `nominalIntervalMs` accessor on the tick services and seeds it into the two initial-state builders so the origin has a real cadence from construction.

## Settings
- Testing: no (no new tests; the existing suite must still compile — see Task 6)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Expose nominal interval on the tick service contract

- [x] **Task 1: Add `nominalIntervalMs` to `ITickService`**
  Files: `packages/breath_module/lib/src/ITickService.dart`
  Add `int get nominalIntervalMs;` to the `ITickService` abstract class (place it near `source`, before `trySwitchTo`). This is the nominal/configured cadence known from construction — distinct from `TickData.intervalMs`, which is the per-tick *measured* delta. Add a brief doc comment clarifying it is the origin/nominal cadence, not a measured delta.

- [x] **Task 2: Implement `nominalIntervalMs` in `ClockTickService`** (depends on Task 1)
  Files: `lib/BreathModule/ClockTickService.dart`
  Add `@override int get nominalIntervalMs => 1000;` to match the existing 1000 ms timer period (the value already used in `simulateTick`).

- [x] **Task 3: Implement `nominalIntervalMs` in `HeartRateTickService`** (depends on Task 1)
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Add `@override int get nominalIntervalMs => 1000;` as a placeholder. Per the spec, the service caches no last RR and has no BPM target, so 1000 is the honest default before the first beat; the origin seed is overwritten on the first real RR tick. Add a short comment noting it is a placeholder until the first measured RR arrives.

- [x] **Task 4: Implement `nominalIntervalMs` in `SwitchableTickService`** (depends on Task 1)
  Files: `lib/BreathModule/SwitchableTickService.dart`
  Add `@override int get nominalIntervalMs => _activeSource == TickSource.timer ? _clock.nominalIntervalMs : _heart.nominalIntervalMs;` so it delegates to the currently active source.

- [x] **Task 6: Add `nominalIntervalMs` to all test fakes so `flutter test` still compiles** (depends on Task 1)
  Widening `ITickService` (and the concrete `ClockTickService` / `HeartRateTickService`) is a breaking change for every explicit implementer. None of these fakes use `noSuchMethod`, so the suite will not compile until each gains the getter. Add `@override int get nominalIntervalMs => 1000;` (the state machine reads it once at construction, so a literal is sufficient) to all 8 fakes:
  - `test/BreathModule/switchable_tick_service_test.dart` — `_FakeClockTickService` (line 18) and `_FakeHeartRateTickService` (line 47), which implement the concrete classes that also gain the getter
  - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` — `FakeTickService` (line 10)
  - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `FakeTickService` (line 19)
  - `test/BreathModule/Presentation/BreathSession/breath_view_model_publication_test.dart` — `_FakeTickService` (line 25)
  - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` — `_FakeTickService` (line 11)
  - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` — `_FakeTickService` (line 21)
  - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` — `_ManualTickService` (line 11)
  This keeps the existing suite compiling; it adds no new test coverage (consistent with `Testing: no`).

### Phase 2: Seed the nominal interval into the initial state builders

- [x] **Task 5: Seed `currentIntervalMs` from the tick service in both initial builders** (depends on Tasks 2-4)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart`
  In `_initialRestState()` (line 127) and `_initialBreathState()` (line 151), replace `currentIntervalMs: -1` with `currentIntervalMs: tickService.nominalIntervalMs`. Do NOT touch `resume()`/`pause()` (they carry the already-seeded value forward) or any of `_onBreathTick`/`_onRestTick`/`_startNewCycle`/`_startRest`, which keep folding the measured `tickData.intervalMs`. Leave `BreathSessionState.initial()` (`Models/BreathSessionState.dart`) at `-1` — it is the pre-load state with no cadence consumer.

## Notes
- `-1` remains a valid *measured*-delta sentinel elsewhere; this change only affects the two state-machine initial builders.
- `equalsIgnoringTickFields` already excludes `currentIntervalMs`, so seeding a real value does not perturb structural-change detection.
- Independently shippable: after note 121 the wire carries no `durationMs`, so this is purely in-app origin cadence with no contract impact.
- No `build_runner` regeneration needed — no Drift schema or generated code is touched.
