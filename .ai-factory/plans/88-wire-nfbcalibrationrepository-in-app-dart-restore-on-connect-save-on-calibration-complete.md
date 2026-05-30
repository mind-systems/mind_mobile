# Plan: Wire NfbCalibrationRepository in App.dart + restore on connect + save on calibration complete

## Context
Wire the existing `NfbCalibrationRepository` into the DI graph (`App.dart`), then thread it through `BciDeviceManager` so calibration is restored automatically on every reconnect to a known device and persisted whenever a fresh, **valid** calibration completes. A successful restore must short-circuit the impedance/calibration step so the user lands directly in `ready` and the restored data is not immediately overwritten.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: DI wiring

- [x] **Task 1: Construct `NfbCalibrationRepository` as a local in `App.initialize()` and inject it into `BciDeviceManager`**
  Files: `lib/Core/App.dart`
  - Add import `package:mind/Bci/NfbCalibrationRepository.dart`.
  - **Do not** add a public field on `class App` and **do not** add a parameter to `App._({...})`. The repository has exactly one consumer (`BciDeviceManager`) and is constructor-injected, matching the existing `BciDeviceRepository` pattern (constructed locally on line 162, not exposed on `App.shared`).
  - In `initialize()`, immediately after the existing `final prefs = await SharedPreferences.getInstance();` line, add on its own single line:
    `final nfbCalibrationRepository = NfbCalibrationRepository(prefs: prefs);`
    (follows the file-level style rule: single-line, no trailing commas on initializer lines).
  - In the existing multi-line `BciDeviceManager(...)` invocation (currently at lines 164–170), add `nfbCalibrationRepository: nfbCalibrationRepository,` as the last named argument, preserving the trailing-comma style of that specific call.

### Phase 2: `BciDeviceManager` integration

- [x] **Task 2: Accept and store `NfbCalibrationRepository`** (depends on Task 1)
  Files: `lib/Bci/BciDeviceManager.dart`
  - Add import `package:mind/Bci/NfbCalibrationRepository.dart`.
  - Add private final field `final NfbCalibrationRepository _nfbCalibrationRepository;` next to the existing `_repository` field.
  - Add `required NfbCalibrationRepository nfbCalibrationRepository,` to the constructor's named parameter list (after `repository`).
  - Initialize it in the initializer list: append `, _nfbCalibrationRepository = nfbCalibrationRepository` after the existing `_repository = repository` initializer (before the `{` of the constructor body).

- [x] **Task 3: Restore calibration after a successful connect, with fault-isolated error handling and direct transition to `ready`** (depends on Task 2)
  Files: `lib/Bci/BciDeviceManager.dart`

  Modify `connectDevice(String serial)` so the restore happens **after** `_provider.connect(serial)` succeeds. The Neiry SDK's `NfbCalibrator.importCalibrationData` (`lib/Bci/NeiryBciProvider.dart:408`) needs an active device binding, mirroring the live `calibrateIndividual()` path used by `startCalibration()`. Calling it pre-connect risks silent no-op or throwing, blocking all future connects.

  The new body of the `try` block becomes (replacing lines 178–183):
  ```dart
  await _provider.connect(serial);
  _connectedSerial = serial;
  unawaited(_repository.registerDevice(serial).catchError(
    (Object e) => logPrint('BciDeviceManager: registerDevice failed: $e'),
  ));

  var restored = false;
  final cal = _nfbCalibrationRepository.latestValid(serial);
  if (cal != null) {
    try {
      await _provider.importCalibration(cal);
      restored = true;
    } catch (e) {
      logPrint('BciDeviceManager: importCalibration failed: $e');
      // Fall through to normal impedance/calibration flow.
    }
  }

  _setState(restored ? BciConnectionState.ready : BciConnectionState.impedance);
  ```

  Notes:
  - The restore is wrapped in its own `try/catch` so a corrupt cache entry (bad JSON, unknown `failReason` enum name, SDK rejection) degrades to "no restore, run normal calibration" rather than bricking the connect path.
  - `restored == true` short-circuits the impedance step entirely. This is what makes the feature observable: without it, the UI would still prompt for calibration and `startCalibration()` → `BciCalibrationCompleted` would immediately overwrite the just-restored data.
  - `registerDevice(...)` is moved above the restore so registration still runs even if the restore throws (matches current behavior where it runs unconditionally on connect success).
  - The outer `catch (e)` block (currently at lines 184–187) is unchanged and still handles `_provider.connect` failures only.

- [x] **Task 4: Persist valid calibrations on completion** (depends on Task 2)
  Files: `lib/Bci/BciDeviceManager.dart`

  In `_subscribeProviderStreams()`, inside the `_provider.calibrationStream.listen` switch, update the `BciCalibrationCompleted` arm:

  - Change the pattern from `case BciCalibrationCompleted(data: final _):` to `case BciCalibrationCompleted(data: final data):` (still exhaustive over the sealed `BciCalibrationEvent`).
  - Before the existing `if (_state == BciConnectionState.calibrating) _setState(BciConnectionState.ready);` line, insert:
    ```dart
    if (data.isValid && _connectedSerial != null) {
      unawaited(_nfbCalibrationRepository.record(_connectedSerial!, data));
    }
    ```

  Rationale:
  - **Gating on `data.isValid`** protects the repository's 20-entry FIFO: `NeiryBciProvider` emits `BciCalibrationCompleted` for both successful and failed calibrations (`lib/Bci/NeiryBciProvider.dart:367-380`), and `latestValid` walks newest→oldest looking for `isValid == true`. Without this gate, 20 failed attempts in a row would evict the last good entry and leave `latestValid` returning `null` forever.
  - **Not gating on `_state == calibrating`** is intentional: a late-arriving completion event after a state transition still persists, so the cache stays in sync with the SDK's view.
  - `_connectedSerial!` is dereferenced inside the same synchronous listener block after the null check; Dart is single-threaded and nothing yields between the check and the call, so the bang is safe.
  - `unawaited` is already in scope via `import 'dart:async';` at the top of `BciDeviceManager.dart` — no new import required.

<!-- orchestrator-sessions
planner: 549d0a73-9f1a-46e9-9f7e-cc7f65c6194b
elapsed: 1081
implementer: f3c294e2-0ed7-4d8e-bffc-b92e00b0d474
-->
