# Code Review (round 3): Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

**Plan:** `.ai-factory/plans/81-recreate-the-sdk-devicelocator-on-every-disconnect-neirybciprovider.md`
**Changed file:** `lib/Bci/NeiryBciProvider.dart` (only code file changed)
**Risk Level:** 🟢 Low

## Status of prior findings

- **L1 (round 1) — RESOLVED.** Teardown microtask wraps Steps 1–4 in
  `try { … } finally { await _resetLocatorSession(); }` (L485–536). The reset now runs on
  every exit path, including a throwing subscription `cancel()`.
- **L2 (round 2) — RESOLVED.** `disconnect()` now drains the gate as its first statement
  (`try { await _teardownComplete; } catch (_) {}`, L589). All three locator-touching
  public paths — `scan()` (L106), `connect()` (L151), `disconnect()` (L589) — now await
  the teardown gate before reading/recreating `_locator`, so the concurrent
  recreating-reset race that could orphan a `DeviceLocator` is closed.

## Verification of the resolved race

Traced the drop-then-disconnect sequence with the gate await in place:
1. Unexpected drop schedules microtask `F` (`_teardownComplete = F`).
2. User disconnect → `disconnect()` `await F` — waits for `F` including its `finally`
   reset (locator A disposed → B created).
3. `F` completes; `disconnect()` resumes, device fields already null (no-ops), then its
   own `_resetLocatorSession()` runs sequentially (B disposed → C created).

Sequential, no overlap, no orphaned instance. The `_doDispose()` ↔ microtask overlap
remains correctly handled by the synchronous `_disposed = true` (L630) plus the double
`_disposed` check in `_resetLocatorSession()` (L433/L439): once terminal dispose begins,
any in-flight microtask reset bails before recreating, so no locator is leaked on a dying
provider.

## Independent pass — no new findings

- **No deadlock / no permanent hang on the gate.** The microtask future always completes:
  every native step is wrapped, and the `finally` reset's `_locator.dispose()` is wrapped
  in `_resetLocatorSession()`. `scan()`/`connect()`/`disconnect()` therefore always
  resume.
- **Nullable-future await is valid.** `_teardownComplete` is `Future<void>?`; `await null`
  resolves immediately on the first scan/connect/disconnect before any drop.
- **`scan()` cancellation safe.** If the consumer cancels the scan subscription while
  suspended on the gate await, `requestDevices()` never starts — no native scan leak.
- **No unhandled-rejection regression.** Equivalent-or-better than the prior
  `unawaited(...)` form (analyzed in round 2).
- **No external `_locator` caching.** Only reads are `requestDevices` (L141) and
  `createDevice` (L158), both at call time on the field. ✅
- **Scope/boundary intact.** Changes confined to `NeiryBciProvider`, the only file
  permitted to import `neiry_kit`. No RULES.md violations.

## Informational (no action required)

- **Benign redundant reset** on the rare drop-then-disconnect sequence: `disconnect()`
  resets the locator a second time after the microtask already did (dispose B → create C).
  Purely an extra dispose/create cycle — sequential, no leak. Not worth special-casing.
- **M1 (first scan on a freshly-recreated locator)** remains the on-device verification
  item already in the plan; `requestDevices()` does not await the new locator's
  native-ready.

## Verdict

Both prior findings are correctly resolved and the independent pass surfaces no
correctness, concurrency, or security issues. The implementation faithfully realizes the
reviewed plan.

REVIEW_PASS
