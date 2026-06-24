# Plan Review: Extract the triplicated teardown sequence into one helper (T6)

**Plan:** `.ai-factory/plans/95-t6-extract-the-triplicated-teardown-sequence-into-one-helper.md`
**Target file:** `lib/Bci/NeiryBciProvider.dart`
**Risk Level:** 🟢 Low — refactor is well-scoped, behavior-preserving, and line-accurate.

## Verdict

The plan is implementable as written. I verified every line reference, the canonical step order, the sub-cancellation order, the test assertions the plan must not break, and the SDK feature it relies on (records). All check out. The findings below are nuances to keep in mind during implementation, not blockers.

## Context Gates

- **Architecture (WARN→none):** The refactor is entirely internal to `NeiryBciProvider`. No port boundaries are crossed; the only privileged import (`neiry_kit`) is untouched. No new cross-module dependency. No issue.
- **Rules (none):** `.ai-factory/RULES.md` covers Module Service statelessness / App.dart / constructor DI — none apply to this provider-internal extraction. No violation.
- **Roadmap (aligned, WARN on design hint):** Matches `ROADMAP.md:312` (T6). The roadmap describes the helper as *"parameterized over capture-locals (drop) vs read-fields (terminal)"*. The plan instead unifies **all three** sites onto the capture-and-null helper (Task 1) and the locals-only teardown helper (Task 2). This is a *cleaner* design (single capture/null path, helper never reads instance fields) and is justified in the plan, but it is a deliberate divergence from the roadmap's wording — flagging so it is a conscious choice, not an oversight. The plan also does not cite the spec note `.ai-factory/notes/170-bci-extract-teardown-helper.md` referenced by the roadmap; worth a quick cross-check before implementing in case the note carries extra constraints.

## Verified Correct

- **Line references** — all accurate against the current file: `_teardownAfterUnexpectedDrop` (398–480), `_cancelDeviceSubscriptions` (482–510), `disconnect()` (512–546), `_doDispose()` (556–593).
- **Canonical order** — the plan's step list and the 10 fan-in subs (in cancel order `_connectionSub … _memsSub`) exactly match both the drop path (436–445) and `_cancelDeviceSubscriptions` (483–502). `_calibrationSub` (line 69) is correctly excluded from the 10.
- **Test contract** — the B2 "pure drop" probe asserts `['stopStream','cancelFanIn','classifierDispose','deviceDisconnect','deviceDispose','locatorDispose','locatorCreate']` and the contiguous-block probe; the plan's helper produces exactly this order on the drop path (`forceStopStream:true, recreate:true`). The reorder probe in Task 6 will correctly break B2 in one place. No assertion edits required — confirmed.
- **Record return type** — `(DevicePort?, ClassifierSet?, List<StreamSubscription<dynamic>?>)` is valid: Dart's `StreamSubscription<T>` is covariant, so the typed sub fields assign into a `List<StreamSubscription<dynamic>?>` and `.cancel()` works. SDK is `^3.11.0`, so records are available.
- **Terminal `recreate:false`** — correct: `_doDispose` disposes `_locator` directly, and `_resetLocatorSession` early-returns once `_disposed` is true, so it cannot be reused for terminal disposal. The plan respects this.
- **`_disposed` guard placement** — the drop path keeps its `if (_disposed) return` (Task 3); the Task 1 capture helper is intentionally guard-free so `_doDispose` (which has already set `_disposed = true`) can still run it. Consistent.

## Findings (non-blocking)

### 1. Task 4 changes `disconnect()`'s error semantics — WARN
Currently `disconnect()` runs `device.disconnect()` and `device.dispose()` in **two separate try/catch blocks** (lines 529–539): if `disconnect()` throws, `dispose()` *still runs*. The shared helper (Task 2) puts both in **one combined try/catch**, so a throwing `disconnect()` **skips** `dispose()` on this path. This is a genuine behavior change on the `disconnect()` path, and it sits in slight tension with the plan's Context line "preserving behavior exactly" / "byte-for-byte preserved." The plan *does* call this out in Task 4 and notes no test covers `disconnect()`'s error edge (only the drop path's combined-form error path is tested), so the suite stays green. Recommendation: keep the acknowledgement, and treat the loss of the "dispose-after-failed-disconnect" attempt as accepted (it matches the already-canonical drop/terminal form). Just don't describe the overall change as zero-behavior-delta — this path has one.

### 2. Field-nulling timing in `disconnect()` / `_doDispose()` shifts earlier — neutral/safer, note only
Today `_cancelDeviceSubscriptions` nulls each sub field *interleaved* with its `await cancel()`, and `disconnect()` nulls `_device` only at the very end (line 540). The new design nulls all 12 fields **synchronously up front** (Task 1 helper) before any await. This closes the documented "disconnect-racing-drop double teardown" window (`ROADMAP.md:305`): a `down` event arriving mid-`disconnect()` will now see `_device == null` and hit the idempotency guard (line 266) instead of enqueuing a second teardown. That is an improvement, not a regression, and no test pins the old interleaved timing — but it is a real observable change in concurrent ordering, so verify the full `test/Bci/` suite (Task 6) rather than assuming it is a pure no-op.

### 3. `device?.isStarted` read on the captured local — verify, not a bug
For `forceStopStream:false`, the helper guards on `device?.isStarted == true` using the **passed-in local**, after Task 1 has nulled the `_device` field. Since the local holds the same `DevicePort` reference, `isStarted` still reflects device state correctly. Confirmed safe — calling out only because the guard moves from reading `_device` to reading a local, which an implementer should preserve exactly (don't accidentally re-read `_device`, which is now null).

### 4. `_calibrationSub` handling in `_doDispose` — keep outside the helper
Task 5 correctly keeps `_calibrationSub?.cancel(); _calibrationSub = null;` out of both helpers (Task 1 must not touch it). Just ensure the implementer does not "tidy" calibration cancellation into the capture helper — the drop path must never cancel it (line 397 contract), and only the terminal path does. The plan states this; flagging because it is the single easiest mistake to make during extraction.

## Positive Notes

- The plan reads the three sites carefully and enumerates every behavioral variation axis (forceStopStream, recreate, calibrationSub, combined-vs-separate try) before proposing the helper signature — exactly the right altitude for a load-bearing refactor.
- Task 6's deliberate-reorder-then-revert step is a strong validation that the order is genuinely single-sourced, not just visually consolidated.
- Commit plan cleanly separates "add helpers (dead)" → "migrate sites" → "verify", so each commit is independently green and reviewable.
- Correctly preserves the queue/`unawaited`/`.catchError` scaffolding (incl. `QueueClosedException` handling) around the drop path and scopes the helper to the ordered async unit only.

## Recommendation

**PLAN_REVIEW_PASS** — proceed. During implementation: (a) update the Context's "byte-for-byte" framing to acknowledge the `disconnect()` combined-try delta from Finding 1, (b) run the full `test/Bci/` suite per Task 6 given the timing shift in Finding 2, and (c) skim spec note 170 for any extra constraints.

PLAN_REVIEW_PASS
