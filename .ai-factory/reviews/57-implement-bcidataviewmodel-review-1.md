# Code Review: Implement `BciDataViewModel`

**Plan:** `.ai-factory/plans/57-implement-bcidataviewmodel.md`
**Scope reviewed:**
- `packages/bci_module/lib/src/BciData/BciDataViewModel.dart` (new)
- `packages/bci_module/lib/bci_module.dart` (export added)

## Verification

- `service.events` is the `Stream<BciDataEvent> get events` getter declared on `IBciDataService` — the listen signature matches.
- `BciDataEvent` is a `sealed` hierarchy with a single member `BciDataStateUpdated(BciDataState state)`. The `switch` in `_onServiceEvent` is exhaustive; the analyzer will not require a default arm.
- `BciDataState.initial()` returns `const BciDataState(channels: [], isConnected: false)` and is a valid seed for `build()`.
- `IBciDataCoordinator.openPairing()` is the sole method on the coordinator; the field is stored for upcoming gestures (per the plan, no gesture wiring in this task). Dart will not flag the public `final` field as unused.
- RULES.md rule 1 is honoured: the ViewModel owns the `StreamSubscription` and tears it down via `ref.onDispose`; the service stays stateless.
- RULES.md rule 3 (constructor injection) is honoured.
- The `ref.onDispose` callback is registered **before** `service.events.listen(...)` and nulls the field after cancel — matches the post-review fix recorded at ROADMAP line 101 and guarantees re-subscription works after a notifier rebuild.
- Barrel export is placed under the `// ViewModels` header, immediately after the existing pairing ViewModel export — symbols are reachable from `lib/BciModule/BciModule.dart` for the next task.
- File paths, import paths, provider name, `UnimplementedError` message, and class shape mirror `BciPairingViewModel` precisely, so the override site will plug in without surprises.

## Findings

None. The implementation faithfully follows the plan, matches the established `BciPairingViewModel` pattern (with the documented intentional divergence of subscribing in `build()` instead of a deferred `initState()`), and introduces no runtime, lifecycle, or typing concerns.

REVIEW_PASS
