# Plan: Add `tickSource: TickSource` to `BreathSessionState` via `ITickService.source`

## Context
`BreathSessionState` lacks a tick-source field that `BreathSoundCoordinator` (milestone 12.6) needs to choose the correct one-shot sound. Expose the tick source via `ITickService.source`, implement it in `ClockTickService`, add the field to `BreathSessionState`, and wire it through `BreathViewModel` so the value is stable per session and only changes when the engine is rebuilt.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Expose `source` on the tick service contract

- [x] **Task 1: Add `TickSource get source` to `ITickService`**
  Files: `packages/breath_module/lib/src/ITickService.dart`
  Add `import 'CommonModels/TickSource.dart';` at the top of the file. Inside the existing `abstract class ITickService`, add an abstract getter `TickSource get source;` alongside the existing `tickStream` getter and `dispose()` method. Do not modify `TickData`. The existing `TickSource` enum (`heartbeat`, `timer`) at `packages/breath_module/lib/src/CommonModels/TickSource.dart` already covers the needed values.

- [x] **Task 2: Implement `source` in `ClockTickService`** (depends on Task 1)
  Files: `lib/BreathModule/ClockTickService.dart`
  Update the `breath_module` import to include `TickSource` (extend the existing `show ITickService, TickData` clause to `show ITickService, TickData, TickSource`). Add the override:
  ```dart
  @override
  TickSource get source => TickSource.timer;
  ```
  Place it next to the existing `tickStream` getter. No other changes to the timer simulation.

### Phase 2: Carry tick source through state and view-model

- [x] **Task 3: Add `tickSource` field to `BreathSessionState`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart`
  Add `import '../../CommonModels/TickSource.dart';` (sibling to the existing `SetShape` import). Add a `final TickSource tickSource;` field to the class. In the const constructor add `this.tickSource = TickSource.timer,` as a named parameter with default — keep it grouped with other enriched fields. Update `BreathSessionState.initial()` to keep using the default (no explicit value needed). In `copyWith`, add an optional `TickSource? tickSource,` parameter and `tickSource: tickSource ?? this.tickSource,` in the returned constructor call. Follow the existing parameter ordering style (named, defaulted) used by the surrounding enriched fields.

- [x] **Task 4: Pass tick source through `BreathViewModel`** (depends on Tasks 1 and 3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  In `_setupEngine(BreathSessionDTO dto)`, inside the full `BreathSessionState(...)` constructor call that assigns `state`, add `tickSource: tickService.source,` alongside the other named arguments (place it near `currentIntervalMs` or with the other enriched fields for readability). In `_onEngineState(BreathSessionStateMachineState engineState)`, inside the second full `BreathSessionState(...)` constructor call, add `tickSource: state.tickSource,` to carry the value forward — the engine state does not emit tick source because it is stable per session and only changes when `_setupEngine` runs again. No changes are needed in `BreathSessionStateMachine` or the engine state class.
  Note: when milestone 12.x adds `HeartbeatTickService`, revisit the initial-emission ordering in `_onEngineState` — if the state-machine stream were to emit synchronously before `_setupEngine` finishes assigning the new `state`, carrying `state.tickSource` forward would yield the previous (default `timer`) value. Today this is moot because only `ClockTickService` exists, but a safer pattern is to fall back to `tickService.source` instead of `state.tickSource`.

### Phase 3: Keep test fakes compiling

- [x] **Task 5: Update existing `ITickService` test fakes to implement `source`** (depends on Task 1)
  Files:
  - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart`
  - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart`
  - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart`
  - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart`
  - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart`
  Adding the abstract `TickSource get source;` getter to `ITickService` (Task 1) makes every existing `implements ITickService` declaration a compile error until the getter is implemented. In each of the listed files, add the override
  ```dart
  @override
  TickSource get source => TickSource.timer;
  ```
  to the `_ManualTickService` / `_FakeTickService` / `FakeTickService` class. Where the file's import of `package:breath_module/breath_module.dart` uses a `show` clause that lists `ITickService` and `TickData` but not `TickSource`, extend the `show` clause to include `TickSource` so the enum is in scope. Do not change any other test logic — this task is purely keeping the fakes valid against the updated interface.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Expose tick source on ITickService and implement in ClockTickService"
- **Commit 2** (after tasks 3-5): "Carry tickSource through BreathSessionState and ViewModel, update test fakes"
