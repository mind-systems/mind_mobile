# Plan Review: Implement `BciDataService` + `BciDataCoordinator`

**Plan:** `.ai-factory/plans/59-implement-bcidataservice-bcidatacoordinator.md`
**Risk Level:** 🟢 Low

## Code-context verification

Verified against the codebase:
- `lib/BciModule/BciPairingService.dart` — pattern the new service mirrors (scan-into-state, `_mapLevel`, ignoring out-of-scope events). ✅
- `lib/BciModule/BciPairingCoordinator.dart` — positional `BuildContext`, `!context.mounted` guard, GoRouter `context.push/pop`. ✅
- `packages/bci_module/lib/src/BciData/IBciDataService.dart` — interface exposes `Stream<BciDataEvent> get events` (a getter, not a method like `observeChanges()`). The plan uses `Stream<BciDataEvent> get events` correctly. ✅
- `packages/bci_module/lib/src/BciData/IBciDataCoordinator.dart` — single `void openPairing()` method. ✅
- `packages/bci_module/lib/src/BciData/Models/BciDataState.dart` — `copyWith` accepts `Object? = _undefined` sentinels for nullable fields (`heartRate`, `emotions`, `nfb`, `batteryPercent`), and plain `T?` for `channels`/`isConnected`. The reducer rules in the plan match these signatures (e.g. setting `heartRate: null` actually clears via the sentinel-treated parameter). ✅
- `lib/Bci/Models/BciNotifierEvent.dart` — sealed class with exactly the 9 variants the plan switches on. Pattern is exhaustive. ✅
- `lib/Bci/Models/BciConnectionState.dart` — enum values match those listed in the reducer (`disconnected`, `scanning`, `connecting`, `impedance`, `calibrating`, `ready`, `bluetoothPermissionDenied`). ✅
- `lib/Bci/Models/BciCardioData.dart`, `BciNfbData.dart`, `BciEmotionsData.dart` — field shapes match the DTO mapping. ✅
- `BciPairingScreen.path = '/bci_pairing'` exists and is exported via `package:bci_module/bci_module.dart`. ✅
- `bci_module.dart` already exports `IBciDataService`, `BciDataEvent`, `BciDataStateUpdated`, `BciDataState`, `BciNfbDTO`, `BciEmotionsDTO`, `BciChannelQualityDTO`, and `BciSignalQuality` (via `BciPairing/Models/BciChannelQualityDTO.dart`). Importing `package:bci_module/bci_module.dart` is sufficient — no need to reach into `src/`. ✅

## Context Gates

- **ARCHITECTURE.md** — PASS. Plan respects the domain↔module boundary: service implements an interface declared inside the package, depends on `BciNotifier` + domain models, converts to DTOs.
- **RULES.md** — PASS. The service is stateless (no `StreamController`, no `StreamSubscription`, no `dispose()`); `events` is a derived stream off `bciNotifier.stream`. Riverpod's `BciDataViewModel.build()` already owns the subscription via `ref.onDispose`. Dependencies injected via constructor. App.dart untouched.
- **ROADMAP.md** — Not checked against, but the plan explicitly defers wiring (`BciModule.buildDataScreen` / route) to a follow-up milestone, matching the staged approach used elsewhere.

## Critical Issues

None.

## Advisory / Minor Issues

### 1. Stale data on disconnect (design choice — worth confirming)
The plan's `BciStateChanged` reducer only flips `isConnected`. It does NOT clear `heartRate`, `nfb`, `emotions`, or `channels` when the device transitions to `disconnected`/`bluetoothPermissionDenied`. By contrast, `BciPairingService._reduceStateChanged` clears `channels` and `calibration` on `disconnected`.

Visually this is masked because `BciDataScreen` renders the "Device not connected" empty state when `!isConnected`, but the underlying `BciDataState` will carry stale bar values across reconnects. If the user disconnects, then reconnects, the first frame after `isConnected → true` may show old NFB/emotion values briefly before fresh events arrive.

Recommend explicitly clearing transient metrics on `disconnected` (and probably `bluetoothPermissionDenied`):
```dart
case BciConnectionState.disconnected:
  return acc.copyWith(
    isConnected: false,
    heartRate: null,
    nfb: null,
    emotions: null,
    channels: const <BciChannelQualityDTO>[],
    // keep batteryPercent? probably null too
  );
```
This is a judgement call — if the team prefers "last known good" until the next event, the current plan is fine. Flagging so the implementer doesn't silently pick one behaviour.

### 2. Initial-state cold start (acknowledged in plan, but no compensating action)
`BciNotifier._subject` is a `BehaviorSubject` that replays **only the single most-recent event**. If the most-recent event is e.g. `BciNfbUpdated`, the data screen mounts and the reducer produces a state with `nfb` populated but `isConnected: false` (carried from `initial()`), which trips the empty-connect screen even though the device is connected.

`BciPairingViewModel.initState()` works around this by calling `startScan()` to trigger fresh emissions. `BciDataViewModel` (already implemented in the package) does not call any such command, and `IBciDataService` has no command method to provide one.

This is **not introduced by this plan** — it's a pre-existing architectural gap in the data flow. But the plan is the natural place to either:
- Add a `void refresh()` (or similar) on `IBciDataService` that re-emits the current `BciConnectionState`, **or**
- Document explicitly that the consuming milestone (`buildDataScreen` / route wiring) must address it.

The plan does mention the BehaviorSubject caveat in "Notes for the implementer" but stops at "Reducer must produce a sensible state when events arrive in any order" — which doesn't actually solve the cold-start case described above. Worth tightening.

### 3. Missing import called out explicitly
The plan lists imports loosely as "`package:mind/Bci/BciNotifier.dart` + the `Models/*` files". The implementer will need:
- `package:mind/Bci/Models/BciNotifierEvent.dart` (sealed event class + variants)
- `package:mind/Bci/Models/BciConnectionState.dart`
- `package:mind/Bci/Models/BciChannelQuality.dart` (for `BciSignalLevel` enum used by `_mapLevel`)

`BciPairingService` imports all three explicitly. Worth naming `BciChannelQuality.dart` so the implementer doesn't miss `BciSignalLevel`.

### 4. `.toList(growable: false)` consistency
The plan describes mapping `channels` but doesn't specify `.toList(growable: false)`. `BciPairingService` uses `.toList(growable: false)` for both the `devices` and `channels` mappings. Recommend the implementer mirror this for consistency (and the small perf win). Trivial.

### 5. Service does not need to clear `errorMessage`
`BciDataState` has no `errorMessage` field (verified in `BciDataState.dart`), so the plan correctly does not handle `BciError` beyond `return acc`. No action needed — noting only because `BciPairingService` does the opposite and someone copying its structure might over-port the error-handling branch.

## Positive Notes

- Plan is appropriately small and focused — only the two missing wiring pieces, with explicit out-of-scope notes for downstream wiring.
- Exhaustive `switch` over the sealed `BciNotifierEvent` with each branch named — no `default:` fallthrough that could silently swallow new event variants.
- Correctly recognises the `_undefined` sentinel semantics in `BciDataState.copyWith` (setting `heartRate: null` actually clears, doesn't become a no-op).
- DRY-vs-coupling tradeoff for `_mapLevel` is explicit ("Re-implement locally — do not depend on `BciPairingService`"), and matches the module-boundary intent.
- Coordinator design is the simplest possible thing that works and matches the existing `BciPairingCoordinator` style perfectly.
- RULES.md compliance is automatic via the chosen `.scan().map()` pattern — no subscription owned by the service.

## Verdict

The plan is solid and ready for implementation. The advisory items are improvements rather than blockers — none of them prevent the resulting code from working correctly for the most common flows. Item #1 (clearing on disconnect) is the most worth addressing inline; item #2 is acknowledged-pre-existing and can be deferred but should be tracked.

PLAN_REVIEW_PASS
