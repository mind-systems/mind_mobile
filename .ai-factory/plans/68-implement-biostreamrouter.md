# Plan: Implement `BioStreamRouter`

## Context
Introduce `lib/Biometrics/BioStreamRouter.dart` — the merge point between capability sources (`IHeartRateSource`, `IRrIntervalSource`, `IEegBandsSource`, `IEmotionsSource`, `IMotionSource`) and the downstream `BiometricBatcher`. Per-capability registration, no client-side dedup (every sample already carries its `source` tag), a lazy broadcast `Rx.merge` of all registered streams mapped through the appropriate `BioSample.from*` factory.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Router implementation

- [x] **Task 1: Create `BioStreamRouter` class**
  Files: `lib/Biometrics/BioStreamRouter.dart`
  Create a new file that defines `class BioStreamRouter`. Imports needed:
  - `dart:async`
  - `package:rxdart/rxdart.dart`
  - `BioSample.dart`
  - `IHeartRateSource.dart`
  - `IRrIntervalSource.dart`
  - `IEegBandsSource.dart`
  - `IEmotionsSource.dart`
  - `IMotionSource.dart`

  Declare five private final per-capability source lists, initialized to empty `[]`:
  - `final List<IHeartRateSource> _heartRates = [];`
  - `final List<IRrIntervalSource> _rrIntervals = [];`
  - `final List<IEegBandsSource> _eegBands = [];`
  - `final List<IEmotionsSource> _emotions = [];`
  - `final List<IMotionSource> _motions = [];`

  Declare the cached merged stream slot: `Stream<BioSample>? _merged;`

- [x] **Task 2: Add `register*` methods**
  Files: `lib/Biometrics/BioStreamRouter.dart`
  Add one public registration method per capability:
  - `void registerHeartRateSource(IHeartRateSource source)`
  - `void registerRrIntervalSource(IRrIntervalSource source)`
  - `void registerEegBandsSource(IEegBandsSource source)`
  - `void registerEmotionsSource(IEmotionsSource source)`
  - `void registerMotionSource(IMotionSource source)`

  Each method appends `source` to its corresponding list and then sets `_merged = null` to invalidate the cached merged stream. No `StateError` on re-registration, no dedup — every register call just appends. The `source` tag carried inside each `BioSample.data['source']` is what the server uses to distinguish origins.

- [x] **Task 3: Add lazy `samples` getter**
  Files: `lib/Biometrics/BioStreamRouter.dart`
  Add a public lazy getter `Stream<BioSample> get samples`. On first read (and on first read after any cache invalidation), build a `<Stream<BioSample>>[]` list by mapping each registered source through the matching `BioSample.from*` factory:
  - heart-rate sources → `s.cardioStream.map(BioSample.fromCardio)`
  - rr sources → `s.rrStream.map(BioSample.fromRr)`
  - eeg sources → `s.nfbStream.map(BioSample.fromNfb)`
  - emotions sources → `s.emotionsStream.map(BioSample.fromEmotions)`
  - motion sources → `s.motionStream.map(BioSample.fromMotion)`

  Empty capability lists contribute nothing (collection-for loops just produce no entries). Build the merged stream via `Rx.merge(streams).asBroadcastStream()`, store it in `_merged`, and return it. On subsequent reads return the cached `_merged` directly (early return when non-null). The match between specification snippet in `.ai-factory/notes/28-biometric-stream-pipeline.md` Milestone 6 lines 209–222 should be exact.

- [x] **Task 4: Document register-before-subscribe invariant in dartdoc**
  Files: `lib/Biometrics/BioStreamRouter.dart`
  Add class-level dartdoc on `BioStreamRouter` explaining what it does (per-capability source registration, merged broadcast stream, no client-side dedup because each sample carries its `source` tag). Add a dartdoc block on the `samples` getter explaining:
  - The merged broadcast stream is constructed lazily on first read.
  - Capabilities with no registered sources are omitted from the merge.
  - Multiple sources for the same capability (e.g. Neiry + future Garmin both supplying HR) are merged in parallel; the server is responsible for any comparison, averaging, or artifact-rejection policy.
  - **Invariant:** register every source BEFORE the first subscriber reads `samples`. After the first read the merged stream is cached; subsequent `register*` calls invalidate the cache but already-subscribed consumers stay bound to the old merge and will not see the newly added source. `App.initialize()` honors this naturally because all `register*` calls happen before `BiometricBatcher` is constructed and subscribes.

  Keep the dartdoc tight — the prose in note 28 §Milestone 6 is the canonical reference; the class doc should be a short summary, not a paste of the note.

<!-- orchestrator-sessions
planner: d3e9cc6c-71fa-40e9-aec0-a1f06ceefdc6
elapsed: 395
implementer: 5e0f4227-845e-43db-ae06-ebeef7e15841
-->
