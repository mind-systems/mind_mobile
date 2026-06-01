# Plan: Align `BciPairingViewModel` to subscribe in `build()`

## Context
Move `BciPairingViewModel`'s service subscription and initial `startScan()` into `build()` (the canonical Riverpod `Notifier` pattern used by `BciDataViewModel` and `BreathSessionListViewModel`), and remove the now-obsolete public `initState()` method along with its call site in `BciPairingScreen`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Refactor

- [x] **Task 1: Move subscription + `startScan()` into `build()`**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  In `build()`, keep the existing `ref.onDispose(...)` cancel-and-null block, then assign `_eventsSubscription = service.observeChanges().listen(_onServiceEvent);` and call `service.startScan();` before the `return BciPairingState.initial();` — mirroring `BciDataViewModel.build()` (which subscribes before returning the initial state). Delete the public `initState()` method entirely, including its `if (_eventsSubscription != null) return;` guard, which is no longer needed once `build()` owns the single subscription. Leave `_onServiceEvent`, the user-gesture methods (`onDeviceTap`, `onRescan`, `onStartCalibration`, `onDisconnect`), the `_eventsSubscription` field, and the constructor unchanged.

- [x] **Task 2: Remove the `initState()` call site in `BciPairingScreen`** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
  Delete the `_BciPairingScreenState.initState()` override (the `super.initState()` + post-frame `ref.read(bciPairingViewModelProvider.notifier).initState()` block). If this leaves `_BciPairingScreenState` with only a `build()` method and no other stateful logic, the screen can stay a `ConsumerStatefulWidget` for minimal churn, but verify no remaining references to the deleted `initState()` exist. The `_BciPairingHeader` widget is unaffected.
