# Code Review: Implement `BciDataService` + `BciDataCoordinator`

**Plan:** `.ai-factory/plans/59-implement-bcidataservice-bcidatacoordinator.md`
**Changed files (staged):**
- `lib/BciModule/BciDataCoordinator.dart` (new)
- `lib/BciModule/BciDataService.dart` (new)
- `android/.kotlin/sessions/kotlin-compiler-3931374903587441396.salive` (new, stray)
- `.ai-factory/plan-reviews/59-...-plan-review-1.md` (new)
- `.ai-factory/plans/59-...md` (new)

Both production files were read in full. Surrounding code (`BciNotifier`, `BciNotifierEvent`, `BciDataState`, `BciDataViewModel`, `BciPairingService`, `BciPairingCoordinator`, domain model classes, package exports) was also inspected to verify imports, types, and behavioural assumptions.

## Critical Issues

### C1. Stray Kotlin compiler session file staged for commit
`android/.kotlin/sessions/kotlin-compiler-3931374903587441396.salive` is an empty (0-byte) Kotlin Gradle daemon session file. It is staged in the same change set. There is no `.kotlin/` entry in either `mind_mobile/.gitignore` or `mind_mobile/android/.gitignore`, which is why it got picked up. It should not be committed and is unrelated to this milestone.

Fix:
1. Unstage and remove the file: `git rm --cached android/.kotlin/sessions/kotlin-compiler-3931374903587441396.salive` (and delete on disk).
2. Add `.kotlin/` to `android/.gitignore` so the directory is excluded going forward (mirrors the official Flutter gitignore template).

Leaving this in the commit will pollute the repo and likely cause merge churn for any teammate who runs an Android build.

## High Severity

None.

## Medium Severity

### M1. Stale metrics persist across a disconnect → reconnect cycle
`_reduce` for `BciStateChanged` only flips `isConnected`. It does not clear `heartRate`, `nfb`, `emotions`, `channels`, or `batteryPercent` when the connection state transitions to `disconnected`, `bluetoothPermissionDenied`, `scanning`, or `connecting`.

Sequence that breaks:
1. Device is connected; the state carries valid `heartRate`, `nfb`, `emotions`, `channels`, `batteryPercent`.
2. Device disconnects → `isConnected: false`. `BciDataScreen` shows the "Device not connected" empty state, so stale data is hidden.
3. User pairs again → `BciStateChanged(impedance)` arrives → `isConnected: true` flips. The data view re-appears **with the pre-disconnect bar values still in state**, then is overwritten by fresh NFB / emotions / cardio events whenever they next arrive.

The plan-review (item #1) explicitly flagged this and recommended clearing on `disconnected` / `bluetoothPermissionDenied`. The implementer chose the inline `isConnected: ...` boolean form, which makes clearing impossible without an explicit per-state branch. `BciPairingService._reduceStateChanged` does the right thing here (explicit branches that clear `channels` / `calibration` on `disconnected`).

Recommended change: replace the single `acc.copyWith(isConnected: ...)` with a small `switch (state)` that clears transient metrics on the non-connected branches, e.g.:

```dart
case BciStateChanged(:final state):
  switch (state) {
    case BciConnectionState.disconnected:
    case BciConnectionState.bluetoothPermissionDenied:
      return acc.copyWith(
        isConnected: false,
        heartRate: null,
        nfb: null,
        emotions: null,
        batteryPercent: null,
        channels: const <BciChannelQualityDTO>[],
      );
    case BciConnectionState.scanning:
    case BciConnectionState.connecting:
      return acc.copyWith(isConnected: false);
    case BciConnectionState.impedance:
    case BciConnectionState.calibrating:
    case BciConnectionState.ready:
      return acc.copyWith(isConnected: true);
  }
```

(The exact policy — whether to clear on `scanning`/`connecting` too — is a judgement call. The minimum is clearing on `disconnected` + `bluetoothPermissionDenied`.)

## Low Severity / Advisory

### L1. Cold-start gap with the `BehaviorSubject` replay (acknowledged in plan)
`BciNotifier._subject` is a `BehaviorSubject` that replays exactly one event. If the most-recent event happens to be e.g. `BciNfbUpdated` while the device is in fact still connected, the data screen will mount with `nfb` populated but `isConnected: false` — and the empty "Connect" placeholder will appear until the next `BciStateChanged` happens to fire. There is no command method on `IBciDataService` or `BciDataViewModel` to force a re-emit (`BciPairingViewModel.initState()` works around this by calling `startScan()`).

This is pre-existing and the plan explicitly defers it. Worth tracking as a follow-up — the symptom is "BCI data screen says disconnected even though device is actually connected".

### L2. `BciCardioData.heartRate.round()` truncates `NaN` / negatives silently
`BciCardioData.heartRate` is `double`. The mapping uses `(metricsAvailable && !hasArtifacts) ? data.heartRate.round() : null`. If the device ever emits `NaN` or `Infinity` with `metricsAvailable: true`, `double.round()` throws `UnsupportedError`. Unlikely in practice (the device should set `metricsAvailable: false` for bad samples), but a safer formulation is `data.heartRate.isFinite ? data.heartRate.round() : null` inside the guarded branch. Optional hardening only.

### L3. Multi-line `///` doc comment style consistency
The `// NOTE: BciNotifier._subject is a BehaviorSubject...` block uses `//` (non-doc) comments. This is consistent with `BciPairingService`. No action.

### L4. `BciDataCoordinator` does not check route stack
`openPairing()` always pushes `BciPairingScreen.path`. If the user reaches `BciDataScreen` *from* `BciPairingScreen` somehow in the future (currently they cannot — pairing screen has no link to data screen), repeated taps could stack duplicate pairing screens. Not exploitable today; flag for the wiring milestone if navigation grows.

## Correctness Verification

Cross-checked against the codebase:
- `bciNotifier.stream` returns `_subject.stream` (`BehaviorSubject<BciNotifierEvent>`). `.scan()` is provided by rxdart's `StreamExtensions`. ✅
- `BciNotifierEvent` is sealed with exactly the 9 variants the reducer matches; the `switch` is exhaustive without a `default:`. The Dart 3 analyser will enforce this. ✅
- `BciDataState.copyWith` uses `_undefined` sentinels for the nullable fields. `heartRate: null` and `nfb: null` therefore actually clear the field (not no-ops). The implementation correctly relies on this when constructing the CardioUpdated branch. ✅
- `BciNfbData` / `BciEmotionsData` field names match `BciNfbDTO` / `BciEmotionsDTO` 1:1. ✅
- `BciCardioData` has `heartRate: double`, `metricsAvailable: bool`, `hasArtifacts: bool` — mapping is correct. ✅
- `BciSignalLevel { green, yellow, red }` ↔ `BciSignalQuality { good, fair, poor }` mapping matches `BciPairingService._mapLevel`. ✅
- `BciConnectionState` enum has 7 values; the plan correctly classifies `impedance`/`calibrating`/`ready` as connected and the other 4 as not. ✅
- `BciPairingScreen.path = '/$name'` is reachable via `package:bci_module/bci_module.dart` (exported). ✅
- The `BciDataService.events` getter rebuilds the scan stream on every call. `BciDataViewModel.build()` calls it exactly once (stored in `_eventsSubscription`), so no resource leak. If anyone calls `events` twice they get independent scan accumulators — fine for the current consumer; worth being aware of. ✅
- `BciDataCoordinator(this.context)` is positional; `BciModule.buildDataScreen(...)` is intentionally out of scope per the plan. ✅

## Runtime Failure Modes Considered
- No migrations involved (Flutter / Drift schema untouched).
- No new `StreamController` / `StreamSubscription` owned by the service — nothing to dispose. The Riverpod `BciDataViewModel` already owns the subscription via `ref.onDispose`.
- No race conditions: scan accumulates synchronously per-event; rxdart's `scan` operates on the calling stream's serialised event order.
- `BciNotifier.dispose()` closes `_subject`. After that, any active scan stream on the subject will receive `done` and the subscription will complete naturally. No leak.

## Positive Notes
- Imports are tight (uses `show` on the coordinator, package-only on the service).
- Reducer is exhaustive and side-effect free.
- `.toList(growable: false)` consistent with the sibling pairing service.
- The "Re-implement `_mapLevel` locally" boundary decision is respected.

## Verdict

The two production files implement the plan correctly. Blocking concerns are limited to **C1** (stray Kotlin daemon file in the commit) and **M1** (stale metrics across a reconnect cycle). Both are easy fixes.

If only the C1 and M1 fixes are applied, this change is ready to merge.
