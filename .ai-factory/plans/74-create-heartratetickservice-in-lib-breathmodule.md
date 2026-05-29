## Plan: Create `HeartRateTickService` in `lib/BreathModule/`

## Context
Introduce the breath-specific adapter that turns `ActiveRrSource` RR-intervals into the existing `ITickService` contract, so a later milestone can plug it into `SwitchableTickService` and let the breath state machine tick on the heartbeat. Single new file, no wiring into `BreathModule.buildSession()` yet — that happens in Phase 22 M5.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add `HeartRateTickService`

- [x] **Task 1: Create `lib/BreathModule/HeartRateTickService.dart`**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Create the file as a sibling of `lib/BreathModule/ClockTickService.dart`. Mirror its import style for `breath_module` (`import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;`) and use `package:mind/Biometrics/ActiveRrSource.dart` for the cross-folder import (the convention used elsewhere in `lib/` — see `lib/Core/App.dart`, `lib/Bci/NeiryBciProvider.dart`). Declare:
  ```dart
  class HeartRateTickService implements ITickService {
    HeartRateTickService({required ActiveRrSource activeRrSource})
        : _activeRrSource = activeRrSource {
      _sub = _activeRrSource.stream.listen((rr) {
        _tickController.add(TickData(rr.intervalMs));
      });
    }

    final ActiveRrSource _activeRrSource;
    final StreamController<TickData> _tickController = StreamController<TickData>.broadcast();
    StreamSubscription? _sub;
  }
  ```
  Each RR interval maps to exactly one `TickData(rr.intervalMs)` — no smoothing, no rate limiting, no artifact filtering (artifact handling is `ActiveRrSource`'s responsibility per the spec).

- [x] **Task 2: Implement `ITickService` overrides (`tickStream`, `source`)**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Add the two `@override` members required by `ITickService` (see `packages/breath_module/lib/src/ITickService.dart`):
  ```dart
  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => TickSource.heartbeat;
  ```

- [x] **Task 3: Expose `hasActiveSource` / `hasActiveSourceStream` proxies**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Proxy the underlying `ActiveRrSource` availability so the future `SwitchableTickService` (Phase 22 M4) can gate manual switches and trigger auto-fallback without holding a direct reference to `ActiveRrSource`:
  ```dart
  /// Proxy for callers that need to gate UI on source availability.
  bool get hasActiveSource => _activeRrSource.hasActiveSource;

  /// Transitions of [hasActiveSource]. Consumed by [SwitchableTickService] for
  /// auto-fallback when all RR sources go silent.
  Stream<bool> get hasActiveSourceStream => _activeRrSource.hasActiveSourceStream;
  ```
  Do not duplicate or cache the boolean — always delegate to `_activeRrSource` so there is one source of truth.

- [x] **Task 4: Implement `dispose()` (own subscription + controller only)**
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Override `dispose()` to cancel `_sub` and close `_tickController`. Do **not** call `_activeRrSource.dispose()` — `ActiveRrSource` is owned by `App.shared` (constructed in `App.initialize()`, Phase 22 M2) and shared with future cardio-driven consumers; the session-scoped tick service must not tear it down.
  ```dart
  @override
  void dispose() {
    _sub?.cancel();
    _tickController.close();
    // Do NOT dispose _activeRrSource — owned by App, shared with future consumers.
  }
  ```

## Notes

- **Scope discipline:** this milestone only adds the new file. No edits to `BreathModule.buildSession()`, `BreathViewModel`, `App.dart`, or any UI — those land in Phase 22 milestones 4–7.
- **No artifact handling here.** `ActiveRrSource` already logs/forwards artifacts per its own contract; this adapter is intentionally dumb and stateless beyond the subscription.
- **No tests.** Project-wide testing policy is minimal; this milestone explicitly does not request test coverage.
- **Reference spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` — "Milestone 3 — `HeartRateTickService`".

<!-- orchestrator-sessions
planner: 5082772f-b011-47dd-866d-f0e67ff910f0
elapsed: 352
implementer: a8aaab5e-39e6-433d-bce3-d00ef09cad93
-->
