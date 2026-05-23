# Plan: Implement `BciDataViewModel`

## Context
Add the presentation-layer ViewModel for the BCI data screen inside `packages/bci_module`. It bridges `IBciDataService` events into a Riverpod-managed `BciDataState` for the upcoming `BciDataScreen`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: ViewModel

- [x] **Task 1: Create `BciDataViewModel` + provider**
  Files: `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
  Create a new file modelled on `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`. Required content:
  - Imports: `dart:async`, `package:flutter_riverpod/flutter_riverpod.dart`, `IBciDataCoordinator.dart`, `IBciDataService.dart`, `Models/BciDataState.dart`.
  - Top-level provider:
    ```dart
    final bciDataViewModelProvider =
        NotifierProvider<BciDataViewModel, BciDataState>(() {
      throw UnimplementedError(
        'BciDataViewModel must be overridden via ProviderScope',
      );
    });
    ```
  - `class BciDataViewModel extends Notifier<BciDataState>` with:
    - `final IBciDataService service;`
    - `final IBciDataCoordinator coordinator;` (injected for future user gestures such as the disconnected-state "Connect" button — keep it as a constructor field even though no gesture method is added in this task)
    - `StreamSubscription<BciDataEvent>? _eventsSubscription;`
    - Constructor: `BciDataViewModel({required this.service, required this.coordinator});`
  - `@override BciDataState build()`:
    - Register `ref.onDispose(() { _eventsSubscription?.cancel(); _eventsSubscription = null; });` **before** subscribing (same defensive pattern used in `BciPairingViewModel.build()` per the post-review fix in roadmap line 101).
    - Subscribe: `_eventsSubscription = service.events.listen(_onServiceEvent);`
    - Return `BciDataState.initial()`.
  - Private handler:
    ```dart
    void _onServiceEvent(BciDataEvent event) {
      switch (event) {
        case BciDataStateUpdated(:final state):
          this.state = state;
      }
    }
    ```
  Do not add an `initState()` method — unlike `BciPairingViewModel`, this ViewModel has no deferred imperative trigger (no `startScan`); the spec explicitly says subscription happens in `build()`. Do not add user-gesture methods in this task — they belong to the screen task that follows.

- [x] **Task 2: Export the ViewModel from the package barrel** (depends on Task 1)
  Files: `packages/bci_module/lib/bci_module.dart`
  Add `export 'src/BciData/BciDataViewModel.dart';` in the `// ViewModels` section (immediately after the existing `export 'src/BciPairing/BciPairingViewModel.dart';` line) so the provider and class are reachable from `lib/BciModule/BciModule.dart` for the later wiring task.

<!-- orchestrator-sessions
planner: 78a0f446-4911-4b14-9d8f-9b239860d2f7
implementer: c0da60af-3197-497b-9e89-928ca3a30f1c
-->
