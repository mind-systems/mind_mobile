# Plan: Wire `BciModule.dart` + `App.dart` + `router.dart` + HomeScreen

## Context
Final assembly step for the BCI pairing flow: introduce a `BciModule` assembler that mints the concrete service/coordinator and overrides `bciPairingViewModelProvider`, register the new route in GoRouter, and route the BCI tile on the Home screen to the pairing screen instead of the "Coming soon" placeholder.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Module assembly

- [x] **Task 1: Create `lib/BciModule/BciModule.dart`**
  Files: `lib/BciModule/BciModule.dart`
  Mirror the shape of `lib/BreathModule/BreathModule.dart`. Define a `BciModule` class with a single static method:
  ```dart
  static Widget buildPairing(BuildContext context) {
    final service = BciPairingService(bciNotifier: App.shared.bciNotifier);
    final coordinator = BciPairingCoordinator(context);
    return ProviderScope(
      overrides: [
        bciPairingViewModelProvider.overrideWith(
          () => BciPairingViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const BciPairingScreen(),
    );
  }
  ```
  Imports: `package:flutter/widgets.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `package:bci_module/bci_module.dart`, `package:mind/BciModule/BciPairingService.dart`, `package:mind/BciModule/BciPairingCoordinator.dart`, `package:mind/Core/App.dart`. Match the formatting conventions used in `BreathModule.dart`. Note: `bciPairingViewModelProvider` is a `NotifierProvider` (not `StateNotifierProvider`), so `.overrideWith(() => ...)` returning a fresh `BciPairingViewModel` is the correct override form — same as the existing `breathSessionListViewModelProvider` override. Do not call `initState()` here — `BciPairingScreen` already triggers it via `addPostFrameCallback`.

### Phase 2: Routing and navigation

- [x] **Task 2: Register `BciPairingScreen` route in `lib/router.dart`** (depends on Task 1)
  Files: `lib/router.dart`
  Add an import for `BciModule` (`package:mind/BciModule/BciModule.dart`) and add `BciPairingScreen` to the existing `package:bci_module/bci_module.dart` show clause. Insert a new `GoRoute` entry in the `routes:` list (place it next to the other module routes, e.g. after the breath constructor route):
  ```dart
  GoRoute(
    path: BciPairingScreen.path,
    name: BciPairingScreen.name,
    builder: (context, state) => BciModule.buildPairing(context),
  ),
  ```
  Keep the existing `ComingSoonScreen` route intact — only the BCI tile is being rerouted in Task 3; other coming-soon usages (if any are added later) should still work.

- [x] **Task 3: Route Home BCI tile to `BciPairingScreen`** (depends on Task 2)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
  In `HomeCoordinator.openComingSoon()`, replace the body `context.push(ComingSoonScreen.path)` with `context.push(BciPairingScreen.path)`. Add `import 'package:bci_module/bci_module.dart' show BciPairingScreen;` and remove the now-unused `ComingSoonScreen` reference if no other method in the file uses it (currently only `openComingSoon` does). Leave the `IHomeCoordinator.openComingSoon()` contract and `HomeViewModel.onComingSoonTap()` wiring untouched — `HomeScreen` still binds the BCI tile to `vm.onComingSoonTap`, so changing only the coordinator body is the minimal, milestone-conformant change. Do not rename the method.
