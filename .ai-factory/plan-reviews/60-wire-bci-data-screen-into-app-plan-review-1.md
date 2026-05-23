# Plan Review: Wire BCI data screen into app

## Code Review Summary

**Files Reviewed:** 1 plan, 6 source files
**Risk Level:** 🟢 Low

### Context Gates
- ARCHITECTURE.md / RULES.md / ROADMAP.md gates: WARN — no explicit references to those files were needed for this wiring task; the plan aligns with the established module pattern (`BciModule.buildPairing` → `BciModule.buildDataScreen`), which mirrors the wiring documented in `docs/core/module-system.md`.
- Module boundary: ✓ Service interface and ViewModel live in `packages/bci_module/`, concrete `BciDataService` + `BciDataCoordinator` live in `lib/BciModule/`. Plan adheres to the conventions in `CLAUDE.md`.

### Critical Issues
None. The plan is a small, well-scoped wiring change that completes the existing pieces (`BciDataService`, `BciDataCoordinator`, `BciDataViewModel`, `BciDataScreen` are already implemented and the public exports are present in `package:bci_module/bci_module.dart`).

### Minor / Verification Notes

1. **Task 2 — import comment is incorrect.**
   The plan says: *"`BciDataScreen` from `package:bci_module/bci_module.dart` is already exported, so the existing `bci_module` import should cover it; verify."*
   The current `lib/router.dart:3` uses a `show` clause:
   ```dart
   import 'package:bci_module/bci_module.dart' show BciPairingScreen;
   ```
   So the existing import does **not** cover `BciDataScreen`. The plan does include "Add any missing imports", so the implementer will correct it, but the assertion is wrong. Suggest changing the import to:
   ```dart
   import 'package:bci_module/bci_module.dart' show BciPairingScreen, BciDataScreen;
   ```

2. **Task 3 — same `show`-clause issue in `HomeCoordinator.dart`.**
   `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart:3` is:
   ```dart
   import 'package:bci_module/bci_module.dart' show BciPairingScreen;
   ```
   After the change, `BciPairingScreen` is no longer referenced in this file — the import should be replaced (not augmented) with `show BciDataScreen`. The plan correctly anticipates this ("Update the import to use `BciDataScreen` instead of `BciPairingScreen` if the latter is no longer referenced").

3. **Stale method name `openComingSoon()`.**
   Plan explicitly chooses to keep the method name to avoid touching the interface/call sites (`IHomeCoordinator.openComingSoon`, `HomeViewModel.onComingSoonTap`, `HomeScreen.onTap: vm.onComingSoonTap`). The name no longer matches behavior — the BCI tile now opens `BciDataScreen`, not a coming-soon placeholder. Acceptable trade-off for scope, but worth flagging for a follow-up rename (the rename is mechanical and touches 4 files).

4. **Lingering `/coming-soon` route.**
   `lib/router.dart:80–84` still registers `ComingSoonScreen`. After this milestone there are no callers pushing to it. Plan does not address this — fine to leave for a later cleanup if other tiles might use it again, but worth noting.

5. **`BciDataCoordinator` does not call `context.read(...)` or touch providers** — it only does `context.push(BciPairingScreen.path)` with a `context.mounted` guard, matching the existing `BciPairingCoordinator` pattern. Plan's instantiation `BciDataCoordinator(context)` is correct.

6. **`App.shared.bciNotifier` exists** (`lib/Core/App.dart:84,107,153,195`), so the `BciDataService(bciNotifier: App.shared.bciNotifier)` instantiation in Task 1 will resolve.

7. **`BciDataViewModel` provider override.**
   `bciDataViewModelProvider` is a `NotifierProvider<BciDataViewModel, BciDataState>` that throws `UnimplementedError` unless overridden — Task 1's `.overrideWith(() => BciDataViewModel(service: service, coordinator: coordinator))` is the correct API call (matches `BciPairingViewModel` pattern).

### Positive Notes
- Plan correctly identifies the three insertion points and nothing more — no scope creep.
- Task ordering is correct (Task 3 depends on Tasks 1 and 2 via `BciDataScreen.path` availability; already noted in the plan).
- The plan respects the manual DI singleton style (`App.shared.bciNotifier`) and the `ProviderScope`-wrapped module pattern documented in `docs/core/module-system.md`.
- Settings (no tests, minimal logging, no docs) are appropriate for a pure wiring change.

PLAN_REVIEW_PASS
