# Plan Review 2: Recreate the SDK DeviceLocator on every disconnect (NeiryBciProvider)

**Plan:** `.ai-factory/plans/81-recreate-the-sdk-devicelocator-on-every-disconnect-neirybciprovider.md`
**Spec note:** `.ai-factory/notes/145-bci-locator-recreate-on-disconnect.md`
**Target file:** `lib/Bci/NeiryBciProvider.dart`
**Risk Level:** 🟢 Low

## Summary

This revision incorporates the fixes requested in review 1. The plan now adds a
provider-owned teardown-completion gate (`_teardownComplete`) that `scan()` and
`connect()` await before reading `_locator`, which closes the H1 race, and it
documents M1 (first-scan-on-fresh-locator readiness) as an explicit verification
probe with an out-of-scope follow-up path. All line references still match the
current source, the four teardown paths remain completely enumerated, and the
dispose-vs-recreate concurrency design (the two `_disposed` checks straddling the
`await`) is unchanged and still correct.

I re-traced the gate mechanism against the actual code and it holds. No blocking
issues remain.

## Context Gates

- **Architecture (OK):** `.ai-factory/ARCHITECTURE.md` present. All changes stay inside
  `NeiryBciProvider`, the only file permitted to import `neiry_kit` (header L31–33). The
  gate is provider-internal and does not cross the `IBciDeviceProvider` boundary —
  `BciDeviceManager` is untouched. No boundary violation. ✅
- **Rules (OK):** `.ai-factory/RULES.md` concerns Module Services / App.dart / constructor
  DI — none apply to this provider-internal change. ✅
- **Roadmap (OK):** Linked to task 145 (ROADMAP.md L268). The prerequisite kit bump
  (L267, commit `836699b`) is `[x]` done. Linkage is explicit and correct. ✅

## H1 — Resolved (verified)

The review-1 race (reconnect `scan()` reading the old `_locator` while the
unexpected-drop microtask disposes that same instance, cancelling the scan's binary
handler without closing its `StreamController` → manager hangs in `BciScanning`) is
closed by the gate. I confirmed the happens-before chain against the code:

1. `_onNeiryConnectionState` (L246) calls `_teardownAfterUnexpectedDrop()` **before**
   `_connectionStateController.add(BciLinkStatus.down)` (L257). Under the revised plan,
   `_teardownComplete` is assigned **synchronously** inside `_teardownAfterUnexpectedDrop()`.
2. `_connectionStateController` is a broadcast controller, so the `down` event is
   delivered to `BciDeviceManager`'s listener (L65) **asynchronously** — strictly after
   the synchronous assignment in step 1.
3. The listener calls `_attemptReconnect()` → `_provider.scan().listen(...)`. The
   `async*` body does not run until listened, and its first statement is
   `await _teardownComplete`. Since the field was already assigned in step 1, the scan
   blocks until the microtask (including the final `_resetLocatorSession()`) completes.
4. `_resetLocatorSession()` disposes the old locator and assigns a fresh one. The scan
   resumes and reads the field at `requestDevices()` (L138, lazy read) → it sees the
   **new** locator, which the microtask never disposes. No cancellation race.

Secondary points I checked and that hold:
- The microtask cannot leave `_teardownComplete` rejected: every step is individually
  try/caught and `_resetLocatorSession()` swallows its own dispose `StateError`, so the
  future always completes normally. `await _teardownComplete` will not throw; the
  defensive `try/catch (_)` is harmless. ✅
- Storing the microtask in a field (instead of `unawaited(...)`) satisfies
  `unawaited_futures` — an assignment statement is not a bare future expression, so the
  lint does not fire. The plan's claim is correct. ✅
- Re-drop during reconnect reassigns `_teardownComplete`; a scan already awaiting the
  prior future correctly waits on that prior teardown (the field is read once at the
  `await`). Each drop is serialized behind its own reset. ✅
- `_device` is nulled **synchronously** in `_teardownAfterUnexpectedDrop()` (L447), so by
  the time the gated `connect()` runs (after scan), the `_device != null` guard (L148)
  will not false-trip. ✅
- Terminal overlap (`_doDispose()` ↔ in-flight microtask) is still safe: `_disposed = true`
  set synchronously before any `await`, the two `_disposed` checks in
  `_resetLocatorSession()` bail before recreate, and `_doDispose()`'s own
  `_locator.dispose()` is try/caught so a double-dispose is a no-op. No leaked native
  session under any interleaving. ✅

## M1 — Appropriately deferred

`requestDevices()` does not await the locator's private `_nativeReady`, so the first
reconnect scan may run against a locator whose native `create` is still in flight. The
plan correctly treats this as a verification probe (Verification §M1) rather than a code
change, because the only real mitigations (a readiness delay or a kit-side
`_nativeReady` await in `requestDevices`) live inside `neiry_kit`, which this single-file
change is forbidden to touch. Documenting it as a note-145 follow-up is the right call.
✅

## Line References — Re-verified

- Field `final _locator = neiry.DeviceLocator();` — L35. ✅
- `scan()` top — L103 (gate before permission checks and before the L138 `requestDevices`). ✅
- `connect()` — L147; gate before the `_device != null` guard (L148) / `createDevice` (L154). ✅
- connect-failure cleanup — catch L162, `_device = null` L183, `rethrow` L184. ✅
- `_teardownAfterUnexpectedDrop()` microtask — L464–511 (Step 4 device disconnect/dispose
  L504–510); the reset is appended as the final step. ✅
- `disconnect()` — `_device = null` L589, before the `add(BciLinkStatus.down)` L592. ✅
- `_doDispose()` — L603–627; device disconnect/dispose block L611–616. ✅

## Minor Notes (non-blocking)

- **`_teardownComplete` is never nulled.** After a reconnect it holds a completed future
  forever; subsequent `scan()`/`connect()` await a completed future (instant). Harmless —
  not worth adding cleanup.
- **`connect()`'s gate await is redundant in the reconnect path** (scan already awaited
  the same future before `connectDevice`), but it is idempotent and cheap, and it
  correctly covers any future caller that reaches `connect()` without going through
  `scan()`. The plan already acknowledges this.
- **Out-of-realistic-scope edge case:** a manual `startScan()` issued while a device is
  still `BciActive`, racing a drop, is not covered by the gate if the scan passes its
  await before the drop assigns `_teardownComplete`. This is not a normal flow (you scan
  when idle, not while connected) and is not the verified on-device path; no action
  needed, mentioned only for completeness.

## Positive Notes

- The H1 fix is minimal, stays entirely within `NeiryBciProvider`, and serializes via a
  single field rather than introducing locks or touching `BciDeviceManager`.
- The happens-before reasoning (synchronous field assignment before async broadcast
  delivery) is exactly what makes the gate sound, and the plan's rationale captures it.
- Concurrency reasoning for the terminal path (the two `_disposed` checks around the
  `await`) carried over from review 1 and remains correct.
- Verification section now explicitly covers both reconnect routes, the H1 no-hang
  outcome, the M1 readiness probe, and the functional recalibrate cycle.

## Recommendation

The plan is solid and ready to implement. Both review-1 issues are resolved (H1 by the
teardown gate, M1 by an explicit verification probe with a documented follow-up). No
blocking issues.

PLAN_REVIEW_PASS
