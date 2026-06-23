# Code Review (round 2): Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

**Plan:** `.ai-factory/plans/81-recreate-the-sdk-devicelocator-on-every-disconnect-neirybciprovider.md`
**Changed file:** `lib/Bci/NeiryBciProvider.dart` (only code file changed)
**Risk Level:** 🟢 Low

## Status of round-1 findings

- **L1 (reset skipped if a subscription `cancel()` throws) — RESOLVED.** The teardown
  microtask now wraps Steps 1–4 in `try { … } finally { await _resetLocatorSession(); }`
  (L485–534), so the locator reset runs on every exit path, including a throwing cancel.
  This is the correct fix and introduces no new unhandled-rejection risk: pre-change the
  body ran via `unawaited(Future.microtask(...))`, so a throwing cancel already routed to
  the zone's uncaught handler; post-change, scan()/connect() await `_teardownComplete`
  inside try/catch when a reconnect follows, which is equal-or-better.

The H1 fix (gate awaited in `scan()`/`connect()`) and the `_doDispose` ↔ microtask
double-`_disposed` guard remain correct.

## Findings

### L2 (Low) — Two *recreating* `_resetLocatorSession()` calls can race and leak a DeviceLocator

`_resetLocatorSession()` (L431–441) is read-dispose-create and is **not atomic** across
concurrent invocations:

```dart
if (_disposed) return;
try { await _locator.dispose(); } catch (_) {}   // <-- await: another reset can interleave here
if (_disposed) return;
_locator = neiry.DeviceLocator();
```

Every public reset path except `disconnect()` first drains the teardown gate
(`scan()` L106, `connect()` L151 both `await _teardownComplete`), so a pending
unexpected-drop microtask's reset has already completed before they touch the locator.
**`disconnect()` (L588) does not await the gate** — it calls `_resetLocatorSession()`
directly at L615.

Reachable interleaving: an unexpected drop schedules the teardown microtask
(`_teardownComplete`, L485) whose `finally` calls `_resetLocatorSession()`; before that
microtask finishes its ~16 awaits, the user disconnects, so
`BciDeviceManager.disconnect()` (BciDeviceManager L248–255) → `_provider.disconnect()` →
`_resetLocatorSession()` (L615) runs **concurrently** with the microtask's reset. Trace
with `_locator == A`:

1. R1 (disconnect): `await A.dispose()` → suspends.
2. R2 (microtask finally): `await A.dispose()` → double-dispose `StateError`, swallowed; continues.
3. R2: `_locator = B`.
4. R1 resumes: `_locator = C`.

`B` is assigned then overwritten without ever being disposed → a leaked `DeviceLocator`
(and its native `clCDeviceLocator` session). No crash or hang; just a native-resource
leak in a narrow window (near-simultaneous unexpected drop + manual disconnect).

Note the `_disposed` double-check does **not** cover this case — it guards the *terminal*
(`_doDispose`) path, which disposes without recreating. The race here is between two
paths that both recreate, neither of which sets `_disposed`.

**Suggested fix** (consistent with the existing gate pattern, minimal): drain the gate at
the top of `disconnect()` too, so its reset is serialized behind any in-flight teardown
reset:

```dart
Future<void> disconnect() async {
  try { await _teardownComplete; } catch (_) {}
  // ...existing body...
}
```

After this, `connect()`, `scan()`, and `disconnect()` all serialize behind a pending
teardown reset, and `_resetLocatorSession()` is never entered re-entrantly. Optional and
non-blocking given the low likelihood and leak-only (non-fatal) impact.

## Informational (no action required)

- **Reconnect latency coupled to full teardown** (unchanged from round 1) — `scan()`/
  `connect()` await the whole teardown microtask before reading the fresh locator. This
  is the intended H1 serialization.
- **M1 (first scan on a freshly-recreated locator)** — still the on-device verification
  item in the plan; `requestDevices()` does not await the new locator's native-ready.

## Verdict

The round-1 finding is properly resolved. One new Low finding (L2) — a narrow,
leak-only concurrent-reset race on the `disconnect()` path — is non-blocking and has a
one-line gate-await fix consistent with the rest of the design. No blocking issues.
