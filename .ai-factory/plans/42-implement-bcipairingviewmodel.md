# Plan: Implement `BciPairingViewModel`

## Context
Create the Riverpod ViewModel that lives inside the `bci_module` package and acts as the module's presentation root. It subscribes to `IBciPairingService.observeChanges()`, mirrors the rolling `BciPairingState` into Riverpod, triggers an initial `service.startScan()`, and forwards user gestures (`onDeviceTap`, `onStartCalibration`, `onDisconnect`, `onClose`) to the service/coordinator pair so the upcoming `BciPairingScreen` can drive the flow without knowing about the domain layer.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Assumptions
- The milestone description references `service.events` and `StateNotifier<BciPairingState>`. The actual interface method (Plan 40, `IBciPairingService`) is `observeChanges()`, and the established project pattern (`BreathViewModel` at `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`) uses Riverpod `Notifier`, not legacy `StateNotifier`. This plan follows the project pattern (`Notifier<BciPairingState>` with `observeChanges()`) — the public ViewModel API and provider behaviour described in the milestone are preserved.
- "Constructor subscribes / calls `startScan()`" is implemented via the Riverpod-idiomatic equivalent: a synchronous `initState()` method called once by the assembler (mirrors `BreathViewModel.initState()`). The actual Dart constructor only captures `service` + `coordinator`; subscription and `startScan()` happen in `initState()` after `build()` runs so `ref.onDispose` is available. The wiring task in the next milestone (`BciModule.buildPairing`) will be responsible for calling `initState()` after `ProviderScope` is set up.

## Tasks

### Phase 1: ViewModel implementation

- [x] **Task 1: Create `BciPairingViewModel` with provider and lifecycle**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  Create the file with these elements, modelled on `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`:

  1. Imports: `dart:async`, `package:flutter_riverpod/flutter_riverpod.dart`, local relative imports for `IBciPairingService.dart`, `IBciPairingCoordinator.dart`, and `Models/BciPairingState.dart`. No imports from `lib/Bci/` or any other domain path — this file lives inside the package and must compile against the package's own interfaces only.
  2. Declare the provider at top-level, throwing `UnimplementedError` so the host app must override it via `ProviderScope` (same pattern as `breathViewModelProvider`):
     ```dart
     final bciPairingViewModelProvider =
         NotifierProvider<BciPairingViewModel, BciPairingState>(() {
       throw UnimplementedError(
         'BciPairingViewModel must be overridden via ProviderScope',
       );
     });
     ```
  3. Class `BciPairingViewModel extends Notifier<BciPairingState>`:
     - Final fields: `IBciPairingService service`, `IBciPairingCoordinator coordinator`.
     - Private field: `StreamSubscription<BciPairingServiceEvent>? _eventsSubscription`.
     - Default constructor with `required` named parameters for `service` and `coordinator`.
     - Override `build()` to register `ref.onDispose(() => _eventsSubscription?.cancel())` and return `BciPairingState.initial()`. Do **not** subscribe inside `build()` — Riverpod re-runs `build()`, and we want a single subscription tied to the screen lifetime, started explicitly via `initState()`.
     - Public `void initState()` method called once by the module assembler after the provider scope is created. Behaviour:
       - Guard against double-subscription: `if (_eventsSubscription != null) return;`
       - Subscribe: `_eventsSubscription = service.observeChanges().listen(_onServiceEvent);`
       - Kick off discovery: `service.startScan();`
     - Private `void _onServiceEvent(BciPairingServiceEvent event)` using a sealed `switch` on `event` (the only variant today is `BciPairingStateUpdated`, but the `switch` must be exhaustive so adding new variants in the future is a compile error rather than a silent miss):
       ```dart
       switch (event) {
         case BciPairingStateUpdated(:final state):
           this.state = state;
       }
       ```

- [x] **Task 2: Add gesture-forwarding methods** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  Add four public methods on `BciPairingViewModel`, each a thin forward — no local state mutation, the next service event will refresh `state`:
  - `void onDeviceTap(String serial) => service.connectDevice(serial);`
  - `void onStartCalibration() => service.startCalibration();`
  - `void onDisconnect() => service.disconnect();`
  - `void onClose() => coordinator.close();`

  These match the gesture names that `BciPairingScreen` (next milestone) will call, and the action verbs on `IBciPairingService` / `IBciPairingCoordinator` defined in Plan 40.

### Phase 2: Public export

- [x] **Task 3: Export `BciPairingViewModel` from the package barrel** (depends on Task 1)
  Files: `packages/bci_module/lib/bci_module.dart`
  Under the existing `// ViewModels` comment header (currently empty), add:
  ```dart
  export 'src/BciPairing/BciPairingViewModel.dart';
  ```
  This also re-exports `bciPairingViewModelProvider` since it's a top-level declaration in the same file. Verify the package still compiles by running `/usr/local/bin/flutter pub get` followed by `/usr/local/bin/flutter analyze packages/bci_module` from the repo root.
