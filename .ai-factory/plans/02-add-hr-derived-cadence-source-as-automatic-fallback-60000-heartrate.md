# Plan: Add HR-derived cadence source as automatic fallback (`60000/heartRate`)

## Context
Add a second tick cadence source derived from heart rate (BPM) so that when the RR-interval source goes stale (silence or sustained artifacts) the breathing metronome auto-switches to `60000/heartRate` instead of falling back to the clock — with no user action and no "connect a heart sensor" alert. RR is reclaimed when it revives.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: HR cadence source

- [x] **Task 1: Create `HeartRateTickCadenceSource`**
  Files: `lib/BreathModule/TickCadence/HeartRateTickCadenceSource.dart`
  Implement `ITickCadenceSource` (`lib/BreathModule/TickCadence/ITickCadenceSource.dart`) backed by an injected `IHeartRateSource` (`lib/Biometrics/IHeartRateSource.dart`, exposes `Stream<CardioData> get cardioStream`). Mirror the structure and conventions of the sibling `RrTickCadenceSource.dart`:
  - Constructor takes `IHeartRateSource heartRateSource`, plus `Duration graceWindow = const Duration(seconds: 10)` and `Timer Function(Duration, void Function()) timerFactory = Timer.new` (same testable-injection pattern as `RrTickCadenceSource`).
  - Hold a `BehaviorSubject<int>` (or a broadcast `StreamController<int>`) for `smoothedPeriodMs` and a `BehaviorSubject<bool>.seeded(false)` for `usableChanges`; keep an `int? _currentPeriodMs` snapshot for the synchronous `currentPeriodMs` getter (seed `null` — cold path, no period accepted yet).
  - Subscribe to `heartRateSource.cardioStream`. On each `CardioData`:
    - **Valid** when `metricsAvailable && !hasArtifacts && heartRate > 0`: compute `final periodMs = (60000 / heartRate).round();`, store it as the snapshot, emit it on `smoothedPeriodMs`, set `isUsable = true` (only `add(true)` if currently false), and re-arm the grace timer.
    - **Otherwise** (gap): do nothing — do not emit, do not refresh staleness.
  - **No moving average / SMA** — emit `(60000/heartRate).round()` directly. This is a final decision (BPM is already an SDK-side average; stacking another lags the live heart).
  - **Staleness**: arm a grace timer (via `timerFactory`) on every valid sample; on expiry set `isUsable = false`. Window pinned to **10 s** to match `RrTickCadenceSource`'s grace. Do not stop emitting the last period — coast like the RR source.
  - `isUsable` returns the subject's current value; `usableChanges` and `smoothedPeriodMs` return the seeded subject streams (the contract requires `usableChanges` to be a seeded `BehaviorSubject` stream).
  - `dispose()` cancels the cardio subscription + grace timer and closes the subjects. **Does NOT dispose the injected `IHeartRateSource`** — it is an App-owned singleton (same rule as `RrTickCadenceSource`).
  - Document at class level (matching the doc style of `RrTickCadenceSource`): HR is a cadence source, NOT a synthetic `IRrIntervalSource` injected into `ActiveRrSource`; SDK flags are trusted as-is (no RR cleaning / plausibility filter).

### Phase 2: App surface

- [x] **Task 2: Expose `IHeartRateSource` on `App.shared`**
  Files: `lib/Core/App.dart`
  `App` currently exposes `activeRrSource` and `smoothedRrSource` but no `IHeartRateSource`. The `NeiryBciProvider` (`bciProvider`, created at `App.dart:193`) implements `IHeartRateSource` and is already used as `cardioSource:` for `BciDeviceManager` (`:196`).
  - Add a field `final IHeartRateSource heartRateSource;` next to `smoothedRrSource` (`App.dart:104`).
  - Add `required this.heartRateSource,` to the `App._({...})` constructor, next to `required this.smoothedRrSource,` (`App.dart:137`).
  - Pass `heartRateSource: bciProvider,` in the `shared = App._(...)` block, alongside `smoothedRrSource: smoothedRrSource,` (`App.dart:258`).
  - Add `import 'package:mind/Biometrics/IHeartRateSource.dart';` to the imports.
  - Note: this is an additive infrastructure surface (a domain biometric source singleton), consistent with the existing `activeRrSource`/`smoothedRrSource` fields — not module-specific state.

### Phase 3: Wiring and selector fix

- [x] **Task 3: Register HR cadence as priority-2 in `buildSession()`** (depends on Task 1, Task 2)
  Files: `lib/BreathModule/BreathModule.dart`
  In `BreathModule.buildSession()` replace the current two-line cadence wiring (`BreathModule.dart:35-36`):
  ```dart
  final rrCadence = RrTickCadenceSource(App.shared.smoothedRrSource);
  final hrCadence = HeartRateTickCadenceSource(App.shared.heartRateSource);
  final selector  = TickCadenceSelector([rrCadence, hrCadence]); // index 0 = RR preferred, 1 = HR fallback
  ```
  Add the import `package:mind/BreathModule/TickCadence/HeartRateTickCadenceSource.dart`. Leave the `clock`, `heart`, and `SwitchableTickService` lines unchanged — the selector's aggregate `isUsable` now stays true whenever HR is alive, so the metronome no longer flips to the clock while RR is stale but HR is streaming.

- [x] **Task 4: Resolve the `currentPeriodMs` fallback for two sources** (depends on Task 1)
  Files: `lib/BreathModule/TickCadence/TickCadenceSelector.dart`
  The selector carries `TODO(note-164)` at `currentPeriodMs` (`:53-61`): when no source is usable it unconditionally returns `_sources.first.currentPeriodMs`, which with the HR source added could be `null` (RR cold) even when HR has a snapshot. Update the fallback so that when `_activeSource` is null it returns the first source (in priority order) whose `currentPeriodMs` is non-null, falling back to `_sources.first.currentPeriodMs` only if none have one. Remove the resolved TODO comment.
