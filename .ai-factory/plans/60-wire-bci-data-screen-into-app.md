# Plan: Wire BCI data screen into app

## Context
The `BciDataScreen` and its supporting service/coordinator/view model have all been implemented, but nothing instantiates them or routes to them yet. This milestone connects them into `BciModule`, registers a GoRoute, and replaces the `openComingSoon()` placeholder on the Home BCI tile so the screen becomes reachable.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Module wiring & routing

- [x] **Task 1: Add `buildDataScreen` factory to `BciModule`**
  Files: `lib/BciModule/BciModule.dart`
  Add a new `static Widget buildDataScreen(BuildContext context)` method following the existing `buildPairing` pattern. Instantiate `BciDataService(bciNotifier: App.shared.bciNotifier)` and `BciDataCoordinator(context)`, then return a `ProviderScope` that overrides `bciDataViewModelProvider` with `BciDataViewModel(service: service, coordinator: coordinator)` and renders `const BciDataScreen()`. Ensure the necessary imports are present (`BciDataService`, `BciDataCoordinator`, `BciDataScreen`, `BciDataViewModel`, `bciDataViewModelProvider` from `package:bci_module/bci_module.dart`).

- [x] **Task 2: Register `BciDataScreen` route**
  Files: `lib/router.dart`
  Add a new `GoRoute(path: BciDataScreen.path, builder: (context, state) => BciModule.buildDataScreen(context))` alongside the existing `BciPairingScreen` route. Add any missing imports (`BciDataScreen` from `package:bci_module/bci_module.dart` is already exported, so the existing `bci_module` import should cover it; verify).

### Phase 2: Home tile navigation

- [x] **Task 3: Route Home BCI tile to BCI data screen** (depends on Tasks 1 and 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
  In `openComingSoon()` (which today opens `BciPairingScreen.path` for the BCI tile), replace `context.push(BciPairingScreen.path)` with `context.push(BciDataScreen.path)`. Update the import to use `BciDataScreen` instead of `BciPairingScreen` if the latter is no longer referenced in this file. Keep the method name unchanged — only its body changes — to avoid touching the interface or call sites.

<!-- orchestrator-sessions
planner: 67256408-d44e-4412-9ad3-baba874b3936
implementer: 935f61d9-27c9-4747-89d7-6f6f4cba8bdb
-->
