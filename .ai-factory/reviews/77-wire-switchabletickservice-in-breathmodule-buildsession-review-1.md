# Code Review: Wire `SwitchableTickService` in `BreathModule.buildSession()`

**Plan:** `.ai-factory/plans/77-wire-switchabletickservice-in-breathmodule-buildsession.md`
**Files changed:** `lib/BreathModule/BreathModule.dart` (only)
**Risk level:** 🟢 Low — single-file wiring change, no signature changes, no new domain state.

## Diff summary

`lib/BreathModule/BreathModule.dart`:
- +2 imports: `HeartRateTickService.dart`, `SwitchableTickService.dart`.
- In `buildSession()`: replace
  ```dart
  final tickService = ClockTickService()..simulateTick();
  ```
  with
  ```dart
  final clock = ClockTickService()..simulateTick();
  final heart = HeartRateTickService(activeRrSource: App.shared.activeRrSource);
  final tickService = SwitchableTickService(clock: clock, heart: heart);
  ```
  No other changes. `tickService` is still passed to `BreathViewModel` as an `ITickService`.

This matches the plan exactly (Task 1 + Task 2).

## Correctness checks

| Check | Result |
|---|---|
| `SwitchableTickService implements ITickService` | ✅ (`SwitchableTickService.dart:8`) |
| `BreathViewModel` parameter type | ✅ accepts `ITickService` (`packages/breath_module/lib/src/ITickService.dart:3`) |
| `App.shared.activeRrSource` exists at runtime | ✅ field declared at `lib/Core/App.dart:90`, initialised at line 195, passed into `App._` at line 224 |
| `HeartRateTickService` constructor signature | ✅ `{required ActiveRrSource activeRrSource}` (`HeartRateTickService.dart:7`) |
| `SwitchableTickService` constructor signature | ✅ `{required ClockTickService clock, required HeartRateTickService heart}` (`SwitchableTickService.dart:9-13`) |
| Initial behavior (default to clock) | ✅ `_activeSource = TickSource.timer` and `_activeSub = _clock.tickStream.listen(...)` set in the constructor body (`SwitchableTickService.dart:14-15`); identical observable behaviour to a bare `ClockTickService` |
| `clock.simulateTick()` called eagerly | ✅ cascade `..simulateTick()` is on `ClockTickService()` itself, not on the facade — timer starts immediately, before `SwitchableTickService` even subscribes. Re-subscribing later to a running broadcast stream avoids first-tick lag, matching the plan's stated rationale. |
| Dispose chain | ✅ `BreathSessionViewModel.dart:72` calls `tickService.dispose()` on VM disposal; `SwitchableTickService.dispose()` (`SwitchableTickService.dart:62-70`) cancels both `_activeSub`/`_healthSub`, closes its two `StreamController`s, and propagates `dispose()` to both `_clock` and `_heart`. `HeartRateTickService.dispose()` correctly does **not** dispose the shared `ActiveRrSource` (comment at line 41). No leaks introduced. |
| Same `App.shared.activeRrSource` instance reused across sessions | ✅ `App.shared.activeRrSource` is a long-lived singleton; each session attaches one new `HeartRateTickService` subscription to `ActiveRrSource.stream` and `hasActiveSourceStream`, both released on dispose. |

## Rules / ARCHITECTURE compliance

- **RULES.md "Module Services must be stateless"** — does not apply. `ClockTickService`, `HeartRateTickService`, and `SwitchableTickService` are infrastructure adapters implementing the package-declared `ITickService` shape; they are not the "Service" rule target (that rule covers concrete `IXxxService` implementations like `BreathSessionService`, which are unaffected here).
- **RULES.md "Never add module-specific state to App.dart"** — no `App.dart` changes; the plan reuses the existing `activeRrSource` field added in milestone 2.
- **RULES.md "Dependencies via constructor"** — `clock` and `heart` are both passed into `SwitchableTickService` via named-required constructor parameters; `activeRrSource` is passed into `HeartRateTickService` the same way. Compliant.
- **ARCHITECTURE.md module-boundary contract** — `BreathModule.buildSession()` remains the documented assembly point; concrete tick services live in `lib/BreathModule/`, the package only sees the `ITickService` interface. No leak of domain models into the package.

## Behavioural identity (per plan claim)

The plan asserts behaviour is unchanged in this milestone. Verified:

1. `SwitchableTickService` starts on `TickSource.timer` and immediately attaches `_clock.tickStream.listen(_tickController.add)`. The facade's `tickStream` therefore re-emits every clock tick at the same cadence as before.
2. `ClockTickService.simulateTick()` is called via cascade on the `ClockTickService()` constructor result before `SwitchableTickService` is constructed — order is the same as the previous single-line form.
3. There is no public API today that calls `trySwitchTo(TickSource.heartbeat)`. The facade stays on the clock for the entire session lifetime.
4. Heart subscription side-effects: `HeartRateTickService` subscribes to `ActiveRrSource.stream` immediately. Each RR interval still synthesises a `TickData` into `HeartRateTickService._tickController`, but **nothing reads that stream** — `SwitchableTickService`'s `_activeSub` is attached to the clock and never resubscribes to heart. The heart-derived ticks accumulate as no-ops on a broadcast controller with no listeners (dropped on the floor — standard broadcast behaviour). No memory build-up, no observable side-effect.
5. The auto-fallback watchdog (`_healthSub`) only acts when `_activeSource == TickSource.heartbeat`. It will receive every `hasActiveSourceStream` event from the start (because `ActiveRrSource` uses a `BehaviorSubject` and the watchdog will receive at least the seeded `false`), but the guard at `SwitchableTickService.dart:17` short-circuits — no source switch.

## Issues found

None — code, plan, and runtime-state checks all align.

## Minor observations (non-blocking)

1. **Import ordering** — the two new imports are inserted between `ClockTickService.dart` and `Core/BreathModuleStateChannel.dart`. The existing file is grouped but not strictly alphabetical (`BreathSessionCoordinator.dart` already sits after `BreathSessionListCoordinator.dart`), so the new placement matches the file's local convention. No `dart format` / `import_sorter` rule appears to govern the file.

2. **Session lifetime cost** — each `buildSession()` call now allocates one `HeartRateTickService`, one `SwitchableTickService`, two `StreamController`s, and attaches one `ActiveRrSource.stream` listener plus one `ActiveRrSource.hasActiveSourceStream` listener. All released on VM dispose via the dispose chain. No leak; the cost is negligible.

3. **No-listener heart ticks during clock mode** — described above in point (4). Acceptable; this is the design intent so that flipping to heart in milestone 6 yields the next RR-driven tick with no warm-up.

## Verdict

REVIEW_PASS
