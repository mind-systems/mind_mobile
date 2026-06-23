# Plan: Surface calibration failure and retry it via quick calibration

## Context
Today an invalid NFB calibration result (`isValid == false`) is misreported as a green "complete" check and routes the user to `BciReady` with no recovery path. This milestone surfaces the failure (showing the reason at the impedance stage) and adds a **Retry** button that re-runs a single-stage **quick** calibration — looping until a valid result is produced. The first run stays the full 4-stage calibration; every retry is quick (the SDK forbids re-running full calibration in-session). No `neiry_kit` change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain — provider + manager + state

- [x] **Task 1: Add `startQuickCalibration()` to the provider abstraction**
  Files: `lib/Bci/IBciDeviceProvider.dart`, `lib/Bci/NeiryBciProvider.dart`
  Add `Future<void> startQuickCalibration();` to the `IBciDeviceProvider` interface, next to the existing `startCalibration()` (line ~53), with a doc comment noting it runs a single-stage quick calibration that may be re-run any number of times in-session.
  Implement it in `NeiryBciProvider`: `final data = await neiry.NfbCalibrator.calibrateIndividualQuick();`, then map `data` into a `NfbCalibrationData` exactly as the existing `CalibrationCompleted` branch does (mirror `NeiryBciProvider.dart:381-393` — `calibratedAt`, `isValid`, `failReason`, all `individual*` fields, `lowerFrequency`, `upperFrequency`), and `_calibrationController.add(BciCalibrationCompleted(mapped));`. Wrap in try/catch: on throw, `logPrint(...)` + `_calibrationController.add(BciCalibrationFailed(e.toString()));`. Emit **no** stage events (quick is single-stage). Cancel `_calibrationSub` first if the full flow used it — quick uses an awaited Future, not a stream subscription.

- [x] **Task 2: Carry run size on the `BciCalibrating` domain state** (depends on Task 1)
  Files: `lib/Bci/Models/BciConnectionState.dart`
  Change `BciCalibrating(super.serial)` (line ~53-55) to `BciCalibrating(super.serial, {required this.totalStages})` with a `final int totalStages;` field (4 = full, 1 = quick). Update the doc comment.

- [x] **Task 3: Route invalid results to impedance and add quick-calibration entry point in the manager** (depends on Task 2)
  Files: `lib/Bci/BciDeviceManager.dart`
  - In `startCalibration()` (line ~234): construct the calibrating state as `BciCalibrating(serial, totalStages: 4)` (both the initial `_setState` at ~237 and the catch-path reset stays `BciImpedance(serial)`).
  - Add `Future<void> startQuickCalibration()`: guard `if (_state is! BciImpedance) return;`, capture `serial`, `_setState(BciCalibrating(serial, totalStages: 1))`, `try { await _provider.startQuickCalibration(); } catch (e) { logPrint(...); _setState(BciImpedance(serial)); }`.
  - In the `BciCalibrationCompleted` calibration-stream handler (line ~80-93): branch on `data.isValid`. **Valid** → keep the existing `_nfbCalibrationRepository.record(...)` persistence (with the `_connectedSerial != null` guard) and `_setState(BciReady(...))`. **Invalid** → do **not** record; `_setState(BciImpedance((_state as BciCalibrating).serial))` (retryable). Keep the `if (_state is BciCalibrating)` outer guard for both branches.
  - Leave the `BciCalibrationFailed` handler (line ~94-98) as-is — it already routes to `BciImpedance`.

### Phase 2: DI passthrough — notifier + service interface

- [x] **Task 4: Pass quick calibration through the notifier and service interface** (depends on Task 3)
  Files: `lib/Bci/BciNotifier.dart`, `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`, `lib/BciModule/BciPairingService.dart`
  - `BciNotifier` (line ~111): add `Future<void> startQuickCalibration() => _manager.startQuickCalibration();`.
  - `IBciPairingService` (line ~20): add `void startQuickCalibration();` next to `startCalibration()`.
  - `BciPairingService` (line ~47): add `@override void startQuickCalibration() => unawaited(bciNotifier.startQuickCalibration());`.

### Phase 3: DTO + reducer — carry failure on the calibration DTO

- [x] **Task 5: Extend the calibration progress DTO** (depends on Task 4)
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciCalibrationProgressDTO.dart`
  Add three fields to `BciCalibrationProgressDTO`: `final int totalStages;`, `final bool failed;`, `final String? failReason;`. Keep `stagesCompleted` and `isComplete`. Make `totalStages` and `failed` required in the const constructor; `failReason` nullable/optional.

- [x] **Task 6: Map run size and failure into the DTO in the reducer** (depends on Task 5)
  Files: `lib/BciModule/BciPairingService.dart`
  - `_reduceStateChanged` `BciCalibrating` branch (line ~153-164): destructure `BciCalibrating(:final serial, :final totalStages)` and build `BciCalibrationProgressDTO(stagesCompleted: 0, isComplete: false, failed: false, totalStages: totalStages)`. This resets any prior failure when a new run (full or quick) starts.
  - `_reduceCalibrationEvent` `BciCalibrationStageFinished` branch (line ~182-188): keep `stagesCompleted`/`isComplete`, but preserve `failed: false`, `failReason: acc.calibration?.failReason`, and `totalStages: acc.calibration?.totalStages ?? 4`.
  - `_reduceCalibrationEvent` `BciCalibrationCompleted` branch (line ~190-196): destructure `BciCalibrationCompleted(:final data)` (the domain event carries the `NfbCalibrationData`). If `data.isValid` → `DTO(isComplete: true, failed: false, stagesCompleted: kept, totalStages: kept)`; else → `DTO(isComplete: false, failed: true, failReason: data.failReason, stagesCompleted: kept, totalStages: kept)`. Use `acc.calibration?.totalStages ?? 4` for the kept value.
  - `BciCalibrationFailed` branch (line ~198-200): replace `acc.copyWith(calibration: null, errorMessage: reason)` with `acc.copyWith(calibration: BciCalibrationProgressDTO(stagesCompleted: acc.calibration?.stagesCompleted ?? 0, isComplete: false, failed: true, failReason: reason, totalStages: acc.calibration?.totalStages ?? 4))`. **Do not** put the reason on `errorMessage` — the `BciImpedance` reducer branch sets `errorMessage: null` (`BciPairingService.dart:150`) and would wipe it. The `BciImpedance` branch does not touch `calibration`, so the failed DTO survives the transition.
  - Note on event ordering: an invalid completion produces both a `BciStateChanged(BciImpedance)` and a `BciCalibrationEventReceived(BciCalibrationCompleted)`. The impedance branch never touches `calibration` and the completed branch never touches `stage`, so the final reduced state (`stage: impedance`, `calibration.failed: true`) is correct regardless of which event the reducer processes first.

### Phase 4: Presentation — ViewModel, UI, l10n

- [x] **Task 7: Add the retry gesture to the ViewModel** (depends on Task 4)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  Add `void onRetryCalibration() => service.startQuickCalibration();` next to the existing `onStartCalibration()` (line ~46). Keep `onStartCalibration()` for the first full run.

- [x] **Task 8: Add failure/retry localization keys** (depends on Task 6)
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Add the following keys next to the existing `bciPairingCalibration*` keys (app_en.arb ~line 131-136), in both ARB files. Then regenerate: `flutter gen-l10n` (or `/usr/local/bin/flutter pub run build_runner build` per the package setup).

  | Key | EN | RU |
  |---|---|---|
  | `bciPairingRetryCalibration` | `Retry` | `Повторить` |
  | `bciPairingCalibrationFailedArtifacts` | `Calibration failed: too much signal noise. Sit still, relax, and try again.` | `Калибровка не удалась: слишком много помех в сигнале. Сядьте спокойно, расслабьтесь и попробуйте снова.` |
  | `bciPairingCalibrationFailedPeak` | `Calibration failed: couldn't reliably detect your individual rhythm. Please try again.` | `Калибровка не удалась: не удалось надёжно определить ваш индивидуальный ритм. Попробуйте ещё раз.` |
  | `bciPairingCalibrationFailed` | `Calibration failed. Please try again.` | `Калибровка не удалась. Попробуйте ещё раз.` |

- [x] **Task 9: Render dynamic dots, failure reason, and Retry button in the UI** (depends on Task 7, Task 8)
  Files: `packages/bci_module/lib/src/BciPairing/Views/BciCalibrationSection.dart`
  - Progress dots (line ~143-167): replace `List.generate(4, ...)` with `List.generate(state.calibration!.totalStages, ...)` and update the per-dot right-padding logic so the last dot has no trailing gap (use `i < state.calibration!.totalStages - 1 ? 8.0 : 0`).
  - In-progress block guard (line ~141): change to `state.calibration != null && !state.calibration!.isComplete && !state.calibration!.failed` so it hides once a failure is shown. Apply the same `!failed` condition to the `ref.listen` `inProgress` computation (line ~90) so the tick timer and stage chime stop on failure.
  - First-attempt button (line ~133-138): keep `onStartCalibration()` (full), but only enable it when `state.stage == BciPairingStage.impedance && state.calibration?.failed != true` — once a failure is shown, the primary action becomes Retry.
  - Add a new failure block, shown `if (state.calibration?.failed == true)`: render the localized failure reason via a helper that maps `state.calibration!.failReason` → message (`"tooManyArtifacts"` → `bciPairingCalibrationFailedArtifacts`, `"peakFrequencyAtBorder"` → `bciPairingCalibrationFailedPeak`, anything else / null → `bciPairingCalibrationFailed`), plus an `ElevatedButton` labelled `l10n.bciPairingRetryCalibration` that calls `ref.read(bciPairingViewModelProvider.notifier).onRetryCalibration()`. Do not show the green check when `failed == true`.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Surface invalid calibration as failure and add quick calibration in domain layer"
- **Commit 2** (after tasks 4-6): "Thread quick calibration and failure state through service and reducer"
- **Commit 3** (after tasks 7-9): "Show calibration failure reason and quick-retry button in pairing UI"
