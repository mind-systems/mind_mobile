# Code Review: `BciPairingService` + `BciPairingCoordinator`

**Plan:** `.ai-factory/plans/44-implement-bcipairingservice-bcipairingcoordinator.md`
**Files reviewed:**
- `lib/BciModule/BciPairingService.dart` (new, 181 lines)
- `lib/BciModule/BciPairingCoordinator.dart` (new, 15 lines)

## Scope verification

`git status` confirms the only code additions are the two files listed in the plan. The other staged paths are documentation artifacts (`.ai-factory/plan-reviews/*` and the plan itself). No incidental edits, no missing wiring (`BciModule.dart` / `App.dart` / `router.dart` are correctly deferred — they belong to the next milestone).

## Correctness

Walked the reducer against the live domain types:

| Concern | Status |
|---|---|
| `BciNotifierEvent` switch is exhaustive over all 6 sealed variants | ✅ All variants matched (`BciStateChanged`, `BciDevicesDiscovered`, `BciSignalQualityUpdated`, `BciCalibrationEventReceived`, `BciBatteryUpdated`, `BciError`); the compiler will catch any future variant addition. |
| `BciConnectionState` switch is exhaustive over all 6 enum values | ✅ All six cases (`disconnected`, `scanning`, `connecting`, `impedance`, `calibrating`, `ready`) are present in `_reduceStateChanged`. |
| `BciCalibrationEvent` switch is exhaustive over all 3 variants | ✅ All three (`BciCalibrationStageFinished`, `BciCalibrationCompleted`, `BciCalibrationFailed`) are present in `_reduceCalibrationEvent`. |
| `BciSignalLevel` switch is exhaustive over `green/yellow/red` | ✅ All three covered in `_mapLevel`. |
| **Critical fix from plan-review-1: `channels` cleared with empty const list, not `null`** | ✅ Line 97 uses `channels: const <BciChannelQualityDTO>[]` — the `null ??` no-op trap is correctly avoided. Inline comment explains why. |
| `calibration: null` and `errorMessage: null` clearing | ✅ Both fields use the `_undefined` sentinel in `BciPairingState.copyWith`, so passing `null` correctly clears. Verified against `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart:58–66`. |
| `errorMessage` cleared on every non-error `BciStateChanged` branch | ✅ Lines 98, 106, 114, 122, 130, 138 — all six branches set `errorMessage: null`. Stance matches the plan; in-code comment (lines 48–51) documents the rule. |
| `devices` and `batteryPercent` preserved on `disconnected` | ✅ Neither is passed to `copyWith`, so they fall through to `this.devices` / `this.batteryPercent`. Matches the plan's UX call. |
| Stage indexing | ✅ `BciCalibrationStageFinished.stage` is the already-1-indexed value emitted by `NeiryBciProvider`; the service forwards it unchanged to `stagesCompleted`. |
| Signal-level mapping (`green→good`, `yellow→fair`, `red→poor`) | ✅ Correct. |
| `isKnown` derivation uses `Set` for O(1) lookup | ✅ `bciNotifier.knownSerials.toSet()` once per `BciDevicesDiscovered`. |
| Command methods are fire-and-forget with `unawaited` | ✅ All four (`startScan`, `connectDevice`, `startCalibration`, `disconnect`) wrap the `Future<void>` from `BciNotifier`. `dart:async` is imported. |
| Coordinator guards against unmounted context | ✅ `if (!context.mounted) return; context.pop();` — matches `BreathSessionCoordinator.dismiss()`. |
| Service is stateless (no fields beyond `bciNotifier`, no `dispose`, no controllers/subscriptions) | ✅ Matches `.ai-factory/RULES.md` rule 1 and the `BreathSessionListService` pattern. |
| `BehaviorSubject` replay assumption documented | ✅ Lines 16–19 carry the load-bearing comment from the plan. |

## Runtime concerns considered

- **Per-subscriber scan state.** Each call to `observeChanges()` creates a fresh `scan` chain seeded with `BciPairingState.initial()`, so two simultaneous subscribers would accumulate independent state. Riverpod's `BciPairingViewModel` (already in the tree at `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart:34`) only subscribes once via `service.observeChanges().listen(...)`, so this isn't exercised today — but it is a property the next-milestone wiring will need to respect (single `ProviderScope`, single subscriber). Not a defect in this change.
- **Initial state delivery.** The `BehaviorSubject` will replay its single most-recent event into the new subscriber's `scan`. Combined with `BciPairingViewModel.initState()` calling `service.startScan()` immediately after subscribing (line 34–35 of the ViewModel), the manager re-emits connection state / discovered devices, so the screen never relies on multi-event replay. Aligns with the plan.
- **Variable shadowing in `_reduce`.** `case BciCalibrationEventReceived(:final event)` shadows the outer `event` parameter inside that case arm. Dart accepts this and the inner `event` (typed `BciCalibrationEvent`) is what's passed to `_reduceCalibrationEvent`. Stylistic nit, not a bug — flagging only for transparency.
- **Type cast safety.** `BciPairingState.copyWith` uses `calibration as BciCalibrationProgressDTO?` and `errorMessage as String?` after the `_undefined` check. The service only ever passes `null`, a `BciCalibrationProgressDTO`, or a `String` to the respective slots, so the casts cannot throw at runtime.
- **`BciCalibrationCompleted` arriving without prior stage events.** `_reduceCalibrationEvent` defends with `acc.calibration?.stagesCompleted ?? 0`. The DTO will then show `isComplete: true, stagesCompleted: 0`, which is a reasonable terminal state.

## Security / data leakage

No external IO, no persistence, no logging of identifiers. Coordinator uses `go_router`'s `context.pop()` only. Nothing to flag.

## Style / minor

- File header imports are split into multiple `package:` lines but not alphabetically ordered (rxdart, bci_module, mind/*). Matches the surrounding codebase's loose ordering — no action needed.
- The comment on line 97 ends with double-space alignment vs. line 96/98's single-space alignment. Cosmetic only.

REVIEW_PASS
