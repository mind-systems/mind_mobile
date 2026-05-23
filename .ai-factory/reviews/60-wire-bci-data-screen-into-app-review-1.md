# Code Review: Wire BCI data screen into app

## Scope of changes

- `lib/BciModule/BciModule.dart` — added `static Widget buildDataScreen(BuildContext context)`.
- `lib/router.dart` — added `GoRoute` for `BciDataScreen.path`, extended the `show` clause.
- `lib/HomeModule/Presentation/HomeScreen/HomeCoordinator.dart` — swapped `BciPairingScreen.path` for `BciDataScreen.path` in `openComingSoon()` and updated the `show` clause accordingly.

All three diffs match the plan exactly. Imports are clean (no leftover unused symbols). The DI shape (`BciDataService(bciNotifier: App.shared.bciNotifier)`, `BciDataCoordinator(context)`, `ProviderScope.overrideWith(() => BciDataViewModel(...))`) matches the existing `buildPairing` pattern in the same file and resolves against the real APIs (`App.shared.bciNotifier` exists, `bciDataViewModelProvider` is a `NotifierProvider`, etc.). The GoRoute uses the same `name`/`path`/`builder` triple as every other route in the file.

## Correctness / runtime concerns

None blocking. A few small things worth noting:

1. **Stale method name `openComingSoon()`.** After this change, the Home BCI tile no longer opens a coming-soon placeholder — it opens the live data screen. The plan deliberately keeps the name to avoid touching `IHomeCoordinator`, `HomeViewModel.onComingSoonTap`, and the `HomeScreen` call site. The method now lies about its behavior. The plan-review already flagged this as a follow-up; not introduced or worsened by this milestone, but it's now permanent until renamed.

2. **`/coming-soon` route still registered but unreachable from the app.** `lib/router.dart:85–89` still wires `ComingSoonScreen.path` → `ComingSoonScreen`. With this milestone, no in-app caller pushes that path; deep links could still hit it. Harmless, just dead-ish code.

3. **No back-navigation surface on `BciDataScreen`.** The screen is `Scaffold(body: SafeArea(Column[BciDataHeader, ...]))` — no `AppBar`, no leading close button. The header tap goes to the pairing flow (not back). Users rely on the system back gesture / button to pop. This is consistent with `BciPairingScreen` after milestone 52 (AppBar removed) and not in scope for this wiring task, but worth flagging if/when the screen gets a header redesign.

4. **`BciDataCoordinator` holds the route-builder `BuildContext`.** `BciModule.buildDataScreen(context)` passes the GoRoute builder's context into the coordinator, which keeps it as a field and uses it later in `openPairing()` with a `context.mounted` guard. Same pattern as `BciPairingCoordinator` — accepted across the codebase. No new risk introduced here.

5. **Re-subscription behavior on screen re-entry (pre-existing, not introduced by this task).** Each time the GoRoute rebuilds, `buildDataScreen` creates a fresh `BciDataService` whose `events` getter starts a fresh `.scan` from `BciDataState.initial()`. `BciNotifier` is a `BehaviorSubject` that replays only the latest event, so after navigating back to the data screen, all fields except the most recently emitted one will be `null` until new events arrive. `BciDataScreen` and `BciDataHeader` already handle `null` fields gracefully (0.3-opacity placeholders, `--` text). Noted previously in code comments inside `BciDataService`; flagging here only so the reviewer doesn't read the empty bars as a regression from this wiring change.

## Verification checks performed

- `App.shared.bciNotifier` is declared and initialized in `lib/Core/App.dart` ✓
- `bciDataViewModelProvider`, `BciDataViewModel`, `BciDataScreen`, `IBciDataService`, `IBciDataCoordinator` are all exported from `package:bci_module/bci_module.dart` ✓
- `BciDataViewModel.build()` correctly subscribes/disposes via `ref.onDispose`, satisfying the override contract ✓
- `BciDataScreen.path` constant resolves to `'/bci_data'`; no path collisions with existing routes ✓
- `IHomeCoordinator.openComingSoon()` signature unchanged; `HomeViewModel`/`HomeScreen` call sites untouched ✓
- No `BciPairingScreen` references remain in `HomeCoordinator.dart` after the `show`-clause swap — the `show BciDataScreen` is now the only symbol used ✓

REVIEW_PASS
