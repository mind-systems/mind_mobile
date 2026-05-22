# Plan: Wire NfbClassifier, CardioClassifier, EmotionsClassifier in NeiryBciProvider

## Context
Extend `NeiryBciProvider` and `IBciDeviceProvider` to expose three new domain streams (`nfbStream`, `cardioStream`, `emotionsStream`) backed by the corresponding `neiry_kit` classifiers, so downstream consumers (BciDeviceManager → BciNotifier → BciDataService) can render NFB bands, cardio metrics, and emotion classifier outputs on the upcoming BCI Data screen.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Interface extension

- [x] **Task 1: Add three new stream getters to `IBciDeviceProvider`**
  Files: `lib/Bci/IBciDeviceProvider.dart`
  Add three abstract getters to the interface, mirroring the style/comment density of the existing `signalQualityStream` and `batteryStream`:
  ```dart
  /// Emits NFB band amplitudes (delta/theta/alpha/smr/beta) per sample.
  Stream<BciNfbData> get nfbStream;

  /// Emits cardio metrics (heart rate + availability/artifact flags) per sample.
  Stream<BciCardioData> get cardioStream;

  /// Emits high-level emotion classifier outputs per sample.
  Stream<BciEmotionsData> get emotionsStream;
  ```
  Add the matching imports for `BciNfbData`, `BciCardioData`, `BciEmotionsData` from `Models/`. The domain model classes already exist in `lib/Bci/Models/` — do not modify them.

### Phase 2: Provider wiring

- [x] **Task 2: Add classifier fields, controllers, subscriptions, and getters to `NeiryBciProvider`** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Import `Models/BciNfbData.dart`, `Models/BciCardioData.dart`, `Models/BciEmotionsData.dart`.
  - Add nullable classifier fields next to `_device`:
    ```dart
    NfbClassifier? _nfbClassifier;
    CardioClassifier? _cardioClassifier;
    EmotionsClassifier? _emotionsClassifier;
    ```
  - Add three new `StreamController.broadcast()` fields next to the existing controllers:
    ```dart
    final _nfbController = StreamController<BciNfbData>.broadcast();
    final _cardioController = StreamController<BciCardioData>.broadcast();
    final _emotionsController = StreamController<BciEmotionsData>.broadcast();
    ```
  - Add three `StreamSubscription` fields next to the existing subs:
    ```dart
    StreamSubscription<NfbUserState>? _nfbSub;
    StreamSubscription<CardioData>? _cardioSub;
    StreamSubscription<EmotionsStates>? _emotionsSub;
    ```
  - Implement the three new interface getters in the existing "Stream getters" section:
    ```dart
    @override Stream<BciNfbData> get nfbStream => _nfbController.stream;
    @override Stream<BciCardioData> get cardioStream => _cardioController.stream;
    @override Stream<BciEmotionsData> get emotionsStream => _emotionsController.stream;
    ```

- [x] **Task 3: Instantiate classifiers in `connect()` after `_device!.start()`** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Inside the existing `try { await _device!.connect(); await _device!.start(); }` block, immediately after `await _device!.start();` and before the closing `}`, add classifier instantiation:
  ```dart
  _nfbClassifier = NfbClassifier(_device!);
  _cardioClassifier = CardioClassifier(_device!);
  _emotionsClassifier = EmotionsClassifier(_device!);
  ```
  In the `catch` block, after `await _device?.dispose();` and before `_device = null;`, also tear down any partially-created classifiers so a failed start leaves no leaked native handles. Wrap each `dispose()` in its own try/catch (same defensive style as the existing `_device?.disconnect()` swallow) and null the field:
  ```dart
  try { await _nfbClassifier?.dispose(); } catch (_) {}
  try { await _cardioClassifier?.dispose(); } catch (_) {}
  try { await _emotionsClassifier?.dispose(); } catch (_) {}
  _nfbClassifier = null;
  _cardioClassifier = null;
  _emotionsClassifier = null;
  ```

- [x] **Task 4: Subscribe to classifier `stateStream`s in `_subscribeDeviceStreams()`** (depends on Task 3)
  Files: `lib/Bci/NeiryBciProvider.dart`
  After the existing `_batterySub = ...` subscription inside `_subscribeDeviceStreams()`, add three subscriptions following the same `onError` + `logPrint` pattern:
  ```dart
  _nfbSub = _nfbClassifier!.stateStream.listen(
    _onNfbState,
    onError: (Object e) =>
        logPrint('NeiryBciProvider: nfb stateStream error: $e'),
  );
  _cardioSub = _cardioClassifier!.stateStream.listen(
    _onCardioState,
    onError: (Object e) =>
        logPrint('NeiryBciProvider: cardio stateStream error: $e'),
  );
  _emotionsSub = _emotionsClassifier!.stateStream.listen(
    _onEmotionsState,
    onError: (Object e) =>
        logPrint('NeiryBciProvider: emotions stateStream error: $e'),
  );
  ```

- [x] **Task 5: Add three mapping handlers (`_onNfbState`, `_onCardioState`, `_onEmotionsState`)** (depends on Task 4)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add three new private mapping methods next to `_onResistance`, each followed by a short section banner matching the existing `// ── X → Y ──` style. Direct field-to-field mapping (all neiry_kit field names already match domain field names):
  ```dart
  void _onNfbState(NfbUserState s) {
    _nfbController.add(BciNfbData(
      delta: s.delta,
      theta: s.theta,
      alpha: s.alpha,
      smr: s.smr,
      beta: s.beta,
    ));
  }

  void _onCardioState(CardioData c) {
    _cardioController.add(BciCardioData(
      heartRate: c.heartRate,
      metricsAvailable: c.metricsAvailable,
      hasArtifacts: c.hasArtifacts,
    ));
  }

  void _onEmotionsState(EmotionsStates e) {
    _emotionsController.add(BciEmotionsData(
      attention: e.attention,
      relaxation: e.relaxation,
      cognitiveLoad: e.cognitiveLoad,
      cognitiveControl: e.cognitiveControl,
      selfControl: e.selfControl,
    ));
  }
  ```
  The `timestamp` field on the neiry_kit models is intentionally dropped — domain DTOs do not carry it. Do not introduce additional filtering: validity gating (e.g. cardio `metricsAvailable && !hasArtifacts`) is performed downstream in `BciDataService`, per `.ai-factory/notes/24-bci-data-screen.md`.

- [x] **Task 6: Cancel subscriptions and dispose classifiers in `_cancelDeviceSubscriptions()`** (depends on Task 4)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Extend the existing `_cancelDeviceSubscriptions()` so it also tears down the three new subscriptions and disposes the classifiers. Order matters: cancel the Dart-side subscription first, then dispose the native classifier handle, then null the field. Swallow any per-classifier `dispose()` exception with `logPrint` (same defensive style as `_device?.disconnect()` in `disconnect()`):
  ```dart
  await _nfbSub?.cancel();
  _nfbSub = null;
  await _cardioSub?.cancel();
  _cardioSub = null;
  await _emotionsSub?.cancel();
  _emotionsSub = null;

  try { await _nfbClassifier?.dispose(); } catch (e) {
    logPrint('NeiryBciProvider: nfb dispose error: $e');
  }
  _nfbClassifier = null;
  try { await _cardioClassifier?.dispose(); } catch (e) {
    logPrint('NeiryBciProvider: cardio dispose error: $e');
  }
  _cardioClassifier = null;
  try { await _emotionsClassifier?.dispose(); } catch (e) {
    logPrint('NeiryBciProvider: emotions dispose error: $e');
  }
  _emotionsClassifier = null;
  ```
  Because `_cancelDeviceSubscriptions()` is reused by both `disconnect()` and `_doDispose()`, both paths now correctly release the classifiers — no further changes needed in `_doDispose()`.

- [x] **Task 7: Close the three new controllers in `_doDispose()`** (depends on Task 6)
  Files: `lib/Bci/NeiryBciProvider.dart`
  After the existing `_calibrationController.close();` line at the end of `_doDispose()`, add:
  ```dart
  _nfbController.close();
  _cardioController.close();
  _emotionsController.close();
  ```
  Do NOT close them in `disconnect()` — broadcast controllers must stay open across reconnects (matches the existing pattern for `_connectionStateController` etc.).

## Commit Plan
- **Commit 1** (after tasks 1–2): "Extend IBciDeviceProvider with NFB, cardio, and emotions streams"
- **Commit 2** (after tasks 3–7): "Wire NFB, cardio, and emotions classifiers in NeiryBciProvider"

<!-- orchestrator-sessions
planner: b9c45851-f6eb-4384-a29f-db623377a533
implementer: a960b73d-04c2-4593-b520-48875cccd1d8
-->
