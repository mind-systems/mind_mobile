# Code Review: Align `BciPairingViewModel` to subscribe in `build()`

**Branch:** `bci-integration`
**Files reviewed (code changes):**
- `packages/bci_module/lib/src/BciPairing/BciPairingViewModel.dart`
- `packages/bci_module/lib/src/BciPairing/BciPairingScreen.dart`

**Risk Level:** 🟢 Low

## Summary

The refactor is implemented correctly and faithfully to the plan. The subscription and `startScan()` were moved into `build()` ahead of `return BciPairingState.initial()`, mirroring the canonical `BciDataViewModel.build()` pattern; the public `initState()` method (and its redundant `_eventsSubscription != null` guard) were deleted; and the `_BciPairingScreenState.initState()` post-frame call site was removed. The `ref.onDispose` cancel-and-null block, `_onServiceEvent`, the gesture methods, the field, and the constructor are all left intact as specified.

## Correctness Verification

- **No synchronous self-mutation during build.** `service.observeChanges()` is built on `bciNotifier.stream` (a RxDart `BehaviorSubject` via `.scan(...).map(...)`). Stream events — including a BehaviorSubject's replayed latest value — are delivered asynchronously (microtask), so `_onServiceEvent`'s `this.state = state` runs *after* `build()` returns. No "modified a provider while building" error. This matches the mechanism `BciDataViewModel` already relies on in production.
- **`startScan()` during build is safe.** `BciPairingService.startScan()` is `unawaited(bciNotifier.startScan())` — fire-and-forget async; it does not synchronously mutate the provider. Behaviorally, the scan now kicks off when the provider is first read (during widget build) rather than in a post-frame callback. Since it is async and the emitted state updates land in a later microtask/frame, this is equivalent in effect and is the same timing `BciDataViewModel` uses.
- **Guard removal is sound.** `BciPairingViewModel.build()` has no `ref.watch` dependencies, so it runs once per provider lifetime; on any future invalidation, `ref.onDispose` cancels and nulls the prior subscription before the new `build()` re-subscribes. The old `if (_eventsSubscription != null) return;` guard is genuinely redundant now.
- **No orphaned call sites.** A repo-wide search confirms the removed `BciPairingViewModel.initState()` had exactly one caller (the now-deleted screen override). The other `initState()` occurrences (`BciDiscoverySection`, `BciCalibrationSection`, and various `lib/` screens) are unrelated Flutter `State.initState` overrides. The provider wiring in `lib/BciModule/BciModule.dart` (`BciPairingViewModel(service: service)`) is unaffected since the constructor was untouched.

## Findings

### 1. Stale comment references the deleted `initState()` method — Low

`lib/BciModule/BciPairingService.dart:16-19` still reads:

```dart
// BciPairingViewModel.initState() calls startScan() on mount to trigger fresh
// emissions; do not assume full history is available on subscribe.
```

`BciPairingViewModel.initState()` no longer exists as a direct result of this change, so the comment now points at deleted code and is factually wrong. The surrounding note (BehaviorSubject replays only the latest event) is still valid and worth keeping. Recommend updating the sentence to reference `build()` instead, e.g.:

```dart
// BciPairingViewModel.build() calls startScan() on subscribe to trigger fresh
// emissions; do not assume full history is available on subscribe.
```

This is an in-code comment that becomes incorrect as a direct consequence of the diff, so it belongs in this change rather than deferred to a docs pass (it was also flagged as a non-blocking recommendation in the plan review and not picked up). Not a runtime bug.

## Conclusion

The code changes are correct and carry no runtime, type, or lifecycle risk. The single finding is a stale comment in a file not included in the diff; fixing it is recommended but non-blocking.
