# Code Review: Surface calibration failure and retry via quick calibration

**Branch:** dev
**Files reviewed (in full):** 9 source files + 5 generated/l10n files
**Risk level:** 🟢 Low — no blocking findings

## Scope

Reviewed all staged code changes against the plan and the surrounding code:
- `lib/Bci/IBciDeviceProvider.dart`, `lib/Bci/NeiryBciProvider.dart`
- `lib/Bci/Models/BciConnectionState.dart`, `lib/Bci/BciDeviceManager.dart`, `lib/Bci/BciNotifier.dart`
- `lib/BciModule/BciPairingService.dart`
- `packages/bci_module/.../BciCalibrationProgressDTO.dart`, `IBciPairingService.dart`, `BciPairingViewModel.dart`, `Views/BciCalibrationSection.dart`
- `packages/mind_l10n/...` (ARB + generated `AppLocalizations*`)

## Correctness verification

- **Type safety of `failReason` flow.** `BciCalibrationCompleted.data` is `NfbCalibrationData` (`BciCalibrationEvent.dart:26-29`); `NfbCalibrationData.failReason` is a non-null `String` with documented values `"none"`/`"tooManyArtifacts"`/`"peakFrequencyAtBorder"` (`NfbCalibrationData.dart:20`). The reducer assigns `failReason: data.failReason` into the DTO's `String? failReason` — type-safe. The UI helper (`_failureMessage`) matches those exact `.name` strings and falls back to the generic message for the free-form `e.toString()` hard-error case. Consistent end-to-end. ✓
- **All construction sites updated.** `grep` confirms `BciCalibrating(` is constructed only at `BciDeviceManager.dart:240` (full, `totalStages: 4`) and `:254` (quick, `totalStages: 1`); `BciDataService.dart:80` is a pattern match, not a construction, and is unaffected by the new named field. `BciCalibrationProgressDTO(` is constructed only in the four `BciPairingService.dart` reducer branches, all updated with the new required `totalStages`/`failed`. No test files construct either type. The build will compile. ✓
- **Invalid result routing.** `BciDeviceManager` `BciCalibrationCompleted` handler now branches on `data.isValid`: valid → record (guarded by `_connectedSerial != null`) + `BciReady`; invalid → no record + `BciImpedance` (retryable). The `BciCalibrationFailed` handler still routes to `BciImpedance`. Persistence happens only on valid results, as required. ✓
- **Reducer cross-event ordering.** An invalid completion produces both a `BciStateChanged(BciImpedance)` and a `BciCalibrationEventReceived(BciCalibrationCompleted)` (the provider's calibration stream feeds both the manager listener and `BciNotifier`). The `BciImpedance` reducer branch (`BciPairingService.dart:159-165`) never touches `calibration`, and the completed/failed branches never touch `stage`. The settled state (`stage: impedance`, `calibration.failed: true`, `totalStages` preserved from the prior `BciCalibrating` reduce) is order-independent. Confirmed the failure text lives on the DTO and is **not** placed on `errorMessage` (which `BciImpedance` wipes to `null` at `:159`). ✓
- **Retry loop.** Retry → `onRetryCalibration` → `startQuickCalibration`. Guard is `_state is! BciImpedance` (true after a failure routed to impedance), so it proceeds, `_setState(BciCalibrating(serial, totalStages: 1))` resets the DTO (`failed: false`), and the `_setState` dedup does **not** swallow it because the prior state is `BciImpedance` (different runtime type). A subsequent invalid quick result loops back to impedance cleanly. ✓
- **Provider quick path.** `startQuickCalibration` cancels any leftover full-flow `_calibrationSub` before awaiting `calibrateIndividualQuick()`, mirrors the full mapping exactly, emits `BciCalibrationCompleted`, and catches throws into `BciCalibrationFailed`. No stage events emitted (single-stage), matching the UI's single-dot render. ✓
- **UI state mutual exclusivity.** `inProgress` (chime/tick timer + dot block) now excludes `failed`; the green check renders only on `isComplete == true` (which is only set on valid); the failure block + Retry render only on `failed == true`. The completion cue does not play on an invalid result (`isComplete` stays false). No "complete + failed" contradiction is possible. Dots render `totalStages` (1 or 4) with correct trailing-gap logic. ✓

## Non-blocking observations

1. **`_setState` dedup ignores `totalStages` (latent, not live).** `BciDeviceManager._setState` (`:130-140`) dedupes `BciActive` transitions on `runtimeType` + `serial` only. A *direct* `BciCalibrating(totalStages: 4)` → `BciCalibrating(totalStages: 1)` transition would be silently dropped. The current flow always routes full→quick through `BciImpedance` first, so there is no live bug. A one-line comment near `startQuickCalibration` warning against a direct calibrating→calibrating switch would protect a future caller. (Already flagged in plan-review note 1.)

2. **Redundant `AppLocalizations.of(context)` lookup (cosmetic).** `_failureMessage` re-resolves `l10n` even though `build` already holds a local `l10n`. Harmless; could take `l10n` as a parameter for symmetry with `_instruction`.

3. **Generated localizations are committed.** `app_localizations*.dart` were regenerated and staged alongside the ARB edits — good, no separate codegen step is left pending. The `bciPairingCalibrationFailedPeak` apostrophe is correctly escaped (`couldn\'t`) in the generated Dart.

No correctness, security, or runtime-breakage issues found (no migrations involved; no type mismatches; the one race path is order-independent by construction).

REVIEW_PASS
