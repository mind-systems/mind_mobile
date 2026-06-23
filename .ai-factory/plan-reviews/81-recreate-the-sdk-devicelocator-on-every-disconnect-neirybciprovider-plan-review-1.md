# Plan Review: Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

**Plan:** `.ai-factory/plans/81-recreate-the-sdk-devicelocator-on-every-disconnect-neirybciprovider.md`
**Spec note:** `.ai-factory/notes/145-bci-locator-recreate-on-disconnect.md`
**Target file:** `lib/Bci/NeiryBciProvider.dart`
**Risk Level:** 🟡 Medium

## Summary

The plan is technically accurate, the line references are correct, and the four teardown
paths are completely enumerated. The SDK assumptions verify against the real
`DeviceLocator` source. The dispose-vs-recreate concurrency design (the `_disposed`
double-check around the `await`) is genuinely well-reasoned and handles the overlap
between `_doDispose()` and an in-flight `_teardownAfterUnexpectedDrop()` microtask
correctly.

There is **one real correctness gap**: the locator reset inside
`_teardownAfterUnexpectedDrop()`'s fire-and-forget microtask races against
`BciDeviceManager._attemptReconnect()`'s concurrent `scan()` on the same `_locator`
field. This is the only unexpected-drop reconnect path — the verified on-device flow —
so it deserves attention before implementation.

## Context Gates

- **Architecture (WARN→OK):** `.ai-factory/ARCHITECTURE.md` present. The plan confines
  all changes to `NeiryBciProvider`, which is correctly identified as the *only* file
  permitted to import `neiry_kit` (file header L31–33). No boundary violation. ✅
- **Rules (OK):** `.ai-factory/RULES.md` rules concern Module Services / App.dart /
  constructor DI — none apply to this provider-internal change. No violation. ✅
- **Roadmap (OK):** Linked to Phase 52 / task 145 (ROADMAP.md L268). Prerequisite kit
  bump (task at L267, commit `836699b`) is marked `[x]` done. Linkage is explicit and
  correct. ✅

## SDK Assumptions — Verified

Checked against `../neiry_kit/lib/src/api/device_locator.dart`:

- ✅ **Process-wide singleton.** `DeviceLocator()` is a factory returning `_instance`
  (L59–62); `dispose()` sets `_instance = null` (L283/L291), so the next
  `DeviceLocator()` constructs a fresh native session. The plan's
  `await _locator.dispose(); _locator = neiry.DeviceLocator();` therefore does produce
  a genuinely new locator. Correct.
- ✅ **Double-dispose throws.** `dispose()` calls `_checkNotDisposed()` first (L270),
  which throws `StateError` (L92). The plan wraps every `_locator.dispose()` in
  try/catch. Correct.
- ✅ **`scan()` reads the field lazily.** `requestDevices` is invoked at L138 inside the
  async generator, after the permission awaits, so it picks up the current `_locator`
  field — no cached reference. The plan's "always read the field" note is satisfied by
  the existing code.

## Critical / High Issues

### H1 — Locator reset in `_teardownAfterUnexpectedDrop()` races the reconnect scan

This is the main concern. The unexpected-drop path is **not** synchronously ordered the
way `disconnect()` and the connect-failure path are.

Sequence on an unexpected drop:
1. Native emits `disconnected` → `_onNeiryConnectionState` (L246) runs.
2. `_teardownAfterUnexpectedDrop()` (L429) nulls fields synchronously and **schedules a
   fire-and-forget microtask** for the heavy disposal (L464). Per the plan, the locator
   reset is appended as the final step *inside that microtask*.
3. `_connectionStateController.add(BciLinkStatus.down)` (L257) emits.
4. `BciDeviceManager`'s listener (L65–74) receives `down` and calls
   `unawaited(_attemptReconnect())` (L72).
5. `_attemptReconnect()` (L257) calls `_provider.scan().listen(...)` →
   `scan()` reads `_locator` and calls `requestDevices(searchTime: 5)`.

Steps 2 (the disposal microtask) and 5 (the reconnect scan) run **concurrently** and
both touch the same `_locator` field. The teardown microtask reaches
`_resetLocatorSession()` only after ~16 awaits (stopStream + 10 subscription cancels +
4 classifier disposes + device disconnect/dispose), while `scan()` reaches
`requestDevices()` after only the 1–3 permission awaits. So the reconnect scan very
plausibly starts on the **old** locator first, after which the teardown microtask calls
`await _locator.dispose()` on that same instance.

`DeviceLocator.dispose()` cancels the active scan via `_cancelScan?.call()` (L274) —
which runs `teardown()` (L142), removing the binary message handler **without closing
the scan's `StreamController`**. The reconnect scan stream then never emits, never
completes, and never errors → `_attemptReconnect`'s listener gets no `onData`/`onDone`/
`onError`, leaving the manager stuck in `BciScanning` indefinitely. Auto-reconnect
silently hangs.

The race is non-deterministic (it depends on platform-channel timing), so it may pass
in casual testing and fail intermittently — exactly the kind of bug that survives to
production.

Note: `disconnect()` and the connect-failure path are **not** affected — both are fully
`await`ed in sequence (`BciDeviceManager.disconnect()` awaits `_provider.disconnect()`
at L252 before returning; the user/manager cannot re-scan until the reset has run). The
gap is specific to the fire-and-forget unexpected-drop path.

**Suggested mitigation** (keeps changes inside `NeiryBciProvider`, honoring the plan's
single-file scope): introduce an internal teardown-completion gate the provider owns and
`scan()`/`connect()` await before touching the locator. e.g. assign
`_teardownComplete = Future.microtask(() async { ...existing steps...; await _resetLocatorSession(); })`
in `_teardownAfterUnexpectedDrop()`, and at the top of `scan()` (before the locator is
read) do `await _teardownComplete;`. That serializes the reconnect scan behind the
locator reset so it always reads the fresh locator. The spec note's Open Question (line
45) raises *intra-microtask* ordering but does not cover this *cross-component* race —
the plan should resolve it explicitly.

## Medium Issues

### M1 — First reconnect scan may hit a not-yet-ready locator

Before this change, `_locator` was created once at construction, so `_nativeReady`
(device_locator.dart L77) had always completed long before any scan. After the change,
the unexpected-drop path recreates the locator and the reconnect immediately scans it.
`requestDevices()` does **not** await `_nativeReady` — it invokes the native `listen`
method directly (L202–210). If the native `create` for the fresh locator is still
in-flight, the first reconnect scan can fail or come up empty. The teardown gate
proposed in H1 mitigates the worst of the timing, but the plan should call out verifying
that the first scan on a freshly-recreated locator behaves (this is also a good probe to
add to the verification step in note 145).

## Minor / Confirmations

- ✅ **All four teardown paths covered.** The paths that null `_device` are exactly:
  connect-failure (L183), `_teardownAfterUnexpectedDrop` (L447), `disconnect` (L589),
  `_doDispose` (L617). The plan addresses all four; none missed.
- ✅ **Line references accurate.** Field L35, scan L138, connect-failure L162–185,
  teardown microtask L464–511, disconnect L589, `_doDispose` L603–627, device
  disconnect/dispose block L611–616 — all match the current file.
- ✅ **No `_disposed` field collision.** `NeiryBciProvider` has no existing `_disposed`
  member (the `_disposed` in `device_locator.dart` is a different class). Safe to add.
- ✅ **Terminal-path design is sound.** Setting `_disposed = true` synchronously at the
  top of `_doDispose()` before any `await`, combined with the second `_disposed` check
  after the `await` in `_resetLocatorSession()`, correctly prevents an overlapping
  teardown microtask from recreating a locator on a dying provider. No leak.
- ✅ **Settings consistency.** Plan declares Testing: no / Logging: minimal — consistent
  with the note (the helper's catch blocks are intentionally silent; existing paths keep
  their `logPrint` lines). The race in H1, however, is the kind of thing a temporary log
  line at locator create/dispose would expose during the pointer-identity verification.

## Positive Notes

- The dispose/recreate concurrency reasoning (the two `_disposed` checks straddling the
  `await`) is precise and correctly handles the `_doDispose` ↔ teardown-microtask
  overlap — this is the subtle part and the plan got it right.
- SDK assumptions are all verifiable against the actual `neiry_kit` source rather than
  assumed.
- Scope is tightly bounded, teardown-path enumeration is complete, and roadmap linkage
  is explicit.

## Recommendation

Address **H1** (serialize the reconnect scan behind the unexpected-drop locator reset,
e.g. via a teardown-completion gate awaited in `scan()`) and note **M1** as a
verification check before implementing. Everything else is solid.
