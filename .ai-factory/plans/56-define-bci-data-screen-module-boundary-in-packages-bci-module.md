# Plan: Define BCI data screen module boundary in `packages/bci_module`

## Context
Introduce the module-boundary types (DTOs, state, service/coordinator interfaces) for the upcoming `BciDataScreen` inside the existing `bci_module` package. This milestone is types-only — no widgets, no ViewModel, no concrete service. The full screen shapes are pinned in `.ai-factory/notes/24-bci-data-screen.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: DTOs

- [x] **Task 1: Create `BciEmotionsDTO`**
  Files: `packages/bci_module/lib/src/BciData/Models/BciEmotionsDTO.dart`
  Define an immutable class with nullable `double` fields: `attention`, `cognitiveLoad`, `relaxation`, `cognitiveControl`, `selfControl` (all `double?`, values in `0..1`). Provide a `const` constructor with named parameters; no `copyWith`, no JSON. Mirror the field order in `.ai-factory/notes/24-bci-data-screen.md` (DTO section).

- [x] **Task 2: Create `BciNfbDTO`**
  Files: `packages/bci_module/lib/src/BciData/Models/BciNfbDTO.dart`
  Immutable class with nullable `double` fields: `delta`, `theta`, `alpha`, `smr`, `beta`. `const` constructor with named parameters. No `copyWith`, no JSON.

### Phase 2: State

- [x] **Task 3: Create `BciDataState`** (depends on Tasks 1, 2)
  Files: `packages/bci_module/lib/src/BciData/Models/BciDataState.dart`
  Immutable class with fields:
  - `final int? heartRate;`
  - `final BciEmotionsDTO? emotions;`
  - `final BciNfbDTO? nfb;`
  - `final int? batteryPercent;`
  - `final List<BciChannelQualityDTO> channels;`
  - `final bool isConnected;`

  `const` constructor with named parameters; `heartRate`, `emotions`, `nfb`, `batteryPercent` optional, `channels` and `isConnected` required.
  Add `static BciDataState initial()` returning a const instance with all nullable fields `null`, `channels` empty, and `isConnected: false`.
  Add a `copyWith` that supports clearing nullable fields (use the sentinel-object pattern from `BciPairingState.copyWith` — see `packages/bci_module/lib/src/BciPairing/Models/BciPairingState.dart`).
  Import `BciChannelQualityDTO` from `../../BciPairing/Models/BciChannelQualityDTO.dart` (kept at its current path for this milestone; any relocation is out of scope here).

### Phase 3: Interfaces

- [x] **Task 4: Create `IBciDataService`** (depends on Task 3)
  Files: `packages/bci_module/lib/src/BciData/IBciDataService.dart`
  Declare:
  ```dart
  sealed class BciDataEvent { const BciDataEvent(); }
  final class BciDataStateUpdated extends BciDataEvent {
    final BciDataState state;
    const BciDataStateUpdated(this.state);
  }
  abstract class IBciDataService {
    Stream<BciDataEvent> get events;
  }
  ```
  Match style used in `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart` (sealed event base, `final class` subtypes). Import `BciDataState` from `Models/BciDataState.dart`. No imperative methods — this screen is read-only; pairing actions belong to the coordinator.

- [x] **Task 5: Create `IBciDataCoordinator`**
  Files: `packages/bci_module/lib/src/BciData/IBciDataCoordinator.dart`
  Single abstract method `void openPairing();`. No other members.

### Phase 4: Public exports

- [x] **Task 6: Export new symbols from `bci_module.dart`** (depends on Tasks 1–5)
  Files: `packages/bci_module/lib/bci_module.dart`
  Add export lines (group under existing sections — Service/Coordinator interfaces, Other public symbols):
  - `export 'src/BciData/IBciDataService.dart';`
  - `export 'src/BciData/IBciDataCoordinator.dart';`
  - `export 'src/BciData/Models/BciDataState.dart';`
  - `export 'src/BciData/Models/BciEmotionsDTO.dart';`
  - `export 'src/BciData/Models/BciNfbDTO.dart';`
  Keep ordering consistent with the existing pairing exports.

## Commit Plan
- **Commit 1** (after Tasks 1–3): "Add BCI data DTOs and state shape"
- **Commit 2** (after Tasks 4–6): "Add BCI data service/coordinator interfaces and exports"

<!-- orchestrator-sessions
planner: c4f1223b-2b68-4f3a-ad66-3f559ad3c7da
implementer: 4adccaa2-792d-440b-9070-d498d3706693
-->
