# Plan: A3 · ClassifierFactory port + adapter (behavior-preserving)

## Context
Introduce a narrow `ClassifierFactory`/`ClassifierSet` port + thin neiry adapter so the four channel-backed classifiers (`NfbClassifier`/`CardioClassifier`/`EmotionsClassifier`/`MEMSClassifier`) and their seven streams become an injectable seam — production behavior byte-identical (default = current inline build), a fake `ClassifierSet` injectable for B2's full-L1/teardown coverage.

## Settings
- Testing: yes (one focused test: fake `ClassifierSet`/`ClassifierFactory` injectable + production default untouched)
- Logging: minimal
- Docs: no

## Tasks

This mirrors the A1/A2 seam pattern already in `lib/Bci/Ports/` (`LocatorPort`/`NeiryLocatorAdapter`, `DevicePort`/`NeiryDeviceAdapter`): **narrow port + thin neiry adapter**, the fake implements the port (not the vendor classes), production default = the real adapter.

**Hard guards (apply to every task):**
- Behavior-preserving only. Do not touch the `_teardownComplete` gate, the teardown ordering, or the calibrator (out of scope — provider keeps importing `neiry` for `NfbCalibrator`/`IndividualNfbData`/`CalibrationEvent`).
- Classifier **build order** = `nfb → cardio → emotions → mems` (connect `:172-175`). Classifier **dispose order** = `nfb → cardio → emotions → mems` (`:511-528` / `:567-589`). Both must be preserved exactly — B2 asserts disposal ordering.
- The port exposes **domain-typed** streams (mapping moves into the adapter, consistent with A2 moving resistance/connection-state mapping into `NeiryDeviceAdapter`) so the fake never depends on `neiry`.
- All new neiry imports live ONLY in `NeiryClassifierSet` / `NeiryClassifierFactory` — same rule as the existing adapters.

### Phase 1: Define the ports

- [x] **Task 1: Add `ClassifierSet` port interface**
  Files: `lib/Bci/Ports/ClassifierSet.dart`
  Declare `abstract interface class ClassifierSet` covering exactly the surface the provider consumes: the **seven streams** as domain-typed getters and a throwable `dispose()`. Streams (mapping currently in the provider's `_on*` methods moves into the adapter):
  - `Stream<BciNfbData> get nfbStateStream` (was nfb `stateStream` → `_onNfbState`)
  - `Stream<String> get nfbErrorStream` (was nfb `errorStream`, log-only)
  - `Stream<CardioData> get cardioStateStream` (was cardio `stateStream` → `_onCardioState`)
  - `Stream<RrInterval> get rrStream` (was cardio `rrStream` → `_onRrInterval`)
  - `Stream<BciEmotionsData> get emotionsStateStream` (was emotions `stateStream` → `_onEmotionsState`)
  - `Stream<String> get emotionsErrorStream` (was emotions `errorStream`, log-only)
  - `Stream<MotionData> get motionStream` (was mems `memsStream` → `_onMemsBatch`, which fans a batch out to multiple `MotionData`)
  - `Future<void> dispose()`
  Imports: `../Models/BciNfbData.dart`, `../Models/BciEmotionsData.dart`, `../../Biometrics/Models/CardioData.dart`, `../../Biometrics/Models/RrInterval.dart`, `../../Biometrics/Models/MotionData.dart`. Add the same doc-comment style as `DevicePort.dart` (narrow port, fake-implementable without `neiry`). No `neiry` import.

- [x] **Task 2: Add `ClassifierFactory` port interface** (depends on Task 1)
  Files: `lib/Bci/Ports/ClassifierFactory.dart`
  Declare `abstract interface class ClassifierFactory` with one method: `ClassifierSet build(DevicePort device)`. Imports: `DevicePort.dart`, `ClassifierSet.dart`. No `neiry` import. Doc-comment: builds the four classifiers from a `DevicePort`; production default is `NeiryClassifierFactory`.

### Phase 2: neiry adapters

- [x] **Task 3: Add `NeiryClassifierSet` adapter** (depends on Task 1)
  Files: `lib/Bci/Ports/NeiryClassifierSet.dart`
  `class NeiryClassifierSet implements ClassifierSet`. Constructor takes a `neiry.Device` and builds the four classifiers **in order** `NfbClassifier → CardioClassifier → EmotionsClassifier → MEMSClassifier` (identical to connect `:172-175`).
  - Implement the seven domain-typed stream getters by mapping the vendor streams — move the provider's mapping bodies verbatim into this adapter:
    - `nfbStateStream` = `_nfb.stateStream.map(...)` → `BciNfbData` (copy `_onNfbState` body)
    - `nfbErrorStream` = `_nfb.errorStream`
    - `cardioStateStream` = `_cardio.stateStream.map(...)` → `CardioData` with `source: SensorSource.neiry, hrv: null` (copy `_onCardioState`)
    - `rrStream` = `_cardio.rrStream.map(...)` → `RrInterval` with `source: SensorSource.neiry` (copy `_onRrInterval`)
    - `emotionsStateStream` = `_emotions.stateStream.map(...)` → `BciEmotionsData` (copy `_onEmotionsState`)
    - `emotionsErrorStream` = `_emotions.errorStream`
    - `motionStream` = `_mems.memsStream.expand((batch) => batch.map(...))` → `MotionData` with `source: SensorSource.neiry` (copy `_onMemsBatch`, which emits one `MotionData` per sample — `expand` preserves the fan-out exactly)
  - `dispose()` disposes the four classifiers in order `nfb → cardio → emotions → mems`, each wrapped in its own `try/catch` with a `logPrint('NeiryClassifierSet: <kind> dispose error: $e')` (preserves current per-classifier error isolation so one failure doesn't skip the rest). It does not rethrow in production.
  - This is the only new file (with Task 4) allowed to `import 'package:neiry_kit/neiry_kit.dart' as neiry`. Follow the doc-comment style of `NeiryDeviceAdapter.dart`.

- [x] **Task 4: Add `NeiryClassifierFactory` adapter** (depends on Task 2, Task 3)
  Files: `lib/Bci/Ports/NeiryClassifierFactory.dart`
  `class NeiryClassifierFactory implements ClassifierFactory`. `build(DevicePort device)` casts `device as NeiryDeviceAdapter`, reads `.rawDevice`, and returns `NeiryClassifierSet(rawDevice)`. This relocates the `(_device as NeiryDeviceAdapter).rawDevice` cast (currently inline at `NeiryBciProvider.dart:171`) into the factory. Imports: `neiry_kit`, `DevicePort.dart`, `ClassifierFactory.dart`, `ClassifierSet.dart`, `NeiryDeviceAdapter.dart`, `NeiryClassifierSet.dart`.
  Also update the `rawDevice` getter doc-comment in `lib/Bci/Ports/NeiryDeviceAdapter.dart:25-30` to state it is now consumed by `NeiryClassifierFactory` (drop the "A3 will introduce…" temporary note).

### Phase 3: Wire the provider

- [x] **Task 5: Inject `ClassifierFactory` and rebuild the classifier surface in `NeiryBciProvider`** (depends on Task 4)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Single coherent edit so the file stays compiling — touch the constructor, fields, `connect()`, subscriptions, and all three teardown paths:
  - **Constructor:** add `ClassifierFactory? classifierFactory` named param; store `final ClassifierFactory _classifierFactory = classifierFactory ?? NeiryClassifierFactory()`. The factory is stateless (not recreated per connect, unlike the locator), so a plain instance — not a `Function()` — is enough. Existing call site `App.dart:193 NeiryBciProvider()` stays valid (default arg).
  - **Fields:** replace the four `neiry.*Classifier? _xClassifier` fields (`:51-54`) with a single `ClassifierSet? _classifierSet`.
  - **Subscription field types:** retype `_nfbSub`→`StreamSubscription<BciNfbData>?`, `_cardioSub`→`StreamSubscription<CardioData>?`, `_rrSub`→`StreamSubscription<RrInterval>?`, `_emotionsSub`→`StreamSubscription<BciEmotionsData>?`, `_memsSub`→`StreamSubscription<MotionData>?`. Error subs stay `StreamSubscription<String>?`.
  - **`connect()` (`:166-202`):** after `await _device!.connect()`, replace the four inline `neiry.*Classifier(raw)` constructions with `_classifierSet = _classifierFactory.build(_device!);` then `await _device!.start()`. In the catch block replace the four `_xClassifier?.dispose()` blocks with one `try { await _classifierSet?.dispose(); } catch (_) {}` then `_classifierSet = null;` (keep the rest of the cleanup — device disconnect/dispose, `_resetLocatorSession()`, rethrow — unchanged).
  - **`_subscribeDeviceStreams()` (`:205-258`):** device subs (connection/resistance/battery) unchanged. Replace the classifier subs so each listens to the corresponding `_classifierSet!` stream and forwards into the existing broadcast controller: `_nfbController.add` / `_nfbErrorSub` logs / `_cardioController.add` / `_rrController.add` / `_emotionsController.add` / `_emotionsErrorSub` logs / `_motionController.add`. Keep the same `onError:` logPrint lines. The provider's broadcast controllers remain the stable public surface across reconnects.
  - **Remove** the now-unused mapping methods `_onNfbState`/`_onCardioState`/`_onRrInterval`/`_onMemsBatch`/`_onEmotionsState` (moved to the adapter in Task 3).
  - **`_teardownAfterUnexpectedDrop()` (`:455-542`):** capture/null `_classifierSet` instead of the four classifier locals (keep the sub captures/nulls). In the microtask, replace Step 3's four dispose blocks with `try { await classifierSet?.dispose(); } catch (e) { logPrint('NeiryBciProvider: classifier dispose error: $e'); }`. Step ordering (stopStream → cancel subs → dispose classifiers → device disconnect/dispose → `_resetLocatorSession`) unchanged.
  - **`_cancelDeviceSubscriptions()` (`:544-590`):** keep the sub cancels; replace the four classifier dispose blocks with one `try { await _classifierSet?.dispose(); } catch (e) { logPrint('NeiryBciProvider: classifier dispose error: $e'); } _classifierSet = null;`.
  - Add imports for `Ports/ClassifierFactory.dart`, `Ports/ClassifierSet.dart`, `Ports/NeiryClassifierFactory.dart`. The remaining `neiry` import stays (calibrator only).
  - Verify the file compiles and `flutter analyze` is clean (use `/usr/local/bin/flutter`).

### Phase 4: Injectability test

- [x] **Task 6: Fake `ClassifierSet`/`ClassifierFactory` + injectability test** (depends on Task 5)
  Files: `test/Bci/neiry_bci_provider_classifier_port_test.dart`
  Mirror the seam-test style of `test/Bci/neiry_bci_provider_device_port_test.dart` (reuse a `FakeDevicePort` + a controlled `LocatorPort`; both already exist there as patterns — re-declare locally, no `neiry` import in the test).
  - `FakeClassifierSet implements ClassifierSet`: seven broadcast `StreamController`s with emit helpers, a call-counted `dispose()` with a `bool throwOnDispose` (and/or a swappable `Completer`) so B2 can drive a throwing dispose.
  - `FakeClassifierFactory implements ClassifierFactory`: `build()` is call-counted and returns the fake set (ignores the `DevicePort` type — this is what unblocks the **full** connect() happy-path that the A2 test had to skip).
  - Tests:
    1. `connect()` with `FakeDevicePort` + `FakeClassifierFactory` completes without throwing; `build()` called once; `device.start()` called once; emitting on each fake classifier stream surfaces on the matching provider public stream (`nfbStream`/`cardioStream`/`rrStream`/`emotionsStream`/`motionStream`).
    2. `disconnect()` (or `dispose()`) calls `FakeClassifierSet.dispose()` once; a `throwOnDispose` set still lets teardown complete (no exception escapes) — the B2 hook.
    3. Default constructor smoke check: `NeiryBciProvider()` still constructs (default `NeiryClassifierFactory` wired, production path untouched).
  - Run `/usr/local/bin/flutter test test/Bci/` and confirm green (including the existing A1/A2 tests — the A2 test still expects a `TypeError` from `connect()` because it uses the default `NeiryClassifierFactory`, whose `build()` casts the fake device → `TypeError`; that remains correct and must stay passing).

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add ClassifierFactory and ClassifierSet ports"
- **Commit 2** (after tasks 3-4): "Add neiry classifier factory and set adapters"
- **Commit 3** (after task 5): "Wire ClassifierFactory into NeiryBciProvider"
- **Commit 4** (after task 6): "Add fake ClassifierSet injectability test"
