# Retry a failed calibration via quick calibration

**Date:** 2026-06-23
**Source:** conversation context (code-grounded)

## Key Findings

- Today an **invalid** calibration result is misreported as success. The neiry SDK reports a poor-signal calibration (too many artifacts / peak at band border) as a **`CalibrationCompleted` event with `isValid == false`** — there is no separate "failed" SDK event (only `CalibrationStageFinished` + `CalibrationCompleted`; a hard `BciCalibrationFailed` is emitted only on a stream error, e.g. mid-run disconnect). `BciDeviceManager` ignores `isValid` and unconditionally goes to `BciReady` (`lib/Bci/BciDeviceManager.dart:80-93`), and the reducer drops `isValid`, rendering a green "complete" check (`lib/BciModule/BciPairingService.dart:190-196`, `BciCalibrationSection.dart:176-187`). The user lands in `BciReady` with **no way to recalibrate**.
- **SDK constraint (product-confirmed):** a **full** 4-stage calibration (`NfbCalibrator.calibrateIndividual()`) **cannot be re-run in the same session** once started — only after a device reconnect (the per-session calibrator limitation). We will NOT force a reconnect (correct but bad UX). **Quick** calibration (`NfbCalibrator.calibrateIndividualQuick()`, `neiry_kit/lib/src/api/nfb_calibrator.dart:192`) **can be re-run any number of times** in-session.
- **Design:** first calibration = full (4 progress dots, unchanged). On any failure (invalid completion OR hard error), surface the failure and show a **Retry** button that runs **quick** calibration (single-stage → **1 progress dot**). Quick can itself return `isValid == false` → the retry loop repeats. A valid result (full or quick) → `BciReady` + persist.

## Details

### Current code map (all paths verified)
- Provider full path: `NeiryBciProvider.startCalibration()` listens to `NfbCalibrator.calibrateIndividual()` and maps `CalibrationCompleted` → `BciCalibrationCompleted(NfbCalibrationData(isValid: data.isValid, failReason: data.failReason.name, …))` (`lib/Bci/NeiryBciProvider.dart:366-397`). `onError` → `BciCalibrationFailed(e.toString())`.
- `NfbCalibrationData` carries `isValid` + `failReason` (`lib/Bci/Models/NfbCalibrationData.dart:11,20`; allowed `failReason`: `"none"` / `"tooManyArtifacts"` / `"peakFrequencyAtBorder"`).
- Manager calibration handler: `lib/Bci/BciDeviceManager.dart:76-100`. Calibration events reach the UI directly (`get calibrationStream => _provider.calibrationStream`, `:111`).
- Reducer: `BciPairingService._reduceCalibrationEvent` (`:177-201`) and `_reduceStateChanged` (`:97-175`). **Gotcha:** the `BciImpedance` branch sets `errorMessage: null` (`:150`), so failure text put on `errorMessage` is wiped when the manager transitions back to impedance. The `BciImpedance` branch does NOT touch `calibration` (`:144-151`), so the calibration DTO **survives** the impedance transition — carry the failure there.
- UI: `BciCalibrationSection` — single button gated on `stage == impedance` runs full (`:133-139`); 4 hardcoded dots (`:145` `List.generate(4, …)`); green check on `isComplete` (`:176-187`).
- DTO: `BciCalibrationProgressDTO { stagesCompleted, isComplete }` (`Models/BciCalibrationProgressDTO.dart`). State enum: `BciPairingStage { discovery, impedance, calibrating, ready }`. Sealed domain state `BciCalibrating(serial)` (`lib/Bci/Models/BciConnectionState.dart:53-55`).

### Exact change (one cohesive feature; layers, top-down)
1. **Provider** — add `Future<void> startQuickCalibration()` to `IBciDeviceProvider` (`lib/Bci/IBciDeviceProvider.dart:53` area). Implement in `NeiryBciProvider`: `final data = await neiry.NfbCalibrator.calibrateIndividualQuick();` → map to `NfbCalibrationData` (mirror `:375-389`) → `_calibrationController.add(BciCalibrationCompleted(mapped));`; on throw → `add(BciCalibrationFailed(e.toString()))`. No stage events (single stage).
2. **Domain state** — `BciCalibrating` carries the run size: `BciCalibrating(super.serial, {required this.totalStages})` (`int totalStages`; 4 for full, 1 for quick). Update the only construction sites in `BciDeviceManager`.
3. **Manager** (`BciDeviceManager`):
   - `startCalibration()` (`:234`): on guard `_state is BciImpedance` → `_setState(BciCalibrating(serial, totalStages: 4))` → `await _provider.startCalibration()`.
   - Add `startQuickCalibration()`: guard `_state is BciImpedance` → `_setState(BciCalibrating(serial, totalStages: 1))` → `await _provider.startQuickCalibration()`; `catch` → `_setState(BciImpedance(serial))`.
   - Calibration handler `BciCalibrationCompleted` (`:80-93`): branch on `data.isValid` — valid → record (existing, keep the `_connectedSerial != null` guard) + `_setState(BciReady(serial))`; **invalid → `_setState(BciImpedance(serial))`** (retryable; do NOT record). `BciCalibrationFailed` (`:94-98`): keep `_setState(BciImpedance(serial))`.
4. **DI passthrough** — `BciNotifier.startQuickCalibration() => _manager.startQuickCalibration()` (`lib/Bci/BciNotifier.dart:111` area); `IBciPairingService.startQuickCalibration()` (`:20` area) + `BciPairingService` impl `unawaited(bciNotifier.startQuickCalibration())`.
5. **DTO** — `BciCalibrationProgressDTO` gains `final int totalStages; final bool failed; final String? failReason;` (keep `stagesCompleted`, `isComplete`).
6. **Reducer** (`BciPairingService`):
   - `_reduceStateChanged` `BciCalibrating(:final totalStages)` (`:153-164`): `calibration: BciCalibrationProgressDTO(stagesCompleted: 0, isComplete: false, failed: false, totalStages: totalStages)`.
   - `_reduceCalibrationEvent` `BciCalibrationCompleted(:final data)` (`:190-196`): if `data.isValid` → `DTO(isComplete: true, failed: false, totalStages: keep)`; else → `DTO(isComplete: false, failed: true, failReason: data.failReason, totalStages: keep)`.
   - `BciCalibrationFailed(:final reason)` (`:198-200`): `DTO(failed: true, failReason: reason, isComplete: false, totalStages: keep)` (instead of `calibration: null`). Carry the reason in the DTO, **not** `errorMessage` (impedance wipes it).
7. **ViewModel** (`BciPairingViewModel`, `:46`): add `onRetryCalibration() => service.startQuickCalibration();` (keep `onStartCalibration` for the first full run).
8. **UI** (`BciCalibrationSection`):
   - Progress dots: `List.generate(state.calibration!.totalStages, …)` (4 full / 1 quick).
   - In-progress block condition (`:141`): `calibration != null && !isComplete && !failed`.
   - On `state.calibration?.failed == true`: show the localized failure reason + a **Retry** button → `onRetryCalibration()`.
   - First-attempt button stays `onStartCalibration` (full) when `stage == impedance && calibration?.failed != true`.
9. **l10n** (`packages/mind_l10n` — add to both `app_en.arb` and `app_ru.arb` next to the existing `bciPairingCalibration*` keys, then regen). The UI maps the DTO `failReason` → message: `"tooManyArtifacts"` → Artifacts, `"peakFrequencyAtBorder"` → Peak, anything else (hard-error free-form `e.toString()`) → generic. Exact copy (pinned):

   | Key | EN | RU |
   |---|---|---|
   | `bciPairingRetryCalibration` | `Retry` | `Повторить` |
   | `bciPairingCalibrationFailedArtifacts` | `Calibration failed: too much signal noise. Sit still, relax, and try again.` | `Калибровка не удалась: слишком много помех в сигнале. Сядьте спокойно, расслабьтесь и попробуйте снова.` |
   | `bciPairingCalibrationFailedPeak` | `Calibration failed: couldn't reliably detect your individual rhythm. Please try again.` | `Калибровка не удалась: не удалось надёжно определить ваш индивидуальный ритм. Попробуйте ещё раз.` |
   | `bciPairingCalibrationFailed` | `Calibration failed. Please try again.` | `Калибровка не удалась. Попробуйте ещё раз.` |

### Guards
- First run is **full** (4 stages); **every retry is quick** (1 stage) — never re-run full in-session (SDK rejects it).
- Persist (`_nfbCalibrationRepository.record`) **only** on a valid result; never on invalid/failed.
- Put failure text on the calibration DTO, never on `errorMessage` (the `BciImpedance` reducer branch clears `errorMessage`, `:150`).
- Quick result can be invalid too — the failed→Retry→quick loop must repeat cleanly.
- No `neiry_kit` change: `calibrateIndividualQuick()` already exists. Do not touch the full-calibration stage flow or the reconnect/teardown work (Phase 52).

### Verify
- Force a bad full calibration (artifacts) → UI shows a **failure** (not a green check), at impedance, with a **Retry** button. Tap Retry → a **1-dot** quick run starts. A good quick run → `BciReady` + persisted; a bad quick run → failure shown again, Retry still available (loop). A clean full first run still shows 4 dots and succeeds.

## Open Questions
- None — all symbols, routing, and the failure/Retry copy (EN/RU) are pinned above.
