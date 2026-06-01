# Code Review (Round 2): Align `BciPairingViewModel` to subscribe in `build()`

**Branch:** `bci-integration`
**Files reviewed (code changes):**
- `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
- `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`
- `lib/BciModule/BciPairingService.dart`

**Risk Level:** 🟢 Low — no findings

## Summary

The refactor is implemented correctly and the single finding from round 1 has been resolved.

- **`BciPairingViewModel.build()`** subscribes via `_eventsSubscription = service.observeChanges().listen(_onServiceEvent)` and calls `service.startScan()` before `return BciPairingState.initial()`, mirroring the canonical `BciDataViewModel.build()`. The `ref.onDispose` cancel-and-null block, `_onServiceEvent`, gesture methods, field, and constructor are intact. The public `initState()` and its redundant `_eventsSubscription != null` guard are gone.
- **`BciPairingScreen`** — the `_BciPairingScreenState.initState()` post-frame override is removed; the only remaining logic is `build()`. No remaining references to the deleted VM method.
- **`BciPairingService`** — the stale `NOTE` comment now reads `BciPairingViewModel.build() calls startScan() on subscribe…`, matching the new lifecycle. The substantive caveat (BehaviorSubject replays only the latest event) is preserved.

## Correctness Verification

- **No build-time self-mutation.** `observeChanges()` is a RxDart `BehaviorSubject`-backed stream; its replayed latest value is delivered asynchronously (microtask), so `_onServiceEvent`'s `this.state = state` runs after `build()` returns — no "modified provider during build" error.
- **`startScan()` is fire-and-forget** (`unawaited(bciNotifier.startScan())`) — no synchronous provider mutation during build.
- **Guard removal is sound** — `build()` has no `ref.watch` dependencies, so it runs once per provider lifetime; on any future invalidation `ref.onDispose` cancels and nulls before re-subscribing.
- **No orphaned call sites** — the removed `BciPairingViewModel.initState()` had exactly one caller (the deleted screen override). Other `initState()` occurrences in the package (`BciDiscoverySection`, `BciCalibrationSection`) are unrelated Flutter `State.initState` overrides. Provider wiring in `lib/BciModule/BciModule.dart` is unaffected (constructor unchanged).

## Conclusion

The round-1 finding (stale comment) is fixed and no new issues are present. The change is correct with no runtime, type, or lifecycle risk.

REVIEW_PASS
