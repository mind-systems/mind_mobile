# Code Review: 42 — Implement `BciPairingViewModel`

**Plan:** `.ai-factory/plans/42-implement-bcipairingviewmodel.md`
**Files reviewed:**
- `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart` (new, 54 lines)
- `packages/bci_module/lib/bci_module.dart` (+1 export line)

**Verification:** `/usr/local/bin/flutter analyze packages/bci_module` → `No issues found! (ran in 3.1s)`.

## Scope check

The patch matches the plan exactly:

- Provider declared at top-level throwing `UnimplementedError` (matches `breathViewModelProvider`).
- `BciPairingViewModel extends Notifier<BciPairingState>` with `service` + `coordinator` required ctor params.
- `_eventsSubscription` instance field; `ref.onDispose` cancels it in `build()`.
- `initState()` guards against double-subscription, subscribes before calling `startScan()`.
- Sealed switch on `BciPairingServiceEvent` (exhaustive — adding a variant later is a compile error).
- Four gesture forwarders, each a one-liner.
- Barrel export added under the `// ViewModels` header.

No out-of-scope refactors, no dead code, no introduced files beyond what the plan called for.

## Correctness analysis

### Lifecycle / subscription
- **Subscription ordering** — `service.observeChanges().listen(...)` is registered *before* `service.startScan()` is called. The listener is in place before any event the service produces. Correct.
- **Notifier `state` setter from a sealed pattern variable** — `case BciPairingStateUpdated(:final state): this.state = state;` introduces a local `state` that shadows the inherited getter; the assignment uses the explicit `this.` qualifier to reach the Notifier setter. Compiles, and the analyzer agrees. Slightly opaque to read but correct.
- **`build()` re-execution** — There are no `ref.watch(...)` calls in `build()`, so it will not re-run for dependency changes. If it were ever invalidated, the Notifier instance is disposed (cancelling the subscription via `ref.onDispose`) and a fresh instance is created — the `_eventsSubscription` field on the old instance does not bleed into the new one. Safe.
- **`ref.onDispose` capture semantics** — The callback `() => _eventsSubscription?.cancel()` captures `this`, so it reads the current field value at dispose-time (not the value at `build()` time). Even if `initState()` runs after `build()` registers the disposer, the disposer will see the populated subscription. Correct.
- **Stream cancel timing** — `StreamSubscription.cancel()` stops further callbacks synchronously (the returned Future only awaits underlying cleanup), so there is no risk of a stray `this.state = ...` write landing on a disposed Notifier and throwing.

### Module boundary / `RULES.md`
- ViewModel owns the `StreamSubscription` and its lifecycle (`ref.onDispose`) — RULES Rule #1 honored. The service implementation in the next milestone can stay stateless as required.
- All dependencies are constructor-injected — RULES Rule #3 honored.
- Imports are local-relative only; no `lib/Bci/...` or `package:bci_module/...` leakage — module boundary preserved.

### Type safety
- `StreamSubscription<BciPairingServiceEvent>?` matches the declared return type of `IBciPairingService.observeChanges()` (`Stream<BciPairingServiceEvent>`). No casts, no dynamic.
- `bciPairingViewModelProvider`'s `NotifierProvider<BciPairingViewModel, BciPairingState>` second type argument matches the `Notifier<BciPairingState>` extension. Correct.

### Runtime risk surface
- No async work, no `await`, no I/O — nothing to race on inside the ViewModel.
- No `Timer`, no `addPostFrameCallback`, no `ChangeNotifier` — nothing else to leak.
- `_eventsSubscription` is the only resource and is cancelled deterministically.

## Findings

### Critical
*(none)*

### Suggestions (non-blocking)

1. **`initState()` is silently inert until called externally.** Reading `bciPairingViewModelProvider` without the next-milestone assembler calling `vm.initState()` yields a fully initialized but non-listening ViewModel — no subscription, no scan, no state transitions. This is the planned design (the assembler in milestone 99 will invoke it after `ProviderScope` setup), but it's a footgun if a screen ever reads the provider directly before the assembler runs. Two cheap mitigations to consider in the next milestone:
   - Add an `assert(_eventsSubscription != null)` after the first frame in the screen, or
   - Move the `service.observeChanges().listen(...)` call into `build()` (it would run exactly once because there are no `ref.watch` dependencies). The current shape was chosen to mirror `BreathViewModel.initState()`, which has the same shape — so this is consistent with project convention, just worth flagging.

2. **`_eventsSubscription` is not nulled after cancel.** After `ref.onDispose` fires, the cancelled subscription is still referenced by the field. Harmless in practice (the Notifier instance is disposed too, so it will be GC'd), but if anyone ever re-enables `initState()`-on-an-existing-instance the double-subscription guard would incorrectly skip. Trivial future hazard, not a current bug.

3. **No `onError` on the subscription.** If `service.observeChanges()` errors (e.g. the underlying `BciNotifier.stream` errors), the exception propagates as an uncaught async error. This matches the `BreathViewModel` pattern (also no `onError`), so it's consistent. The concrete `BciPairingService` in the next milestone is built on RxDart `scan` over `BciNotifier.stream` — if `BciNotifier` is well-behaved this shouldn't fire, but worth keeping in mind when reviewing milestone 97.

### Positive notes

- Plan deviations from the (slightly stale) roadmap text (`service.events` → `observeChanges()`, `StateNotifier` → `Notifier`) are documented in the plan's Assumptions section and faithfully implemented.
- Subscribe-then-start ordering avoids missing the first emission, even if the service implementation chooses to emit synchronously from `startScan()`.
- Exhaustive `switch` on a sealed type future-proofs the event handler.
- `build()` seeds state with `BciPairingState.initial()` so the UI always has a valid snapshot even before the first service event arrives — robust against RxDart `scan`'s "no seed on subscribe" behaviour noted in the plan-40 review.
- Barrel export placement matches the existing file's section ordering exactly.
- `flutter analyze` is clean.

## Verdict

The implementation is small, focused, correct, and faithful to the plan. The two reasonable concerns (silent-until-`initState`, no `onError`) are both inherited from the established `BreathViewModel` shape and are appropriately deferred to the wiring milestone.

REVIEW_PASS
