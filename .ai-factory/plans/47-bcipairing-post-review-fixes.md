# Plan: BciPairing post-review fixes

## Context
Apply two fixes flagged in the BciPairing code review: strip all `///` docstrings from the touched BciPairing package files (project no-docs style), and ensure `BciPairingViewModel` nulls its events subscription field on dispose so a future second `initState()` call cannot be silently no-op'd by the stale-non-null guard.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Fixes

- [x] **Task 1: Remove all `///` docstrings from `IBciPairingService.dart`**
  Files: `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`
  Delete every `///` comment in the file. This includes:
  - the class docstring above `abstract class IBciPairingService`
  - the method docstring above `observeChanges()`
  - the one-line docstrings above `startScan()`, `connectDevice()`, `startCalibration()`, and `disconnect()`

  Leave the rest of the file (interface signature, method declarations, imports) unchanged. The anchor "above `<member>`" is unambiguous — do not rely on line counts.

- [x] **Task 2: Remove the `///` docstring from `BciCalibrationProgressDTO.dart`**
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciCalibrationProgressDTO.dart`
  Delete the single `///` class docstring that sits above the class declaration (it is the only docstring in the file). Leave the rest of the file unchanged.

- [x] **Task 3: Null `_eventsSubscription` in `ref.onDispose` callback and remove the `initState()` docstring**
  Files: `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`

  Two edits in the same file:

  1. In `build()`, replace the single-expression form
     ```dart
     ref.onDispose(() => _eventsSubscription?.cancel());
     ```
     with the block form that also nulls the field:
     ```dart
     ref.onDispose(() {
       _eventsSubscription?.cancel();
       _eventsSubscription = null;
     });
     ```
     Rationale: if `initState()` is ever invoked a second time on the same instance (e.g. by a future test harness or assembler change), the existing `if (_eventsSubscription != null) return;` guard would otherwise treat the already-cancelled subscription as live and silently skip the resubscribe. Nulling on cancel keeps the guard honest. (Note: this is *not* about Riverpod "rebuilds" — a disposed `Notifier` is replaced with a fresh instance whose field is already null; the concern is repeated `initState()` on the same instance.)

  2. Delete the `///` docstring on the line directly above `void initState()` ("Called once by the module assembler after the provider scope is created."). Same no-docs rule as Tasks 1–2; since the file is already being edited, this keeps the rule applied uniformly.
