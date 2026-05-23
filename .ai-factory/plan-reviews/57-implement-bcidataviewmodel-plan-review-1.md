# Plan Review: Implement `BciDataViewModel`

**Plan file:** `.ai-factory/plans/57-implement-bcidataviewmodel.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE / RULES gate:** PASS.
  - `.ai-factory/RULES.md` rule 1 (Module Services stateless; ViewModel manages subscription lifecycle via `ref.onDispose`) is honoured — the plan registers `ref.onDispose` and stores a `StreamSubscription<BciDataEvent>` inside the ViewModel.
  - Rule 3 (constructor injection) is honoured — both `service` and `coordinator` are required constructor parameters.
- **ROADMAP gate:** PASS. The plan is the natural continuation of phase work on `bci_module` (the `BciPairing` analogues are already complete; the post-review fix referenced in roadmap line 101 — null the subscription field inside `onDispose` — is replicated correctly).

## Codebase verification

All assumptions in the plan were checked against the current code:

- `packages/bci_module/lib/src/BciData/` exists and contains `IBciDataService.dart`, `IBciDataCoordinator.dart`, and `Models/BciDataState.dart`. The new `BciDataViewModel.dart` file does **not** yet exist — correct precondition.
- `IBciDataService` exposes `Stream<BciDataEvent> get events` (not `observeChanges()` like the pairing service), and `BciDataEvent` is a sealed hierarchy with a single `BciDataStateUpdated(BciDataState state)` member. The plan's switch (`case BciDataStateUpdated(:final state)`) is exhaustive and matches the actual API.
- `BciDataState.initial()` exists and returns `const BciDataState(channels: [], isConnected: false)` — safe to return from `build()`.
- `IBciDataCoordinator` declares `void openPairing()`; the plan acknowledges that no gesture method is wired in this task and explicitly keeps `coordinator` as an unused-for-now constructor field for the upcoming screen task. Reasonable.
- `packages/bci_module/lib/bci_module.dart` line 4 currently exports `src/BciPairing/BciPairingViewModel.dart` under the `// ViewModels` header — the plan's insertion point ("immediately after that line") is precise.
- The reference template `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart` matches the plan's blueprint (Notifier, constructor injection, `ref.onDispose` that nulls the field, switch on sealed event type).

## Findings

### Critical Issues
None.

### Minor Notes
- The plan deliberately diverges from `BciPairingViewModel` by subscribing inside `build()` rather than in a separately-invoked `initState()`. This is correct here because there is no deferred imperative trigger (no analogue of `service.startScan()`). Worth flagging only so the implementer doesn't reflexively copy the pairing pattern wholesale.
- The local `state` variable bound by the pattern `BciDataStateUpdated(:final state)` shadows `Notifier.state`. The plan correctly assigns through `this.state = state`. If the implementer adds further branches, they must remember the shadowing.
- `coordinator` will be an unused field at this commit. Lint rules `unused_field` target private fields only, so the public `final IBciDataCoordinator coordinator` will not trip Dart analyzer, but a reviewer reading the diff in isolation may question it. The plan already pre-empts this by stating the reason; no change needed.

### Positive Notes
- The `ref.onDispose` block is registered **before** the `listen` call, matching the post-review fix recorded at ROADMAP line 101 and ensuring re-subscription works on notifier rebuild.
- The plan is scoped tightly: only the ViewModel file and a single barrel-export line. No premature wiring of services/coordinators or screen code — those are correctly deferred.
- File paths, import paths, and the provider's `throw UnimplementedError` shape mirror the established pattern, so the override site (`lib/BciModule/BciModule.dart`) will plug in without surprise.

PLAN_REVIEW_PASS
