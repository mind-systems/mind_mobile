# Code Review: Wire `BciModule.dart` + `App.dart` + `router.dart` + HomeScreen

**Plan:** `.ai-factory/plans/46-wire-bcimodule-dart-app-dart-router-dart-homescreen.md`
**Branch:** `bci-integration`
**Files reviewed:** `lib/BciModule/BciModule.dart` (new), `lib/router.dart`, `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`, plus surrounding context: `lib/BciModule/BciPairingService.dart`, `lib/BciModule/BciPairingCoordinator.dart`, `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`, `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`, `packages/bci_module/lib/src/BciPairing/IBciPairingService.dart`, `lib/BreathModule/BreathModule.dart` (reference pattern), `lib/Core/App.dart` (DI), `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`, `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart`.

## Summary
Three-file wiring change for the BCI pairing flow:
1. New assembler `lib/BciModule/BciModule.dart` (mirrors `BreathModule.buildSessionList`).
2. `lib/router.dart` adds a `GoRoute` for `BciPairingScreen.path` → `BciModule.buildPairing`.
3. `HomeCoordinator.openComingSoon()` now pushes `BciPairingScreen.path` instead of `ComingSoonScreen.path`; the unused `mind_ui` import was correctly removed.

## Correctness Checks

### `lib/BciModule/BciModule.dart` — new file
- Constructor wiring matches concrete classes:
  - `BciPairingService({required this.bciNotifier})` ↔ `BciPairingService(bciNotifier: App.shared.bciNotifier)` ✅ (`lib/BciModule/BciPairingService.dart:14`).
  - `BciPairingCoordinator(this.context)` ↔ positional `context` ✅ (`lib/BciModule/BciPairingCoordinator.dart:8`).
  - `BciPairingViewModel({required this.service, required this.coordinator})` ✅ (`packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart:20-23`).
- `bciPairingViewModelProvider` is `NotifierProvider<BciPairingViewModel, BciPairingState>` — `.overrideWith(() => BciPairingViewModel(...))` is the correct override form (matches the pattern used in `BreathModule.dart:21-23` for `breathSessionListViewModelProvider`). ✅
- `App.shared.bciNotifier` exists (`lib/Core/App.dart:84, 107, 153, 195`). ✅
- `initState()` is **not** called from the assembler; that is correct — `BciPairingScreen` triggers it via `addPostFrameCallback` (`BciPairingScreen.dart:24-30`). Calling it here would either duplicate the subscription or race with the screen-side call (the VM guards with `if (_eventsSubscription != null) return;`, so it would not actually double-subscribe, but invoking it before `ref` is bound would still be wrong).
- Lifecycle: each navigation creates a fresh `BciPairingService` + `BciPairingCoordinator`. The service's stream subscription is owned by the VM and canceled in `ref.onDispose` (`BciPairingViewModel.dart:27`), so the previous instance is collectible on pop. No leak.
- Imports compile — `bci_module` barrel exports `BciPairingScreen`, `BciPairingViewModel`, `bciPairingViewModelProvider`, etc. ✅
- Class style and ordering match `BreathModule.dart` conventions. ✅

### `lib/router.dart`
- Adds `import 'package:bci_module/bci_module.dart' show BciPairingScreen;` (line 3) and `import 'package:mind/BciModule/BciModule.dart';` (line 5). ✅
- `BciPairingScreen.path = '/bci_pairing'` and `.name = 'bci_pairing'` (`BciPairingScreen.dart:15-16`) — no path collisions with the other routes. ✅
- The new `GoRoute` is placed after the breath constructor entry. Order in `routes:` is irrelevant for GoRouter matching by path, but stylistically it groups with other module routes — fine. ✅
- `ComingSoonScreen` route at lines 80-84 is preserved per the plan. Note: after this change, **no in-app caller pushes `ComingSoonScreen.path`** (grep confirms it is referenced only inside `router.dart` now). That is dead code, but the plan explicitly chose to keep it intact for possible future tiles — noted, not a defect.

### `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart`
- `openComingSoon()` body now `context.push(BciPairingScreen.path)`. ✅
- New import `package:bci_module/bci_module.dart' show BciPairingScreen;`. ✅
- Old `package:mind_ui/mind_ui.dart` import was the only source of `ComingSoonScreen` in this file; nothing else in this file uses `mind_ui`, so removing it is correct and does not break other methods (verified by reading the full file). ✅
- `IHomeCoordinator.openComingSoon()` contract and `HomeViewModel.onComingSoonTap()` wiring are unchanged, as required. ✅
- Runtime behaviour: `HomeScreen` binds the BCI tile (`l10n.homeTabMind`) to `vm.onComingSoonTap` (`HomeScreen.dart:29`), which calls `coordinator.openComingSoon()`, which now navigates to `/bci_pairing`. End-to-end path is connected. ✅

## Static Analysis / Build
- No proto changes, no Drift migrations, no DI changes in `App.dart`.
- All new symbols (`BciPairingScreen`, `BciPairingViewModel`, `bciPairingViewModelProvider`, `BciPairingState`) are re-exported by `packages/bci_module/lib/bci_module.dart`. ✅
- Compile-time risk: none observed.

## Runtime Risk Assessment
- **Stream lifecycle**: service is recreated per route entry; subscription cancel is wired through `ref.onDispose`. No leak across repeated open/close.
- **Context lifetime in coordinator**: `BciPairingCoordinator.close()` guards with `context.mounted` before `context.pop()` — safe even if the screen pops by other means before `close()` fires.
- **`BehaviorSubject` replay semantics**: the service uses `bciNotifier.stream.scan(...)`. RxDart's `scan` is per-subscription; each navigation gets its own reducer accumulator starting from `BciPairingState.initial()`. Combined with the screen-side `service.startScan()` triggered from `initState()`, fresh emissions will populate state. No stale-state bleed across navigations.
- **Re-entry**: if the user navigates back to the BCI tile, a fresh `ProviderScope` + fresh service/coordinator are created. The previous instance is GC-eligible. ✅

## Minor / Non-blocking Observations

1. **Orphaned `ComingSoonScreen` route.** After this change, nothing in the app pushes `ComingSoonScreen.path`. The route definition in `router.dart:80-84` is now dead. This was an explicit plan decision (keep the route in case other tiles later need it). No action required for this milestone, but worth queueing a cleanup if no other tile reuses it within the next milestone or two.

2. **Method name `openComingSoon` is now misleading.** The method navigates to BCI pairing, not a "coming soon" placeholder. The plan deliberately deferred the rename to keep the milestone scope minimal. A follow-up should rename `IHomeCoordinator.openComingSoon()` → `openBci()` (and `HomeViewModel.onComingSoonTap` → `onBciTap`) once the BCI tile is the only consumer. Not a runtime issue; purely naming hygiene.

3. **No null-safety / async pitfalls** in the new code. No `await`, no `Future`, no `Stream` ownership transferred across boundaries that aren't already handled.

## Verdict
The implementation matches the plan, uses the established `BreathModule` assembler pattern, and the runtime path (Home BCI tile → `openComingSoon()` → `/bci_pairing` → `BciModule.buildPairing` → overridden VM → `BciPairingScreen`) is fully connected. No bugs, security issues, or correctness problems found. Two non-blocking cleanup opportunities noted above.

REVIEW_PASS
