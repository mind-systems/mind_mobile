# Plan: Wire `SwitchableTickService` in `BreathModule.buildSession()`

## Context
Replace the bare `ClockTickService` instantiation in `BreathModule.buildSession()` with a `SwitchableTickService` facade that owns both a `ClockTickService` and a `HeartRateTickService`. Behavior is unchanged in this milestone — sessions still tick from the clock; the facade is dormant until milestone 6 adds the toggle API.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Wire Switchable facade

- [x] **Task 1: Replace tick service construction in `buildSession()`**
  Files: `lib/BreathModule/BreathModule.dart`
  In the `buildSession(BuildContext, {required String sessionId})` method, replace the single line
  `final tickService = ClockTickService()..simulateTick();`
  with three lines:
  ```dart
  final clock = ClockTickService()..simulateTick();
  final heart = HeartRateTickService(activeRrSource: App.shared.activeRrSource);
  final tickService = SwitchableTickService(clock: clock, heart: heart);
  ```
  Rationale for keeping `clock.simulateTick()` always running: when the user switches back from heart to clock later (milestone 6), the timer is already ticking and the facade just re-attaches its subscription — no first-tick lag. Do NOT change the rest of `buildSession()` — the existing `BreathViewModel` construction continues to receive `tickService` as an `ITickService`. The `SwitchableTickService` implements `ITickService`, so the VM signature is unaffected. Do NOT modify `BreathViewModel`, `BreathSessionScreen`, or any other file in this milestone.

- [x] **Task 2: Add the two new imports**
  Files: `lib/BreathModule/BreathModule.dart`
  Add the following imports alongside the existing `ClockTickService` import (keep alphabetical/grouping convention already used in the file — both should sit next to `package:mind/BreathModule/ClockTickService.dart`):
  ```dart
  import 'package:mind/BreathModule/HeartRateTickService.dart';
  import 'package:mind/BreathModule/SwitchableTickService.dart';
  ```
  Both files already exist at `lib/BreathModule/HeartRateTickService.dart` and `lib/BreathModule/SwitchableTickService.dart` (added in milestones 3 and 4). `App.shared.activeRrSource` is already wired in `lib/Core/App.dart` (milestone 2 — confirmed: `final ActiveRrSource activeRrSource` field exists on `App`). No new `App` field needed.

## Verification (manual, no test code)
After the edit, the file should still compile (`flutter analyze`) and `buildSession()` should still return a `BreathSessionScreen` wrapped in `ProviderScope`. Launching a session must behave identically to current `main` — clock-driven ticks, no UI difference. The `SwitchableTickService` defaults to `TickSource.timer` and forwards clock ticks, so no behavioral regression is possible from this change alone.

<!-- orchestrator-sessions
planner: 71058f4b-30f3-41c5-9624-a29afc76b28e
elapsed: 404
implementer: 14c949b6-ed4d-4b39-8c3a-953ce102cd06
-->
