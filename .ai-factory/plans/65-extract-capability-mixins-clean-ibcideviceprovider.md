# Plan: Extract capability mixins + clean `IBciDeviceProvider`

## Context
Split per-stream capabilities (HR, RR, EEG bands, emotions, motion) out of `IBciDeviceProvider` into five small capability interfaces under `lib/Biometrics/`, leaving the provider with only device-class concerns (scan / connect / calibration / battery / signal quality). `NeiryBciProvider` then implements all six interfaces and gains brand-new RR and MEMS subscriptions; `BciDeviceManager` gains three capability sources via the constructor (HR / NFB / emotions only — RR and motion bypass the manager entirely since no UI consumes them). Spec source: `.ai-factory/notes/27-biometrics-refactor.md` "Milestone 3".

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: New capability interfaces under `lib/Biometrics/`

- [x] **Task 1: Create `IHeartRateSource` interface**
  Files: `lib/Biometrics/IHeartRateSource.dart`
  Declare `abstract interface class IHeartRateSource` with a single getter `Stream<CardioData> get cardioStream;`. Import `Models/CardioData.dart` (relative). One-purpose interface — keeps HR-only sources (Apple Health aggregates, summary watches) able to implement HR without RR.

- [x] **Task 2: Create `IRrIntervalSource` interface**
  Files: `lib/Biometrics/IRrIntervalSource.dart`
  Declare `abstract interface class IRrIntervalSource` with `Stream<RrInterval> get rrStream;`. Import `Models/RrInterval.dart` (relative). Kept separate from `IHeartRateSource` because some HR sources never expose per-beat intervals.

- [x] **Task 3: Create `IEegBandsSource` interface**
  Files: `lib/Biometrics/IEegBandsSource.dart`
  Declare `abstract interface class IEegBandsSource` with `Stream<BciNfbData> get nfbStream;`. Import via package path: `import 'package:mind/Bci/Models/BciNfbData.dart';` — `BciNfbData` stays under `lib/Bci/Models/` because it is an EEG-classifier output by definition.

- [x] **Task 4: Create `IEmotionsSource` interface**
  Files: `lib/Biometrics/IEmotionsSource.dart`
  Declare `abstract interface class IEmotionsSource` with `Stream<BciEmotionsData> get emotionsStream;`. Import via package path: `import 'package:mind/Bci/Models/BciEmotionsData.dart';`. Same rationale as `BciNfbData`.

- [x] **Task 5: Create `IMotionSource` interface**
  Files: `lib/Biometrics/IMotionSource.dart`
  Declare `abstract interface class IMotionSource` with `Stream<MotionData> get motionStream;`. Import `Models/MotionData.dart` (relative). Document inline that one emission represents one sample — provider unrolls SDK batches into per-sample emissions.

### Phase 2: Trim `IBciDeviceProvider` to device-class concerns

- [x] **Task 6: Remove capability getters from `IBciDeviceProvider`** (depends on Tasks 1, 3, 4)
  Files: `lib/Bci/IBciDeviceProvider.dart`
  Delete the three getters `cardioStream`, `nfbStream`, `emotionsStream` and their doc comments. Remove the now-unused imports: `package:mind/Biometrics/Models/CardioData.dart`, `Models/BciEmotionsData.dart`, `Models/BciNfbData.dart`. Surviving surface: `scan()`, `connect()`, `disconnect()`, `connectionStateStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`, `startCalibration()`, `dispose()`. Do not touch the class-level doc block.

### Phase 3: `NeiryBciProvider` — implement five capability interfaces, add RR + MEMS

- [x] **Task 7: Declare new interfaces on `NeiryBciProvider`** (depends on Tasks 1–5, 6)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Change `class NeiryBciProvider implements IBciDeviceProvider {` to
  `class NeiryBciProvider implements IBciDeviceProvider, IHeartRateSource, IRrIntervalSource, IEegBandsSource, IEmotionsSource, IMotionSource {`.
  Add the five new imports near the existing `IBciDeviceProvider` import: `package:mind/Biometrics/IHeartRateSource.dart`, `package:mind/Biometrics/IRrIntervalSource.dart`, `package:mind/Biometrics/IEegBandsSource.dart`, `package:mind/Biometrics/IEmotionsSource.dart`, `package:mind/Biometrics/IMotionSource.dart`. Also add `package:mind/Biometrics/Models/RrInterval.dart` and `package:mind/Biometrics/Models/MotionData.dart` (needed for the new controllers/handlers below). The existing three getter bodies (`cardioStream`, `nfbStream`, `emotionsStream`) already satisfy the matching capability interfaces — leave them as-is.

- [x] **Task 8: Add RR-interval controller, getter, subscription, handler** (depends on Task 7)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Add field next to the other broadcast controllers: `final _rrController = StreamController<RrInterval>.broadcast();`.
  - Add subscription field next to `_cardioSub`: `StreamSubscription<neiry.RRInterval>? _rrSub;`.
  - Add getter (annotate `@override`): `Stream<RrInterval> get rrStream => _rrController.stream;`.
  - In `_subscribeDeviceStreams()`, after the existing `_cardioSub` block, add:
    ```dart
    _rrSub = _cardioClassifier!.rrStream.listen(
      _onRrInterval,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: rrStream error: $e'),
    );
    ```
  - Add handler:
    ```dart
    void _onRrInterval(neiry.RRInterval rr) {
      _rrController.add(RrInterval(
        intervalMs: rr.intervalMs,
        timestamp: rr.timestamp,
        isArtifact: rr.isArtifact,
        source: SensorSource.neiry,
      ));
    }
    ```
    Pass `isArtifact` through verbatim; do not filter — server decides. Use `rr.timestamp` from the SDK, never `DateTime.now()`.
  - In `_cancelDeviceSubscriptions()`, add cancel/null pair for `_rrSub` next to `_cardioSub`.
  - In `_doDispose()`, add `_rrController.close();` next to `_cardioController.close();`.

- [x] **Task 9: Add MEMS (motion) classifier, controller, getter, subscription, batch handler** (depends on Task 7)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Add controller: `final _motionController = StreamController<MotionData>.broadcast();`.
  - Add classifier and subscription fields next to the other classifiers (MEMS, unlike the others, requires explicit `dispose()`, so we hold a reference):
    ```dart
    neiry.MEMSClassifier? _memsClassifier;
    StreamSubscription<List<neiry.MemsSample>>? _memsSub;
    ```
  - Add getter (annotate `@override`): `Stream<MotionData> get motionStream => _motionController.stream;`.
  - In `_subscribeDeviceStreams()`, after the existing classifier subscriptions, construct and subscribe MEMS:
    ```dart
    _memsClassifier = neiry.MEMSClassifier(_device!);
    _memsSub = _memsClassifier!.memsStream.listen(
      _onMemsBatch,
      onError: (Object e) =>
          logPrint('NeiryBciProvider: memsStream error: $e'),
    );
    ```
  - Add batch-unrolling handler — emit one `MotionData` per `MemsSample`, preserving each sample's SDK-supplied timestamp:
    ```dart
    void _onMemsBatch(List<neiry.MemsSample> batch) {
      for (final s in batch) {
        _motionController.add(MotionData(
          accelerometer: s.accelerometer,
          gyroscope: s.gyroscope,
          timestamp: s.timestamp,
          source: SensorSource.neiry,
        ));
      }
    }
    ```
  - In `_cancelDeviceSubscriptions()`, cancel and null `_memsSub`. Then, immediately after the existing per-classifier `dispose()` try/catch blocks, add:
    ```dart
    try {
      await _memsClassifier?.dispose();
    } catch (e) {
      logPrint('NeiryBciProvider: mems dispose error: $e');
    }
    _memsClassifier = null;
    ```
    MEMS is the exception — other classifiers are released indirectly via `_device!.dispose()`, but MEMS leaks native resources without an explicit call.
  - In `_doDispose()`, add `_motionController.close();` next to the other controller closes.

### Phase 4: Wire capabilities through `BciDeviceManager`

- [x] **Task 10: Add three capability-source fields and constructor parameters to `BciDeviceManager`** (depends on Tasks 1, 3, 4, 6)
  Files: `lib/Bci/BciDeviceManager.dart`
  - Add new imports: `package:mind/Biometrics/IHeartRateSource.dart`, `package:mind/Biometrics/IEegBandsSource.dart`, `package:mind/Biometrics/IEmotionsSource.dart`. Keep the existing `CardioData` import.
  - Add three `final` fields alongside `_provider` and `_repository`:
    ```dart
    final IHeartRateSource _cardioSource;
    final IEegBandsSource _eegBandsSource;
    final IEmotionsSource _emotionsSource;
    ```
  - Extend the constructor to require all three (keep `provider` and `repository`):
    ```dart
    BciDeviceManager({
      required IBciDeviceProvider provider,
      required IHeartRateSource cardioSource,
      required IEegBandsSource eegBandsSource,
      required IEmotionsSource emotionsSource,
      required BciDeviceRepository repository,
    })  : _provider = provider,
          _cardioSource = cardioSource,
          _eegBandsSource = eegBandsSource,
          _emotionsSource = emotionsSource,
          _repository = repository {
      _subscribeProviderStreams();
    }
    ```
  - Update the three existing capability getters to delegate to the new sources instead of `_provider`:
    ```dart
    Stream<BciNfbData> get nfbStream => _eegBandsSource.nfbStream;
    Stream<CardioData> get cardioStream => _cardioSource.cardioStream;
    Stream<BciEmotionsData> get emotionsStream => _emotionsSource.emotionsStream;
    ```
  - Do **not** add `IRrIntervalSource` or `IMotionSource` parameters. Both bypass the manager: no UI consumes per-beat intervals or per-sample motion, and routing them through `BciNotifierEvent` would pollute the sealed union for no consumer. They will be wired directly into `BioStreamRouter` in a later milestone.

- [x] **Task 11: Pass the single `NeiryBciProvider` instance into all four `BciDeviceManager` roles in `App.dart`** (depends on Task 10)
  Files: `lib/Core/App.dart`
  Update the `BciDeviceManager(...)` construction (currently on line 152) so the same `bciProvider` local is passed as four parameters:
  ```dart
  final bciDeviceManager = BciDeviceManager(
    provider: bciProvider,
    cardioSource: bciProvider,
    eegBandsSource: bciProvider,
    emotionsSource: bciProvider,
    repository: bciRepository,
  );
  ```
  Do not add new App fields — `bciProvider` is already a local in `initialize()`. Follow the existing formatting style (multi-line named-argument call) used elsewhere in `initialize()`.

## Commit Plan
- **Commit 1** (after tasks 1–5): "Add capability source interfaces for biometric streams"
- **Commit 2** (after tasks 6–9): "Split capabilities out of IBciDeviceProvider and add RR + motion sources to NeiryBciProvider"
- **Commit 3** (after tasks 10–11): "Inject capability sources into BciDeviceManager and wire from App"

<!-- orchestrator-sessions
planner: 97d2ac75-834c-4107-848e-62a4b3f6dd11
elapsed: 943
implementer: 7b7db53d-ac06-4899-83a8-66595e4fe9a4
-->
