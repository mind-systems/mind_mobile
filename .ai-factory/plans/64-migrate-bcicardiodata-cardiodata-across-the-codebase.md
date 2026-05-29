# Plan: Migrate `BciCardioData` → `CardioData` across the codebase

## Context
Replace the Phase-19 BCI-only `BciCardioData` with the richer biometrics `CardioData` value object (added in milestone 63: `lib/Biometrics/Models/CardioData.dart`) at every consumer along the cardio stream — provider → manager → notifier event → module service — then delete the old type. This unifies cardio representation under the new biometrics layer and starts carrying SDK timestamps + `SensorSource` through the pipeline (spec: `.ai-factory/notes/27-biometrics-refactor.md` Milestone 2, `.ai-factory/notes/32-biosample-sdk-timestamps.md`). Capability split (separating cardio from the provider interface) is the next milestone; here the `cardioStream` getter stays put on `IBciDeviceProvider`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Swap the cardio payload type through the stream

- [x] **Task 1: Switch `BciNotifierEvent.BciCardioUpdated` payload to `CardioData`**
  Files: `lib/Bci/Models/BciNotifierEvent.dart`
  Replace the line `import 'package:mind/Bci/Models/BciCardioData.dart';` with `import 'package:mind/Biometrics/Models/CardioData.dart';`. In the `BciCardioUpdated` variant change the field type from `BciCardioData data` to `CardioData data` (constructor parameter `this.data` does not need to change — only the field declaration's type). No other variants in this file are affected.

- [x] **Task 2: Switch `IBciDeviceProvider.cardioStream` return type to `Stream<CardioData>`** (depends on Task 1)
  Files: `lib/Bci/IBciDeviceProvider.dart`
  Replace `import 'Models/BciCardioData.dart';` with `import 'package:mind/Biometrics/Models/CardioData.dart';` (use the absolute `package:mind/...` form to match the convention used elsewhere for cross-module imports; the file currently uses relative imports for its own `Models/` siblings — keep those as-is, only the cardio import changes). Change the getter signature from `Stream<BciCardioData> get cardioStream;` to `Stream<CardioData> get cardioStream;`. Leave all other stream getters untouched — capability split is the next milestone.

- [x] **Task 3: Switch `BciDeviceManager.cardioStream` getter return type** (depends on Task 2)
  Files: `lib/Bci/BciDeviceManager.dart`
  Replace `import 'package:mind/Bci/Models/BciCardioData.dart';` with `import 'package:mind/Biometrics/Models/CardioData.dart';`. Update the public getter (around line 81) from `Stream<BciCardioData> get cardioStream => _provider.cardioStream;` to `Stream<CardioData> get cardioStream => _provider.cardioStream;`. The body is a pass-through delegation to the provider and needs no logic change. No other lines in this file reference `BciCardioData`.

- [x] **Task 4: Re-wire `NeiryBciProvider` to emit `CardioData` with alias import** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  This file is the only place in `mind_mobile` that may import `neiry_kit`. The SDK exposes its own `CardioData` class that collides with the new biometrics `CardioData`, so the entire `neiry_kit` import must be aliased to avoid the name clash. Changes, in order:
  1. Change `import 'package:neiry_kit/neiry_kit.dart';` to `import 'package:neiry_kit/neiry_kit.dart' as neiry;`.
  2. Remove `import 'Models/BciCardioData.dart';` and add `import 'package:mind/Biometrics/Models/CardioData.dart';` and `import 'package:mind/Biometrics/Models/SensorSource.dart';` to the import block at the top.
  3. Prefix every reference to a `neiry_kit` type in the file with `neiry.` (the file currently uses bare names for all SDK types). Specifically:
     - Fields/locals: `DeviceLocator()` → `neiry.DeviceLocator()`; `Device?` → `neiry.Device?`; `NfbClassifier?` → `neiry.NfbClassifier?`; `CardioClassifier?` → `neiry.CardioClassifier?`; `EmotionsClassifier?` → `neiry.EmotionsClassifier?`.
     - Subscription generics: `StreamSubscription<NeiryConnectionState>?` → `StreamSubscription<neiry.NeiryConnectionState>?`; `StreamSubscription<ResistanceData>?` → `StreamSubscription<neiry.ResistanceData>?`; `StreamSubscription<CalibrationEvent>?` → `StreamSubscription<neiry.CalibrationEvent>?`; `StreamSubscription<NfbUserState>?` → `StreamSubscription<neiry.NfbUserState>?`; `StreamSubscription<CardioData>?` → `StreamSubscription<neiry.CardioData>?`; `StreamSubscription<EmotionsStates>?` → `StreamSubscription<neiry.EmotionsStates>?`.
     - Classifier instantiation in `connect()`: `NfbClassifier(_device!)` → `neiry.NfbClassifier(_device!)`; `CardioClassifier(_device!)` → `neiry.CardioClassifier(_device!)`; `EmotionsClassifier(_device!)` → `neiry.EmotionsClassifier(_device!)`.
     - Mapper signatures: `_onNeiryConnectionState(NeiryConnectionState s)` → `_onNeiryConnectionState(neiry.NeiryConnectionState s)`; `_onResistance(ResistanceData r)` → `_onResistance(neiry.ResistanceData r)`; `_onNfbState(NfbUserState s)` → `_onNfbState(neiry.NfbUserState s)`; `_onEmotionsState(EmotionsStates e)` → `_onEmotionsState(neiry.EmotionsStates e)`.
     - Switch-case pattern matches: `case NeiryConnectionState.connected:` → `case neiry.NeiryConnectionState.connected:` (and the other two arms); `case CalibrationStageFinished(:final stage):` → `case neiry.CalibrationStageFinished(:final stage):`; `case CalibrationCompleted():` → `case neiry.CalibrationCompleted():`.
     - Scan call: `_locator.requestDevices(type: NeiryDeviceType.headband, searchTime: 5)` → `_locator.requestDevices(type: neiry.NeiryDeviceType.headband, searchTime: 5)`.
     - Calibration: `NfbCalibrator.calibrateIndividual()` → `neiry.NfbCalibrator.calibrateIndividual()`.
  4. Change the cardio controller field at line 40 from `final _cardioController = StreamController<BciCardioData>.broadcast();` to `final _cardioController = StreamController<CardioData>.broadcast();` (our `CardioData`, not aliased).
  5. Change the getter override at line 74 from `Stream<BciCardioData> get cardioStream => _cardioController.stream;` to `Stream<CardioData> get cardioStream => _cardioController.stream;`.
  6. Rewrite `_onCardioState` (lines 271–277) end-to-end:
     ```dart
     void _onCardioState(neiry.CardioData c) {
       _cardioController.add(CardioData(
         heartRate: c.heartRate,
         metricsAvailable: c.metricsAvailable,
         hasArtifacts: c.hasArtifacts,
         timestamp: c.timestamp,
         source: SensorSource.neiry,
         hrv: null,
       ));
     }
     ```
     `hrv: null` is correct for this milestone — the spec defers HRV index population (note 27). The SDK's `CardioData.timestamp` is a `DateTime` (matches our field type) so no conversion is needed.
  7. Update the comment header at line 269 from `// ── CardioData → BciCardioData ──...` to `// ── neiry.CardioData → CardioData ──...` to reflect the new mapping direction.

- [x] **Task 5: Verify `BciModule/BciDataService.dart` still compiles** (depends on Tasks 1, 4)
  Files: `lib/BciModule/BciDataService.dart`
  The reducer destructures `case BciCardioUpdated(:final data):` and reads `data.heartRate`, `data.metricsAvailable`, `data.hasArtifacts` — all three fields exist on the new `CardioData` with the same types, so the reducer body needs no logic change. Run the project's analyzer (`flutter analyze` / IDE) after Tasks 1–4 land; if the analyzer reports an unresolved-type or missing-import error on the destructured `data`, add `import 'package:mind/Biometrics/Models/CardioData.dart';` to the file's import block (Dart usually resolves the inferred field-access types transitively through `BciNotifierEvent.dart`, but the explicit import is the safest fix if it doesn't). No other consumer (`BciNotifier`, `BciDataScreen`, `BciDataViewModel`) reads the cardio payload type directly — `BciNotifier`'s subscriptions are `StreamSubscription<dynamic>` (verified in source) so no edits are needed there.

### Phase 2: Remove the dead type

- [x] **Task 6: Delete `lib/Bci/Models/BciCardioData.dart`** (depends on Tasks 1–5)
  Files: `lib/Bci/Models/BciCardioData.dart`
  Delete the file. After Tasks 1–5 there must be zero remaining references to `BciCardioData` in `lib/` — confirm with a project-wide grep for `BciCardioData` before deleting; if any reference is still found, fix it in the same task before removing the file (the migration is incomplete otherwise). After deletion run `flutter analyze` to confirm the project still compiles end-to-end.

## Commit Plan
- **Commit 1** (after Tasks 1–4): "Switch cardio stream from BciCardioData to biometrics CardioData across provider, manager, and notifier event"
- **Commit 2** (after Tasks 5–6): "Verify downstream consumers and delete legacy BciCardioData type"

<!-- orchestrator-sessions
planner: c3f7f8bf-3922-4de5-8628-84b34a26bf12
elapsed: 734
implementer: 2c0bd897-e591-4602-83cf-768cba0163b9
-->
