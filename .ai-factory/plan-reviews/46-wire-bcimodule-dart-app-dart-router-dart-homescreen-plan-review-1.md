# Plan Review: Wire `BciModule.dart` + `App.dart` + `router.dart` + HomeScreen

**Plan file:** `.ai-factory/plans/46-wire-bcimodule-dart-app-dart-router-dart-homescreen.md`
**Files reviewed:** 7 (plan, ROADMAP, BreathModule.dart, router.dart, HomeCoordinator.dart, BciPairingScreen.dart, BciPairingViewModel.dart, BciPairingService.dart, BciPairingCoordinator.dart, App.dart bciNotifier usage)
**Risk Level:** 🟢 Low

### Context Gates
- **ARCHITECTURE.md**: not consulted in detail, but the plan adheres to the established module-assembly pattern (Service/Coordinator concrete in `lib/`, package-side `ViewModel` provider override) used by `BreathModule.dart`. No boundary issues.
- **RULES.md**: not consulted line-by-line; plan follows English-only and pattern conventions.
- **ROADMAP.md**: this plan corresponds to milestone line 99 — "Wire `BciModule.dart` + `App.dart` + `router.dart` + HomeScreen" (status `[ ]`). Linked correctly. ✅

### Critical Issues
None.

### Inaccuracies / Minor Issues

1. **Task 2 — non-existent "existing show clause" for `bci_module`.**
   The plan instructs: *"add `BciPairingScreen` to the existing `package:bci_module/bci_module.dart` show clause"*. There is no existing `package:bci_module/bci_module.dart` import in `lib/router.dart` — the only existing module show-clause is `package:breath_module/breath_module.dart` (line 3). The implementer must **add a brand-new import line**, e.g.:
   ```dart
   import 'package:bci_module/bci_module.dart' show BciPairingScreen;
   ```
   alongside the `import 'package:mind/BciModule/BciModule.dart';` line. The wording in Task 2 should be corrected to "add a new import for `bci_module` with `show BciPairingScreen`" to avoid confusion at implementation time.

2. **Task 3 — leaves a now-unused `mind_ui` import.**
   `HomeCoordinator.dart` imports `package:mind_ui/mind_ui.dart` (line 9), and within this file that barrel is currently used **only** for `ComingSoonScreen` (no other `mind_ui` symbols appear in the file). Once `ComingSoonScreen` is replaced with `BciPairingScreen`, the `mind_ui` import becomes dead. The plan says "remove the now-unused `ComingSoonScreen` reference" but does not explicitly call out removing the now-unused `mind_ui` import. Recommend adding to Task 3:
   > Also remove `import 'package:mind_ui/mind_ui.dart';` — after the swap nothing else in this file references `mind_ui`.

3. **Naming smell, acknowledged but unresolved.** The plan correctly notes that `IHomeCoordinator.openComingSoon()` keeps its name even though it no longer opens a "coming soon" screen. The plan justifies this as a minimal change, which is fine for this milestone — but a follow-up cleanup task (rename to e.g. `openBci()` and update interface + view-model wiring) should probably be queued. Not blocking.

### Correctness Spot Checks (plan vs. codebase)

- `App.shared.bciNotifier` exists (`lib/Core/App.dart:84,107,153,195`). ✅
- `bciPairingViewModelProvider` is `NotifierProvider<BciPairingViewModel, BciPairingState>` (`packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart:7-12`); the recommended `.overrideWith(() => BciPairingViewModel(...))` form is the right one — matches `breathSessionConstructorProvider.overrideWith(() => ...)` in `BreathModule.dart`. ✅
- `BciPairingScreen.path` / `BciPairingScreen.name` exist as static const (`packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart:15-16`). Route registration as planned will work. ✅
- `BciPairingScreen` triggers `initState()` itself via `addPostFrameCallback` (lines 24-30); the plan correctly says **not** to call `initState()` from the module assembler. ✅
- `BciPairingService` constructor signature matches plan (`BciPairingService({required this.bciNotifier})`). ✅
- `BciPairingCoordinator(this.context)` matches plan. ✅
- `ComingSoonScreen` route in `router.dart:74-77` will remain valid even if no code currently links to it — fine per Task 2 directive. ✅

### Architectural Soundness
- The plan mirrors `BreathModule.buildSessionList` exactly — single `static Widget buildPairing(BuildContext context)`, override of view-model provider, no domain leakage past the assembler. Aligns with the module-system rule that "modules are wired at the app layer" (per `CLAUDE.md` / `docs/core/module-system.md`).
- No DI changes needed in `App.dart` itself — `bciNotifier` already exists. Despite the plan title mentioning `App.dart`, no task actually edits `App.dart`, which is correct.
- No migrations, no proto changes — none expected for a wiring step.

### Security / Performance
- No new IO, no auth flow change, no data persistence. Nothing to flag.

### Positive Notes
- Plan correctly identifies the `NotifierProvider` vs `StateNotifierProvider` distinction and cites the matching existing pattern.
- Plan correctly avoids touching the `IHomeCoordinator` contract, scoping the change to a single line in the implementation.
- Plan correctly notes the lifecycle reason **not** to call `initState()` from the assembler.
- Task ordering (module → route → home tile) is correct and the dependencies are explicitly stated.

### Recommendation
The plan is solid. The two minor issues above (router.dart wording around a non-existent import, and the unused `mind_ui` import in `HomeCoordinator.dart`) are cosmetic and easy to spot during implementation, but tightening the wording will avoid wasted cycles. No architectural rework needed.

PLAN_REVIEW_PASS
