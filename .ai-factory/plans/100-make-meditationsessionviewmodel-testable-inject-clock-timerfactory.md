# Plan: Make `MeditationSessionViewModel` testable: inject Clock + TimerFactory

## Context
Make `MeditationSessionViewModel` unit-testable by injecting the time source and the periodic-timer constructor, so `elapsedSeconds = now − startedAt` wall-clock behavior can be asserted under fake time without real seconds passing.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Inject seams

- [x] **Task 1: Add `clock` and `timerFactory` constructor parameters**
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  Add two optional named constructor parameters with defaults, following the exact pattern used in `lib/Biometrics/ActiveRrSource.dart` (`DateTime Function() clock = DateTime.now` stored as a private `_clock` field via the initializer list) and `lib/Core/Grpc/GrpcConnectionManager.dart` (timer factory default `Timer.new`):
  - `DateTime Function() clock = DateTime.now` → stored as `final DateTime Function() _clock`
  - `Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic` → stored as `final Timer Function(Duration, void Function(Timer)) _timerFactory`

  Updated constructor:
  ```dart
  MeditationSessionViewModel({
    required this.poseId,
    DateTime Function() clock = DateTime.now,
    Timer Function(Duration, void Function(Timer)) timerFactory = Timer.periodic,
  })  : _clock = clock,
        _timerFactory = timerFactory;

  final String poseId;
  final DateTime Function() _clock;
  final Timer Function(Duration, void Function(Timer)) _timerFactory;
  ```
  Keep all other fields (`_stateController`, `elapsedSeconds`, `_timer`, `_startedAt`) unchanged. The defaults make this a non-breaking change — existing `MeditationSessionViewModel(poseId: ...)` call sites keep working.

- [x] **Task 2: Route `start()` through the injected seams** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  In `start()`, replace the two hardcoded `DateTime.now()` calls with `_clock()` and the inline `Timer.periodic(...)` with `_timerFactory(...)`. Behavior must stay identical (wall-clock delta, not an accumulator):
  ```dart
  void start() {
    _startedAt = _clock();
    elapsedSeconds.value = 0;
    _timer = _timerFactory(const Duration(seconds: 1), (_) {
      elapsedSeconds.value = _clock().difference(_startedAt!).inSeconds;
    });
    state = state.copyWith(status: MeditationSessionStatus.active);
  }
  ```
  Leave `stop()`, `build()`, the `state` setter, and disposal logic untouched.

- [x] **Task 3: Confirm wiring/instantiation sites are unaffected** (depends on Task 2)
  Files: meditation module assembly point (search for `MeditationSessionViewModel(` and `meditationSessionViewModelProvider` under `lib/` and `packages/meditation_module/`)
  Verify every existing instantiation only passes `poseId` and therefore picks up the new defaults — no production wiring change is required. If any call site exists, leave it as-is. Run `flutter analyze` on `packages/meditation_module` to confirm the refactor compiles with no new warnings.
