# Plan Review — Add `toggleHeartTickSource()` + `sourceChanges` subscription + `noCardioSource` UI event

**Plan reviewed:** `.ai-factory/plans/78-add-toggleheartticksource-sourcechanges-subscription-nocardiosource-ui-event-to-breathviewmodel.md`

## Summary

The plan accurately reflects the codebase state and is well-scoped for milestone 6 of the heart-rate-tick-source feature. All API names match the actual symbols, the architecture matches the M4 / M5 work that landed in `ITickService` and `SwitchableTickService`, and the single-write-point pattern (subscription as the only writer of `state.tickSource`) is correctly enforced.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Not directly impacted — change is confined to the existing ViewModel layer, no new modules, no boundary crossings introduced. WARN: none.
- **Rules (`.ai-factory/RULES.md`):** Three rules in the project — module Services must be stateless, no module-specific state in App.dart, dependencies via constructor. None are violated. The ViewModel is the correct place to own the subscription; `tickService` is constructor-injected via the existing field. No new App.dart touchpoints.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Plan corresponds directly to the M6 entry around line 173 of `ROADMAP.md` and matches its three-part decomposition (enum rename + callback rename, sourceChanges subscription, toggle method).

## Codebase Verification

Verified against the actual source:

- `BreathSessionViewModel.dart:12` — `enum BreathSessionError { starFailed }` exists exactly as the plan states.
- `BreathSessionViewModel.dart:32` — `void Function(BreathSessionError error)? onErrorEvent;` field exists.
- `BreathSessionViewModel.dart:286` — the only emit site for `BreathSessionError.starFailed` (inside `toggleStar`'s catch) is where the plan claims it is.
- `BreathSessionScreen.dart:99` — single screen callsite `viewModel.onErrorEvent = (_) { ... };` confirmed; uses `_` discard, so adding `noCardioSource` to the enum will not break the compile.
- `ITickService.dart` already exposes `Stream<TickSource> get sourceChanges` and `bool trySwitchTo(TickSource target)` on the interface — no cast to `SwitchableTickService` is needed, as the plan correctly states.
- `SwitchableTickService.dart` confirms: `trySwitchTo` returns `false` only when target is `heartbeat` and `!_heart.hasActiveSource`; switching to `timer` always succeeds; switching to the current source returns `true` without re-emitting on `sourceChanges`.
- `BreathSessionState` already has `final TickSource tickSource` with a `copyWith` setter — Task 3's `state.copyWith(tickSource: src)` will compile cleanly.
- Outside this module, `BreathSessionError` is referenced only in roadmap / notes / plan files — no production code imports it, so the rename is safely local.
- `BreathSessionListViewModel.onErrorEvent` (uses `SessionListError`) and `LoginViewModel.onErrorEvent` (uses `LoginError`) are correctly identified as unrelated and must remain untouched.
- No test files reference `BreathSessionError` or `BreathSessionViewModel.onErrorEvent` — `flutter analyze` should pass cleanly after the rename, as the plan claims.

## Notes / Minor Nits

1. **Task 3 — "transitive import" justification is technically wrong, conclusion is right.** The plan's wording "the file already imports `../ITickService.dart` which transitively references `TickSource`" implies symbols leak through imports — they don't (Dart only exposes symbols an imported file `export`s, not the ones it `import`s). `ITickService.dart` does `import 'CommonModels/TickSource.dart'`, not `export`, so `TickSource` is currently NOT in scope in `BreathSessionViewModel.dart`. The current file only ever references the value (`tickService.source`), never the type `TickSource` by name, which is why it compiles today. Task 5 introduces named references (`TickSource.heartbeat`, `TickSource.timer`), so the explicit `import '../CommonModels/TickSource.dart';` is required and the plan does ask for it — only the justification text is misleading. Implementer should ignore the "transitive" framing and just add the import.

2. **Task 2 — `noCardioSource` will route through the generic error snackbar if any code emits it before M7.** The current `onErrorEvent = (_) { ... show error snackbar ... }` handler does not destructure the variant; after rename it becomes `onUiEvent = (_) { ... show error snackbar ... }`. If `toggleHeartTickSource()` is invoked before M7 wires the proper `AppAlert`, both `starFailed` and `noCardioSource` will fire the generic error snackbar — wrong UX. The plan mitigates this by noting `toggleHeartTickSource()` is "unreachable from UI until M7," which is true (no toggle button is wired in this milestone). Acceptable for the milestone, but the implementer should resist the temptation to add ad-hoc invocation in testing without also short-circuiting the snackbar. The plan's suggestion to leave a `// noCardioSource handled in M7` comment in the handler is reasonable; just make sure that comment lands so the next milestone author finds it.

3. **Task 3 — subscription is created inside the `try` block in `initState()`.** If `service.getSession(sessionId)` throws, the subscription is never created and the catch branch sets `loadState: error`. That is acceptable behavior (no tick source toggling makes sense in error state, and `tickService.dispose()` in `ref.onDispose` still cleans up the service). No change needed — just flagging the failure-mode reasoning so it isn't surprising.

4. **Task 3 — subscription only fires on changes.** The initial `state.tickSource` is seeded by `_setupEngine` reading `tickService.source` directly (line 151). `SwitchableTickService` does not emit on `sourceChanges` for the initial source, only on switches. The initial sync is therefore correct because `_setupEngine` runs synchronously before the subscription would matter. Plan implicitly relies on this; worth stating explicitly but not blocking.

5. **Task 5 — double-tap is safe.** If the user toggles twice in quick succession before the subscription has fanned the source change back into `state.tickSource`, the second call's `target` would still be opposite of the (already-updated) `tickService.source`, so it would attempt to toggle again. `trySwitchTo` handles `target == _activeSource` by returning `true` without re-emitting. No bug; just noting that the manual-toggle UX is naturally idempotent under the chosen pattern.

## Critical Issues

None.

## Architectural Mistakes

None. The plan correctly:
- Places the `sourceChanges` subscription in `initState()` (one-shot, lifecycle of the VM) rather than inside `_setupEngine()` (called on each session update — would stack subscriptions).
- Avoids casting `tickService` to `SwitchableTickService` because the API is on the `ITickService` interface as of M4.
- Establishes the subscription as the single writer of `state.tickSource`, so manual toggle and auto-fallback share one code path (matches the spec in `.ai-factory/notes/29-heart-rate-tick-source.md`).
- Keeps `_sourceChangesSub` cancellation alongside other subscription cancellations in `ref.onDispose`, before `tickService.dispose()` — matches the existing ordering convention.

## Missing Steps / Migrations / Security

None. No DB schema, no proto, no migration, no security surface change.

PLAN_REVIEW_PASS
