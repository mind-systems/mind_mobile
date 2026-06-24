# Code Review 2: C1 · Actor / serial command queue refactor (green→green)

**Reviewed:** `git diff HEAD` on branch `phase-55-serialize-bci-lifecycle`
**Changed code files:**
- `lib/Bci/SerialCommandQueue.dart` (new, 82 lines)
- `lib/Bci/NeiryBciProvider.dart` (modified)
- `test/Bci/neiry_bci_provider_command_queue_test.dart` (new)

## Verification performed

- Read all three changed files in full, plus the unchanged consumer `BciDeviceManager.dart` (scan/connect/disconnect/reconnect/connection-listener paths) and both characterization suites (B1 races, B2 full teardown).
- Ran `flutter test test/Bci/` → **All 61 tests pass** (B1 + B2 green→green, no assertion edits; 3 new queue/provider tests pass).
- Confirmed the three binding constraints hold: single serial queue owns ordering; the teardown command is atomic with its internal `finally`-recreate intact; `dispose()` closes the queue, drains the in-flight slot, and runs a terminal teardown without recreate.
- Confirmed `_teardownComplete` and the three `await _teardownComplete` drains are removed, and constraint 1 (one-directional) holds — `scan()` releases the queue slot before `yield*`, so a reconnect-driven `connect()` enqueued from the scan stream's `onData` never deadlocks against an in-flight command.

**Note:** review-1's primary finding (post-dispose drop leaking resources + raising an unhandled error) has been addressed — `_teardownAfterUnexpectedDrop()` now early-returns on `if (_disposed) return;` at `NeiryBciProvider.dart:383`. That correctly covers the case where a drop arrives *after* `dispose()` has set `_disposed = true`.

## Findings

### 1. (Low) A teardown command enqueued *behind* an in-flight command, then dropped by a racing `dispose()`, leaks the captured device and raises an unhandled `StateError`

The `_disposed` guard at `:383` closes the *drop-after-dispose* window, but there is a second, narrower window it does not cover: a teardown that was **enqueued before `dispose()`** (when `_disposed` was still false) but **dropped because `dispose()` closed the queue before that teardown's slot became active**.

Concrete path:
1. `disconnect()` is running as a queue command. Inside its body it `await`s `_device!.stopStream()` (`NeiryBciProvider.dart:487-492`); at this point `_connectionSub` is still live (it is only cancelled later, at `_cancelDeviceSubscriptions()` `:496`) and `_device != null`.
2. A native `BciLinkStatus.down` arrives during that `stopStream` await. `_onConnectionStatus` (`:264`) sees `_device != null`, runs `_teardownAfterUnexpectedDrop()` — which synchronously captures `device`/`classifierSet`/all 10 subs into locals, **nulls the fields**, and `unawaited(_queue.enqueue(teardown-B))`. Teardown-B is now queued **behind** the still-running `disconnect` command. (`_disposed` is false, so the `:383` guard does not fire.)
3. `dispose()` is called before the `disconnect` command finishes → `_doDispose` sets `_disposed = true`, `_queue.close()`, `await _queue.idle`.
4. The `disconnect` command finishes; teardown-B's slot then runs, finds `_closed == true`, and is **dropped** at `SerialCommandQueue.dart:58-62`: `completer.completeError(StateError(...))`. Because teardown-B was enqueued with `unawaited(...)`, that errored future has no listener → **unhandled async error** delivered to the zone / `PlatformDispatcher.onError`.
5. Worse than noise: teardown-B's body never ran, so the **captured device handle, classifier set, and 10 subscriptions are never disposed/cancelled**. And `_doDispose`'s terminal teardown can't clean them either — `_teardownAfterUnexpectedDrop()` already nulled `_device`/`_classifierSet`/subs in step 2, so `_doDispose` sees `_device == null` and skips device disconnect/dispose.

This requires a precisely-timed native drop during an in-flight `disconnect()` (or the `connect()` failure window) plus a racing `dispose()`, so it is uncommon — hence **Low** — but it is a real leak + unhandled error, and it is distinct from the window the `:383` guard fixes.

**Suggested fix.** Distinguish "command dropped because the queue closed" from "command body threw". Today both surface as a bare `StateError`, so the fire-and-forget teardown can't selectively swallow the drop without also swallowing the genuine throwing-cancel error that B2 relies on. Options:
- Have `SerialCommandQueue` complete dropped commands with a dedicated sentinel type (e.g. `QueueClosedException`) instead of `StateError`, then attach `.catchError(...)` on the fire-and-forget enqueue at `:412` that swallows only that type. The terminal `_doDispose` is the correct owner of cleanup in that case — but see the caveat below about the nulled fields.
- Caveat: even with the error swallowed, the captured-resource leak remains unless `_doDispose` can still reach them. The cleanest structural fix is for `_teardownAfterUnexpectedDrop()` to **not null the fields until the teardown command actually begins executing** (move the capture+null inside the enqueued command), so a dropped teardown leaves `_device`/subs intact for `_doDispose` to finalize. That change would need re-validating against the double-drop idempotency test (B1 "double unexpected-drop"), which depends on `_device` being nulled synchronously — so it is not a free swap and should be done carefully if pursued.

Given the rarity, an acceptable lighter-touch resolution is to swallow the drop `StateError` on the fire-and-forget path and accept the narrow leak, documented as a known edge.

### 2. (Low, advisory — carried from review-1) `_doDispose` gates terminal cleanup on the in-flight command

`_doDispose` `await _queue.idle` (`:531`) before closing controllers / releasing the locator. If an in-flight command stalls on a native call (`createDevice`, `disconnect`, etc.), the controllers are never closed and the locator never released. `dispose()` returns immediately (`unawaited(_doDispose())`) so callers aren't blocked, and this is the intended trade-off for non-interleaving serialization. No action required; flagged so it's a conscious choice.

### 3. (Low, advisory — carried from review-1) `scan()` runs `requestDevices()` inside the queued command even if the subscription is cancelled during the teardown-wait

In `scan()` (`:156-159`) `requestDevices()` executes inside the enqueued command. If the scan generator's subscription is cancelled while the command is still queued behind an in-flight teardown, the command still runs and starts a native scan whose returned stream is discarded (the `yield*` never executes). In practice a following `disconnect()`/locator recreate tears that locator down, so it is self-healing. No change needed; noted for completeness.

### Non-issues confirmed

- `SerialCommandQueue._tail` never rejects: the success continuation catches all command errors and routes them to the per-command completer, so the `onError` handler at `:71-77` is an unreachable safety net and the completer is never double-completed.
- `idle => _tail` is a correct completion barrier: after `close()`, no new `enqueue` chains onto `_tail` (closed enqueues return early without extending it), so `await _queue.idle` deterministically waits for exactly the already-chained work; and `_tail` never throwing means `await _queue.idle` cannot break `_doDispose`.
- The B2 throwing-cancel path still produces exactly one unhandled async error (the teardown body's `StateError` after `finally` reaches recreate) — the queue adds none.
- `connect()`/`disconnect()` return their result futures to `BciDeviceManager`, which observes them (awaited / routed to `onError`), so a queue-closed `StateError` on those paths is not leaked to the zone — only the fire-and-forget teardown path (finding 1) is.
- The new provider-level test leaves no open controllers: the gated teardown's `device.dispose()`/`classifierSet.dispose()` close their controllers before `_resetLocatorSession` early-returns on `_disposed`.

## Recommendation

Green→green is achieved and the refactor is sound. Finding 1 is the only substantive item — a narrow dispose-race that leaks captured resources and raises an unhandled error; it has a concrete (if non-trivial) fix and could reasonably be deferred with a documented known-edge given its rarity. Findings 2 and 3 are advisory.
