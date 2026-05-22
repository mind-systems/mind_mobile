# Plan Review: Implement `BciPairingService` + `BciPairingCoordinator` (v2)

**Plan:** `.ai-factory/plans/44-implement-bcipairingservice-bcipairingcoordinator.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** ✅ Concrete `Service` lives in `lib/BciModule/`, implements `IBciPairingService` declared in `packages/bci_module/`, and converts domain models (`BciDeviceInfo`, `BciChannelQuality`, `BciCalibrationEvent`) → DTOs. Domain types never cross the module boundary. Coordinator depends only on GoRouter + the package's `IBciPairingCoordinator` — matches existing `BreathSessionCoordinator` shape.
- **RULES.md:** ✅ Stateless service (only `bciNotifier` field, no `StreamController`, no `StreamSubscription`, no `dispose()`); `observeChanges()` derives directly from `bciNotifier.stream`; Riverpod owns the lifecycle. All deps injected via constructor. Matches all three rules.
- **ROADMAP.md:** ✅ Task scope matches the open BCI pairing milestone; the follow-on wiring task (`BciModule.dart` + `App.dart` + `router.dart`) is deliberately out of scope.

## Resolution of Prior Review (review-1)

| Prior issue | Status in v2 |
|---|---|
| (1) `copyWith(channels: null)` is a no-op; must pass empty const list | ✅ Resolved — `channels: const <BciChannelQualityDTO>[]` is explicit in the `disconnected` branch, with an inline comment calling out the `null` footgun. |
| (2) `errorMessage` stale-state stance | ✅ Resolved — clear on every non-error `BciStateChanged` branch; re-populated only by `BciError` / `BciCalibrationFailed`. Each branch shows `errorMessage: null`, and the plan asks for a comment on `_reduce` documenting the stance. |
| (3) `BehaviorSubject` replay assumption | ✅ Resolved — load-bearing note added (lines 45) plus a request for a one-line comment above `observeChanges()`. |
| (4) Switch-over-sealed-type exhaustiveness | ✅ Resolved — plan now explicitly mandates `switch (event)` over chained `if (event is …)`. |
| (5) Behaviour of `devices` / `batteryPercent` on `disconnected` | ✅ Resolved — "keep as-is" decision documented with rationale. |

## Verification of Codebase Assumptions

Spot-checked the v2 plan against the codebase:

| Claim | Status |
|---|---|
| `lib/BciModule/` does not exist yet | ✅ Confirmed |
| `IBciPairingService` interface shape (observeChanges + 4 void commands) | ✅ Confirmed (`packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`) |
| `IBciPairingCoordinator.close()` | ✅ Confirmed |
| `BciNotifier` exposes `stream`, `knownSerials`, `startScan/connectDevice/startCalibration/disconnect` returning `Future<void>` | ✅ Confirmed |
| `BciNotifier._subject` is a `BehaviorSubject<BciNotifierEvent>` (single-event replay) | ✅ Confirmed |
| `BciNotifierEvent` sealed; 6 variants used in plan | ✅ Confirmed |
| `BciCalibrationEvent` sealed; 3 variants used in plan; stage is 1-indexed (provider emits `stage.index + 1`) | ✅ Confirmed |
| `BciConnectionState` enum has the 6 values handled by `_mapStage` | ✅ Confirmed (`disconnected/scanning/connecting/impedance/calibrating/ready`) |
| `BciPairingState.copyWith` uses `_undefined` sentinel for `calibration`, `batteryPercent`, `errorMessage`; plain `List?` for `channels`, `devices` | ✅ Confirmed — explains why the `const []` distinction in the plan matters |
| `BciPairingStage` enum (`discovery/impedance/calibrating/ready`) | ✅ Confirmed |
| `BciCalibrationProgressDTO` carries `stagesCompleted` + `isComplete` (matches plan's reduction) | ✅ Confirmed |
| `BciDeviceInfo { serial, name }` and `BciScannedDeviceDTO { serial, name, isKnown }` mapping fields line up | ✅ Confirmed |
| `BciSignalLevel { green, yellow, red }` ↔ `BciSignalQuality { good, fair, poor }` mapping | ✅ Consistent |
| `bci_module.dart` exports all symbols referenced by the plan's imports list | ✅ Confirmed |
| `BreathSessionCoordinator.dismiss()` mounts-guard + `context.pop()` shape | ✅ Mirrored exactly |
| `BreathSessionListService` uses `switch (event)` over sealed `BreathSessionNotifierEvent` | ✅ Mirrored — pattern is consistent |
| `dart:async` exports `unawaited` | ✅ Confirmed |
| `rxdart` `scan` extension signature `(S Function(S, T, int), S seed)` | ✅ Confirmed against the prior review's pin |

## Issues

### Critical
*(none)*

### Important
*(none)*

### Minor / Worth Considering

1. **"Pure function" terminology in `_reduce`.** The plan calls `_reduce` "pure" (line 47), but the `BciDevicesDiscovered` branch reads `bciNotifier.knownSerials.toSet()` from the surrounding instance. This is fine — `knownSerials` is a snapshot read, not a mutation — but the wording could mislead. Suggest dropping "pure" or qualifying as "deterministic w.r.t. (acc, event) given the notifier's cached known-serials snapshot". Non-blocking.

2. **`calibration` persistence across `ready` transition.** When the device transitions `calibrating → ready` via `BciStateChanged(BciConnectionState.ready)`, the plan does not touch `calibration`, so the last `BciCalibrationProgressDTO` (typically `{stagesCompleted: 4, isComplete: true}`) survives into the ready state. This is almost certainly desired (UI may want to render the green check-mark next to the calibration step on the ready screen), but the plan does not explicitly say so. A single-line note in the reducer comment ("`calibration` intentionally preserved across `→ ready` so the success state remains visible to the UI") would prevent a later reviewer from "fixing" it. Non-blocking.

3. **`unawaited(bciNotifier.startScan())` swallows synchronous throws into the Dart zone.** `BciDeviceManager.startScan()` (under `bciNotifier.startScan`) can synchronously throw if BLE prerequisites aren't satisfied — those won't reach the `BciError` stream because the stream's `onError` only catches errors emitted from the manager's underlying streams, not from imperative command calls. The interface is intentionally fire-and-forget (`void`), so this isn't a contract violation, but the user-visible failure path would be silent. Worth confirming the plan implementer (or the next milestone) considers wrapping command bodies in `try { unawaited(…); } catch (e) { /* surface via BciError or log */ }`. Non-blocking for *this* plan since the interface forbids returning a future; arguably belongs in the next milestone.

4. **Allocation in the `BciDevicesDiscovered` branch.** `bciNotifier.knownSerials.toSet()` allocates a fresh `Set` on every discovery emission. Discovery emissions are low-frequency (≤ a few Hz), so this is a non-issue. Mentioning only to pre-empt a "we could lift this" comment in code review.

## Positive Notes

- All five revisions requested in review-1 land cleanly — no half-fixes.
- The inline comments the plan asks the implementer to add (BehaviorSubject replay assumption, `errorMessage` clearing stance, `copyWith` semantics for `channels` / `devices`) are exactly the comments a fresh maintainer would need.
- `scan` over the `expand(state.lastEvent)` pattern is the right choice — `BciNotifier` emits typed slice events, not whole-state-with-event-tail like `BreathSessionNotifier`.
- Imports list is complete and accurate; the `dart:async` import for `unawaited` is the only piece that's easy to forget and the plan calls it out.
- `_mapStage` and `_mapLevel` helper extractions keep `_reduce` readable and mirror the established `BreathSessionListService._mapEvent` shape.
- Coordinator mirrors `BreathSessionCoordinator.dismiss()` including the `context.mounted` guard — zero surprises.
- Scope discipline maintained: the plan resists doing the next-milestone wiring.

## Verdict

The plan is ready to implement. All issues from review-1 are resolved, no new critical or important issues surfaced, and the few minor observations above are documentation polish rather than design problems.

PLAN_REVIEW_PASS
