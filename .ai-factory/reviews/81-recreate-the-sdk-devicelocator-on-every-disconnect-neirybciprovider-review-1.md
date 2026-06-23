# Code Review: Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

**Plan:** `.ai-factory/plans/81-recreate-the-sdk-devicelocator-on-every-disconnect-neirybciprovider.md`
**Changed file:** `lib/Bci/NeiryBciProvider.dart` (only code file changed; the rest of the diff is plan/review docs)
**Risk Level:** 🟢 Low

## Summary

The implementation matches the reviewed plan faithfully and all four teardown paths are
covered exactly as specified:

- `_locator` made mutable; `_disposed` and `_teardownComplete` fields added (L35–38).
- `_resetLocatorSession()` helper with the dispose→recreate sequence and the two
  `_disposed` checks straddling the `await` (L432–441).
- Inline reset in the two synchronous paths — `connect()` failure cleanup (L188) and
  `disconnect()` (L613).
- Unexpected-drop path stores its microtask in `_teardownComplete` and appends the reset
  as the final step (L485, L533); `scan()` (L106) and `connect()` (L151) await the gate
  before touching `_locator`.
- Terminal `_doDispose()` sets `_disposed = true` first and disposes the locator without
  recreating (L628, L644).

The H1 race (reconnect scan vs. the fire-and-forget teardown microtask) is correctly
serialized by the gate, and the `_doDispose` ↔ teardown-microtask overlap is correctly
handled by the double `_disposed` check (verified by tracing the await interleavings — no
leaked or recreated-on-a-dead-provider locator in any ordering). No external code caches a
`_locator` reference; the only reads (`requestDevices` L141, `createDevice` L158) hit the
field at call time. The change compiles cleanly (awaiting a nullable `Future<void>?` is
valid; `await null` resolves immediately).

## Findings

### L1 (Low) — Locator reset is skipped if a subscription `cancel()` throws in the teardown microtask

In `_teardownAfterUnexpectedDrop()`'s microtask (L485–534), the Step 2 subscription
cancels are **not** wrapped in try/catch:

```dart
await connectionSub?.cancel();   // L492 — unguarded
await resistanceSub?.cancel();
...
await memsSub?.cancel();          // L501
...
await _resetLocatorSession();     // L533 — terminal step
```

Steps 1, 3, and 4 each swallow their errors, but if any of the ten `.cancel()` awaits
throws, the microtask future rejects and **`_resetLocatorSession()` at L533 is never
reached**. Consequences:

- The locator is not recreated, so the *next* unexpected-drop reconnect runs against the
  stale per-serial device again — silently reintroducing the exact staleness this task
  exists to fix, for that cycle.
- `_teardownComplete` completes with an error; `scan()`/`connect()` swallow it (their
  `try { await _teardownComplete; } catch (_) {}`) and proceed on the **old** locator.

This does not cause the H1 hang (the future does complete, via rejection), so it is
strictly lower severity, and `StreamSubscription.cancel()` throwing is uncommon. The same
unguarded-cancel pattern already exists in `_cancelDeviceSubscriptions()`, so this is
consistent with the codebase rather than a new anti-pattern — but making the reset the
*terminal* step of a sequence with unguarded awaits is what newly couples the fix's
success to those cancels not throwing.

**Suggested fix** — guarantee the reset runs regardless:

```dart
_teardownComplete = Future.microtask(() async {
  try {
    // ...existing Steps 1–4...
  } finally {
    await _resetLocatorSession();
  }
});
```

`finally` runs the reset on both the success and throw paths while still letting the
original error surface (harmlessly, since the awaiters swallow it). Optional and
non-blocking.

## Informational (no action required)

- **Reconnect latency now coupled to full teardown.** `scan()`/`connect()` await the
  entire teardown microtask (stopStream → 10 cancels → 4 classifier disposes →
  device disconnect/dispose) before reading the fresh locator. This is the intended H1
  serialization and is correct; just note that any slow native call in that chain delays
  the reconnect scan by that much. On an unexpected drop the device handle is already
  gone, so these calls are expected to return quickly.
- **M1 (first scan on a freshly-recreated locator)** remains the on-device verification
  item already captured in the plan's Verification section — `requestDevices()` does not
  await the new locator's native-ready, so confirm the first reconnect scan discovers the
  device rather than coming up empty. Out of scope for this single-file change.

## Verdict

No blocking issues. The single Low finding (L1) is a robustness hardening, not a runtime
defect on the happy path. The H1 fix is correct and the concurrency reasoning holds.
