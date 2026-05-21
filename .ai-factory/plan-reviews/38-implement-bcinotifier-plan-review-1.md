# Plan Review: Implement `BciNotifier`

**Plan file:** `.ai-factory/plans/38-implement-bcinotifier.md`
**Reviewed against:** working tree at the time of review
**Risk Level:** 🟢 Low

## Summary

The plan accurately reflects the current codebase. The three target objects exist exactly as described:

- `lib/Bci/BciDeviceManager.dart` already exposes `stateStream`, `discoveredDevicesStream`, `signalQualityStream`, `batteryStream`, `calibrationStream`, `discoveredDevices`, and `cachedSerials()` — Task 2's subscription list and getter delegation line up 1:1 with the available surface.
- `lib/Bci/BciDeviceRepository.dart` constructor signature `BciDeviceRepository({required BciDevicesGrpcApi api, required SharedPreferences prefs})` matches the wiring spec in Task 3.
- `lib/Bci/BciDevicesGrpcApi.dart` takes a `BciDevicesServiceClient`, and `GrpcClient.bciDevicesService` exists at `lib/Core/Grpc/GrpcClient.dart:32`. The plan's "use `bciDevicesService`, not `channel`" note is correct and useful.
- `NeiryBciProvider` exposes broadcast `StreamController`s for connection/quality/battery/calibration, so a second listener (the new `BciNotifier`) on `calibrationStream` will not collide with the manager's existing subscription. No issue.
- `BciCalibrationEvent` is a sealed class with `final class` variants — Task 1's "mirror this style" instruction is consistent with the file at `lib/Bci/Models/BciCalibrationEvent.dart`.
- `lib/Logger.dart` exists and exports `logPrint` — the plan's import path is correct.

## Context Gates

- **ARCHITECTURE.md** — PASS. `BciNotifier` slots into the domain layer (pure Dart, RxDart `BehaviorSubject`) exactly as the layer stack describes. App.dart wiring follows the manual-DI pattern.
- **RULES.md** — PASS. The plan explicitly forbids Flutter/Riverpod imports in the notifier, all dependencies are injected via constructor, and App.dart only gains generic infrastructure wiring (no module-specific behaviour). The plan reiterates the RULES.md "domain notifier stays pure" rule.
- **ROADMAP.md** — PASS. Phase 17's "Implement `BciNotifier`" item describes the same scope; this plan is the concrete expansion of that bullet.

## Critical Issues

None.

## Minor Notes / Improvements

1. **BehaviorSubject replay semantics doc nit (Task 2 — Notes block).**
   The current wording — *"A late subscriber to a `BehaviorSubject` will still receive the last value once one is published"* — is technically true but slightly misleading in this context. The stream carries heterogeneous event types (`BciStateChanged`, `BciDevicesDiscovered`, `BciSignalQualityUpdated`, …), so a late subscriber gets only the **most recently emitted event** of whatever variant that happened to be. They will not get the current `BciConnectionState` unless the last event was a `BciStateChanged`. The synchronous getters (`currentState`, `discoveredDevices`, `knownSerials`) are the correct way to bootstrap initial state.
   Consider rewording the note to: *"A late subscriber receives only the single most recent event regardless of variant; consumers must bootstrap initial state from the synchronous getters, not the stream."*

2. **Stream broadcast assumption is implicit.**
   Tasks 2 subscribes to `manager.calibrationStream`, which is a passthrough of `_provider.calibrationStream`. The manager itself already subscribes to this stream in `_subscribeProviderStreams` (`lib/Bci/BciDeviceManager.dart:53`). This works only because `NeiryBciProvider` exposes a broadcast controller (verified). Worth a single line in the plan stating "all underlying provider streams are broadcast, so adding a second subscriber in the notifier is safe" — otherwise a reader unfamiliar with `NeiryBciProvider` may worry about a `Stream has already been listened to` error.

3. **`catchError` return type quirk (Task 3 — bullet 4).**
   `bciRepository.fetchKnownSerials()` returns `Future<List<String>>`. The plan writes `unawaited(bciRepository.fetchKnownSerials().catchError((Object e) { return <String>[]; }));`. This compiles and runs (Dart treats `catchError`'s onError as `Function`), but the implementor may hit an analyzer warning because `unawaited` expects `Future<void>` semantically. The idiomatic equivalent that silences the analyzer in similar spots elsewhere in this repo (see `DeviceRepository.ping()` call at `App.dart:130`) is fine because `ping` returns `Future<void>`. Two safer alternatives:
   - `unawaited(bciRepository.fetchKnownSerials().then((_) {}).catchError((Object e) { /* swallow */ }));`, or
   - just `bciRepository.fetchKnownSerials().catchError(...);` without `unawaited` (most concise — the dangling future will not produce an unhandled-error if `catchError` is attached).
   Not a blocker; just a heads-up.

4. **Dispose ownership.**
   `BciNotifier.dispose()` awaits `manager.dispose()`. That implies the notifier *owns* the manager. Since the plan creates the manager and notifier together inside `App.initialize()` and stores only the notifier on `App`, this ownership is consistent. Worth one line in Task 3 making this explicit ("`bciDeviceManager` is owned by `bciNotifier` — no field on `App` for it"), so a future maintainer doesn't try to share the manager with another consumer and accidentally double-dispose it.

5. **No `dispose()` site for `BciNotifier`.**
   The notifier exposes `Future<void> dispose()` but the plan doesn't wire it anywhere. This mirrors how `TokenNotifier.dispose()` is also not called (singleton App lifetime), so it's consistent with the rest of the codebase — no change requested. Just noting it for completeness.

6. **`BciError` is emitted but never observed in this plan.**
   Task 2 adds `BciError(String)` events on subscription errors. The downstream `BciPairingService` (Phase 17's next-but-one task) will need to map these to `errorMessage`. Not a problem for this plan, but worth a forward-reference comment in the notifier so the next plan author knows the error semantics already exist.

## Positive Notes

- Plan correctly identifies and pre-emptively fixes the milestone description's `grpcClient.channel` typo.
- Subscription field placement (`late final` or nullable `StreamSubscription`) and disposal pattern are spelled out — no ambiguity left for the implementor.
- The decision to **not** seed `BehaviorSubject` with an initial event is correct: the manager owns canonical state and re-publishing on subscribe would require synthesising events of arbitrary variants.
- File paths, constructor signatures, and import paths all match the working tree exactly.
- The plan respects the App.dart style header rules (single-line initializers, no trailing commas inside `initialize()`).

PLAN_REVIEW_PASS
