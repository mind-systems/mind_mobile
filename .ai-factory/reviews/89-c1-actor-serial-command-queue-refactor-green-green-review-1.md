# Code Review: C1 · Actor / serial command queue refactor (green→green)

**Reviewed:** `git diff HEAD` on branch `phase-55-serialize-bci-lifecycle`
**Changed code files:**
- `lib/Bci/SerialCommandQueue.dart` (new)
- `lib/Bci/NeiryBciProvider.dart` (modified)
- `test/Bci/neiry_bci_provider_command_queue_test.dart` (new)

## Verification performed

- Read all three changed files in full plus the unchanged consumer (`BciDeviceManager.dart`) and both characterization suites (B1 races, B2 full teardown).
- Ran `flutter test test/Bci/` → **All 61 tests passed** (B1 + B2 characterization suites green→green with no assertion edits, plus the 3 new queue tests).
- Ran `flutter analyze` on the three files → **No issues found**.

The refactor faithfully implements the three binding constraints: a single serial queue owns ordering; `scan`/`connect`/`disconnect`/drop-teardown all flow through it; the teardown command runs as one atomic unit with its internal `finally`-recreate preserved; `dispose` closes the queue (poison pill), drains the in-flight slot, and runs a terminal teardown that never recreates. `_teardownComplete` and the three drains are gone. Constraint 1 (one-directional) holds because `scan()` only holds the queue slot long enough to call `requestDevices()` and releases it before `yield*`, so a reconnect-driven `connect()` enqueued from the scan stream's `onData` never deadlocks against an in-flight command.

## Findings

### 1. (Low–Medium) Device drop during `dispose()` drain leaks the device/classifier/subscriptions and raises an unhandled `StateError`

`lib/Bci/NeiryBciProvider.dart:524-530` — `_doDispose()` now sets `_disposed = true`, calls `_queue.close()`, then `await _queue.idle`. The provider's `_connectionSub` (the listener on the device's `connectionStateStream` that invokes `_onConnectionStatus`) is **not** cancelled until the terminal-teardown phase that runs *after* `await _queue.idle`. So there is a window — between `dispose()` being called and the in-flight queue draining — in which a native `BciLinkStatus.down` can still reach `_onConnectionStatus` (`:257`) with `_device != null`.

When that happens, `_teardownAfterUnexpectedDrop()` (`:382`) runs: it captures `device`/`classifierSet`/all 10 subs into locals, **nulls the fields synchronously**, then `unawaited(_queue.enqueue(...))`. But the queue is closed, so `enqueue` returns immediately at `SerialCommandQueue.dart:46-52` with a `completeError(StateError)` **without running the teardown body**. Two consequences:

1. **Resource leak:** the captured device handle, classifier set, and 10 stream subscriptions are now orphaned — the teardown body never ran, and `_doDispose`'s subsequent terminal teardown sees `_device == null` / `_classifierSet == null` / all subs null, so it disposes/cancels none of them.
2. **Unhandled async error:** the `unawaited` errored future is unobserved → surfaces via the zone's uncaught-error handler.

This is a behavior regression: the old code (`_teardownComplete = Future.microtask(...)`, no "closed" concept) always ran the teardown microtask, which disposed the captured device and was a no-op only on the locator recreate (guarded by `_disposed`). It neither leaked nor errored on a post-dispose drop.

The characterization suites don't exercise a drop *after* dispose, so this is invisible to the green→green gate — but it's a real, if narrow, production race (e.g. the headband powers off at the same moment the app tears the provider down).

**Suggested fix** — bail out before capturing/nulling so the in-flight `_doDispose` still owns and cleans up the device:

```dart
void _teardownAfterUnexpectedDrop() {
  if (_disposed) return; // dispose's terminal teardown will clean up _device
  final device = _device;
  ...
}
```

Equivalently, guard the call site at `:264`/`:267` with `if (_device == null || _disposed) return;`. This is safe for the existing suites (none set `_disposed` before a drop). If `_doDispose` has already passed its terminal phase and nulled `_device`, the existing `_device == null` guard already covers it.

### 2. (Low) `dispose()` now blocks its own teardown on an in-flight command

`_doDispose()` `await _queue.idle` before running the terminal teardown. If an in-flight teardown/connect command stalls on a native call, the controllers are never closed and the device is never released. `dispose()` itself returns immediately (`unawaited(_doDispose())`), so callers aren't blocked — but the cleanup is now gated on the in-flight command, whereas the old code ran cleanup immediately and concurrently. This is the intended trade-off for non-interleaving serialization and is acceptable; flagging only so it's a conscious choice. No action required unless native calls are known to hang.

### 3. (Low / informational) `scan()` calls `requestDevices()` from inside the queued command regardless of later subscription cancellation

In `scan()` (`:156-159`) the `requestDevices()` call now executes inside the enqueued command. If the scan generator's subscription is cancelled while the command is still waiting behind an in-flight teardown, the command still runs and starts a native scan on the fresh locator whose stream is then discarded (the `yield*` never executes). In practice the subsequent `disconnect()`/locator recreate tears that locator down, so it is self-healing, and the old code had a similar shape. No change needed; noted for completeness.

### Non-issues confirmed

- The `enqueue` `onError` handler (`SerialCommandQueue.dart:71-77`) is an unreachable safety net — the success continuation catches all command errors and routes them to the completer, so `_tail` never rejects and the completer is never double-completed. Harmless.
- Fire-and-forget teardown of a *throwing-cancel* path correctly surfaces as an unhandled async error (B2 asserts this) and does not poison subsequent queue commands.
- `connect`/`disconnect` return their result futures to the caller, so a post-dispose `StateError` from a closed queue is observed by `BciDeviceManager` (routed to `onError`/awaited), not leaked — only the fire-and-forget teardown path (finding 1) is affected.
- `idle => _tail` is a correct completion barrier: after `close()`, no new `enqueue` extends `_tail` (closed enqueues return early without chaining), so `await _queue.idle` deterministically waits for exactly the already-chained work.

## Recommendation

Finding 1 is the only one I'd ask to address before merge — a one-line `_disposed` guard that prevents a resource leak and an unhandled error on a real (if uncommon) race, with zero risk to the green→green suites. Findings 2 and 3 are advisory.
