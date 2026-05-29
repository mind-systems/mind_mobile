# Plan: Remove close button from BciPairingScreen + delete now-empty BciPairingCoordinator

## Context
Enforce the app-wide convention that screen headers have no explicit close button (back navigation uses iOS swipe-back / Android system back), and delete the now-empty `BciPairingCoordinator` along with its interface since `onClose()` is the only thing it powered.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: UI cleanup

- [x] **Task 1: Remove close button and rearrange header row in `BciPairingScreen`**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
  In `_BciPairingHeader.build()` (lines 64–99), delete the `IconButton(icon: Icon(Icons.close), onPressed: vm.onClose)` block (lines 68–71). Rearrange the surrounding `Row` to mirror the sibling `BciDataHeader` layout: battery indicator on the left, `Spacer()` in the middle, red disconnect `TextButton` on the right — i.e. `[batteryRow, Spacer(), disconnectTextButton]`. Remove the now-unused `Spacer()` that previously separated the close button from the battery (only one `Spacer()` remains, between battery and disconnect). The `vm` local can stay (still used by `onDisconnect`) — but if it is no longer referenced after removal of `vm.onClose`, drop it; double-check via the disconnect branch which calls `vm.onDisconnect()` inside the dialog callback, so `vm` stays.

### Phase 2: ViewModel + interface cleanup

- [x] **Task 2: Remove `onClose`, `coordinator` field, and coordinator import from `BciPairingViewModel`** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
  Delete the `onClose()` method (line 59). Delete the `final IBciPairingCoordinator coordinator;` field (line 16) and the `required this.coordinator,` parameter in the constructor (line 22). Delete `import 'IBciPairingCoordinator.dart';` (line 3). The constructor becomes `BciPairingViewModel({ required this.service });`.

- [x] **Task 3: Delete the `IBciPairingCoordinator` interface file** (depends on Task 2)
  Files: `packages/bci_module/lib/src/BciPairing/IBciPairingCoordinator.dart`
  Delete this file entirely.

- [x] **Task 4: Remove `IBciPairingCoordinator` export from the package barrel** (depends on Task 3)
  Files: `packages/bci_module/lib/bci_module.dart`
  Delete the line `export 'src/BciPairing/IBciPairingCoordinator.dart';` (line 9). Keep the surrounding `IBciPairingService` and `IBciDataCoordinator` exports intact.

### Phase 3: App-layer wiring cleanup

- [x] **Task 5: Delete the concrete `BciPairingCoordinator` implementation** (depends on Task 4)
  Files: `lib/BciModule/BciPairingCoordinator.dart`
  Delete this file entirely.

- [x] **Task 6: Remove coordinator wiring from `BciModule.buildPairing`** (depends on Task 5)
  Files: `lib/BciModule/BciModule.dart`
  In `buildPairing()` (lines 11–22): delete the line `final coordinator = BciPairingCoordinator(context);` and remove the `coordinator: coordinator,` argument from the `BciPairingViewModel(...)` constructor call so it reads `BciPairingViewModel(service: service)`. Delete the `import 'package:mind/BciModule/BciPairingCoordinator.dart';` line. Leave `buildDataScreen()` and its `BciDataCoordinator` wiring untouched.

<!-- orchestrator-sessions
planner: cbafab6f-f28e-45dd-a459-22c7289cc3e8
elapsed: 426
implementer: 50e34b33-c1ff-4392-a8d2-60e261ae494c
-->
