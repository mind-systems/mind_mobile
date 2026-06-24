# scan() leaks QueueClosedException to the consumer → spurious BciIdle (T4)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 2 — low-severity hardening.

## Key Findings

- `scan()` (`lib/Bci/NeiryBciProvider.dart:118`) now does `final devicesStream = await _queue.enqueue(...)` (`:156`) then `yield* devicesStream` (`:159`). After `dispose()` closes the queue, that enqueue completes with `QueueClosedException`, which propagates out of the `async*` generator to the scan stream's listener.
- The Phase-55 refactor removed the old `try { await _teardownComplete; } catch (_) {}` swallow, so this rejection is now surfaced. `BciDeviceManager` listens to `_provider.scan()` in two places — `startScan` (`lib/Bci/BciDeviceManager.dart:179`, `onError` `:198` → `BciIdle` `:206`/`:211`) and `_attemptReconnect` (`:277`, `onError` `:293` → `BciIdle` `:304`/`:309`) — so a post-dispose scan error forces a spurious `BciIdle`.

## Details

- Wrap the enqueue await in `scan()` to **swallow `QueueClosedException`** and end the stream cleanly (e.g. `return` from the generator) instead of propagating — restoring the old post-dispose swallow semantics. Only `QueueClosedException` is swallowed; a genuine `requestDevices` error still surfaces.

## Guards

- Swallow **only** `QueueClosedException` — do not blanket-catch (real scan failures must still reach `BciDeviceManager`'s `onError`).
- Do not change `BciDeviceManager` (the fix belongs at the provider seam).
- No queue/CONSTRAINT changes.

## Verify

- Calling `dispose()` while a scan is pending no longer drives `BciDeviceManager` to a spurious `BciIdle`; the scan stream just ends.
- A real `requestDevices` error still reaches `onError`. Suites green.

**Done-when:** post-dispose scan ends silently (no `QueueClosedException` to the consumer); genuine scan errors still propagate; covered by a test.
