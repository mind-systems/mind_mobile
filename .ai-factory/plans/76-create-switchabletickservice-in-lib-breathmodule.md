## Plan: Create `SwitchableTickService` in `lib/BreathModule/`

## Context
Introduce the `SwitchableTickService` facade that owns both `ClockTickService` and `HeartRateTickService` behind a single `ITickService`, plus the two new interface members (`sourceChanges`, `trySwitchTo`) that ship atomically so the contract stays complete across every milestone. The Switchable is the breath-side mediator: it forwards ticks from one active child onto a single broadcast stream, exposes a typed source-change stream, and wires auto-fallback from heartbeat → timer when all RR sources go silent. No `BreathModule.buildSession()` wiring and no `BreathViewModel` changes in this milestone — those land in Phase 22 M5 and M6.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Extend the `ITickService` interface

- [x] **Task 1: Add `sourceChanges` and `trySwitchTo` to `ITickService`**
  Files: `packages/breath_module/lib/src/ITickService.dart`
  Extend the abstract class with two new members (alongside the existing `tickStream`, `source`, `dispose`):
  ```dart
  Stream<TickSource> get sourceChanges;
  bool trySwitchTo(TickSource target);
  ```
  Keep the file's existing import (`CommonModels/TickSource.dart`) — `TickSource` is already in scope. Do not add a default implementation; concrete subclasses provide their own. The contract for non-switchable implementations is documented through behaviour (no-op stream + always `false`) — keep the abstract declaration minimal, no dartdoc beyond a brief one-liner explaining intent on each member.

- [x] **Task 2: Implement the new interface members in `ClockTickService`** (depends on Task 1)
  Files: `lib/BreathModule/ClockTickService.dart`
  Add the two `@override` members at the bottom of the class, both as no-ops because `ClockTickService` is single-source and never switches:
  ```dart
  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;
  ```
  No constructor changes, no new fields, no new imports — `TickSource` is already in scope via the existing `breath_module` show clause. Keep the existing import style intact.

- [x] **Task 3: Implement the new interface members in `HeartRateTickService`** (depends on Task 1)
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Mirror Task 2 — add the same two no-op overrides at the bottom of the class. Heart is also single-source from its own perspective (it just forwards `ActiveRrSource.stream`); the multi-source facade is `SwitchableTickService`'s job, not this one. Do not touch `hasActiveSource` / `hasActiveSourceStream` proxies — they stay as-is for `SwitchableTickService` to consume.
  ```dart
  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;
  ```

- [x] **Task 3b: Update in-tree test fakes that implement `ITickService`** (depends on Task 1)
  Files:
  - `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` (class `FakeTickService`)
  - `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` (class `FakeTickService`)
  - `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` (class `_FakeTickService`)
  - `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` (class `_FakeTickService`)
  - `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` (class `_ManualTickService`)

  Each of these is a private/local fake in the test tree that directly `implements ITickService`. Once Task 1 lands, the interface has two new abstract members; without the matching overrides every fake fails to compile and `flutter test` (and the wider build) breaks immediately at Commit 1. Add the same two no-op overrides to **every** listed fake — identical to Tasks 2/3 — preserving each file's existing import style (most already import `breath_module` with a `show` clause that includes `TickSource`; if any fake imports only `ITickService`/`TickData`, extend the existing `show` clause to also include `TickSource` rather than adding a separate import):
  ```dart
  @override
  Stream<TickSource> get sourceChanges => const Stream.empty();

  @override
  bool trySwitchTo(TickSource target) => false;
  ```
  No other test changes — do not alter assertions, fake behaviour, or test setup. This task exists solely to keep the test tree compiling alongside the interface extension; it is not a testing-policy violation (the project rule "Settings → Testing: no" governs *authoring new tests*, not letting existing test files fail to compile).

### Phase 2: Add `SwitchableTickService`

- [x] **Task 4: Create `lib/BreathModule/SwitchableTickService.dart` with constructor + fields** (depends on Tasks 2, 3, 3b)
  Files: `lib/BreathModule/SwitchableTickService.dart`
  Create the new file as a sibling of `ClockTickService.dart` and `HeartRateTickService.dart`. Mirror their import style: `import 'package:breath_module/breath_module.dart' show ITickService, TickData, TickSource;` plus relative imports for the two children (`import 'ClockTickService.dart';`, `import 'HeartRateTickService.dart';`) and `dart:async` for the controllers/subscriptions. Declare:
  ```dart
  class SwitchableTickService implements ITickService {
    SwitchableTickService({
      required ClockTickService clock,
      required HeartRateTickService heart,
    })  : _clock = clock,
          _heart = heart {
      _activeSource = TickSource.timer;
      _activeSub = _clock.tickStream.listen(_tickController.add);
      _healthSub = _heart.hasActiveSourceStream.listen((hasActive) {
        if (!hasActive && _activeSource == TickSource.heartbeat) {
          _switchInternal(TickSource.timer);
        }
      });
    }

    final ClockTickService _clock;
    final HeartRateTickService _heart;

    final StreamController<TickData> _tickController =
        StreamController<TickData>.broadcast();
    final StreamController<TickSource> _sourceChangesController =
        StreamController<TickSource>.broadcast();

    late TickSource _activeSource;
    StreamSubscription<TickData>? _activeSub;
    StreamSubscription<bool>? _healthSub;
  }
  ```
  Key contract points to preserve while writing this scaffold:
  - `_activeSource` defaults to `TickSource.timer` — sessions always start on clock; user opts into heartbeat explicitly.
  - **Constructor ordering matters:** `_activeSource = TickSource.timer;` MUST run before `_healthSub = _heart.hasActiveSourceStream.listen(...)`. `hasActiveSourceStream` is a `BehaviorSubject.stream` and fires immediately with its seeded value (initially `false`); the `_activeSource == TickSource.heartbeat` guard then correctly suppresses a spurious initial fallback. Do not reorder.
  - The clock subscription is attached eagerly in the constructor so the facade is wired end-to-end on construction; once M5 wires `clock.simulateTick()` into `buildSession()`, ticks flow immediately with zero first-tick lag on switch-back from heart. In this milestone in isolation no caller invokes `simulateTick()`, so the eager subscription is a pipe with no producer yet — that's expected (M4 doesn't wire the facade anywhere).
  - The `_healthSub` listener wires auto-fallback here, not in the VM — the spec explicitly centralises this so the VM's `sourceChanges` subscription handles manual toggles and watchdog fallback through one code path.
  - Use a single broadcast `_tickController` so downstream consumers (state machine, sound coordinator) never resubscribe across switches.

- [x] **Task 5: Implement `ITickService` overrides + `sourceChanges` getter**
  Files: `lib/BreathModule/SwitchableTickService.dart`
  Add the four public read-only members required by the interface plus the new `sourceChanges` getter:
  ```dart
  @override
  Stream<TickData> get tickStream => _tickController.stream;

  @override
  TickSource get source => _activeSource;

  @override
  Stream<TickSource> get sourceChanges => _sourceChangesController.stream;
  ```
  `sourceChanges` is the single source of truth that `BreathViewModel` will subscribe to in Phase 22 M6 to mirror `state.tickSource`. Do not emit a seed value — late subscribers do not need the current source; they query `source` directly when they need a snapshot.

- [x] **Task 6: Implement `trySwitchTo()` and the internal `_switchInternal()` helper**
  Files: `lib/BreathModule/SwitchableTickService.dart`
  Add the public `trySwitchTo` method and the internal `_switchInternal` worker. Behaviour contract:
  - `trySwitchTo(target)` returns `true` when the switch is performed or the target is already active.
  - It returns `false` **only** when `target == TickSource.heartbeat && !_heart.hasActiveSource` — the caller (`BreathViewModel` in M6) inspects this boolean and shows the "connect a heart sensor" alert.
  - `_switchInternal(target)` cancels the current `_activeSub`, swaps `_activeSource`, subscribes the new child's `tickStream` into `_tickController`, and emits the new value on `_sourceChangesController`.
  ```dart
  @override
  bool trySwitchTo(TickSource target) {
    if (target == _activeSource) return true;
    if (target == TickSource.heartbeat && !_heart.hasActiveSource) {
      return false;
    }
    _switchInternal(target);
    return true;
  }

  void _switchInternal(TickSource target) {
    _activeSub?.cancel();
    _activeSource = target;
    final ITickService next = target == TickSource.timer ? _clock : _heart;
    _activeSub = next.tickStream.listen(_tickController.add);
    _sourceChangesController.add(target);
  }
  ```
  Switching to `timer` always succeeds (clock has no liveness requirement). The internal helper is reused by both the manual path (`trySwitchTo`) and the auto-fallback path (constructor's `_healthSub` handler) — keep it private and synchronous; never call it from outside the class. `_activeSub?.cancel()` returns a future that is intentionally not awaited; any in-flight `TickData` already queued by the previous child cannot land on the closed-over `_tickController.add` callback after cancel returns, so the brief async tail is harmless.

- [x] **Task 7: Implement `dispose()` (cancels subs, closes controllers, propagates to children)**
  Files: `lib/BreathModule/SwitchableTickService.dart`
  Owning semantics: `SwitchableTickService` is the only consumer of the two child services in the breath session — the VM only ever sees the facade. So `dispose()` cancels its own subscriptions, closes both controllers, then propagates `dispose()` down to both children (so each child cancels its own subscription to `ActiveRrSource` / its own `Timer.periodic`, but neither child disposes the upstream `ActiveRrSource`, which is owned by `App.shared`).
  ```dart
  @override
  void dispose() {
    _activeSub?.cancel();
    _healthSub?.cancel();
    _tickController.close();
    _sourceChangesController.close();
    _clock.dispose();
    _heart.dispose();
  }
  ```
  Order matters: cancel `_activeSub` before propagating `_heart.dispose()` / `_clock.dispose()`. Each child's `dispose()` closes its own `tickStream` controller and would otherwise push a `done` to the facade's already-active forwarding subscription; having cancelled `_activeSub` first keeps that teardown silent. Do not `await` close calls — `StreamController.close()` returns a future but `dispose` is sync per the interface signature (mirrors `ClockTickService.dispose()` / `HeartRateTickService.dispose()`).

## Commit Plan
- **Commit 1** (after tasks 1, 2, 3, 3b): "Extend ITickService with sourceChanges and trySwitchTo no-ops"
  Scope: `packages/breath_module/lib/src/ITickService.dart`, `lib/BreathModule/ClockTickService.dart`, `lib/BreathModule/HeartRateTickService.dart`, and the five test files listed in Task 3b. The five test fakes ship in this same commit so the build (and `flutter test`) stays green after Commit 1 — without them the interface extension is a compile break.
- **Commit 2** (after tasks 4-7): "Add SwitchableTickService facade with auto-fallback wiring"
  Scope: `lib/BreathModule/SwitchableTickService.dart`.

## Notes

- **Scope discipline:** this milestone touches exactly nine files — the interface, the two existing concrete services, the new `SwitchableTickService.dart`, and the five in-tree test fakes that implement `ITickService`. No edits to `BreathModule.buildSession()`, `BreathViewModel`, `BreathSessionScreen`, `App.dart`, or any l10n / docs. Wiring lands in Phase 22 M5; VM/UI wiring lands in M6/M7.
- **Single source of truth for the active source:** `_activeSource` is mutated only through `_switchInternal`; the public `source` getter and `sourceChanges` stream both reflect that field. The VM (M6) will subscribe to `sourceChanges` to mirror it into `state.tickSource` — do not anticipate that subscription here.
- **Default state:** facade starts on `TickSource.timer` with the clock subscription already live, so once M5 wires `clock.simulateTick()` consumers receive ticks immediately on construction without an explicit start call.
- **Auto-fallback path:** centralised in the constructor's `_healthSub` listener — when `_heart.hasActiveSourceStream` emits `false` while currently on heartbeat, snap back to timer via `_switchInternal`. This guarantees a single sync point for both manual and automatic switches (the VM does not need its own fallback logic). Auto-fallback is one-shot per silence transition; re-arming heartbeat is always a user-initiated tap, consistent with the spec.
- **Ownership boundary:** `SwitchableTickService` owns the two children's lifecycles (dispose propagates downward), but `HeartRateTickService.dispose()` already documents that it does NOT dispose its upstream `ActiveRrSource` (owned by `App.shared`). That contract is preserved.
- **Rule compliance:** No state lands in `App.dart` (concrete construction happens in `BreathModule.buildSession()` per M5). All dependencies are injected via constructor (`clock` and `heart`); no class wires itself by calling another's methods externally.
- **Reference spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` — "Milestone 4 — `SwitchableTickService`".

<!-- orchestrator-sessions
planner: e2a92369-d785-44a3-b3b1-c6ddadfb7c2a
elapsed: 1031
implementer: 28ed011a-3acd-48a5-84fd-68ca4ab60ecb
-->
