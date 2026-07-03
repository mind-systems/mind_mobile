# Code Review 3 — Start-race hardening (variant B): pending-start + timeout + retry keyed on `client_activity_id`

**Scope:** full `git diff HEAD` — `ModuleStateChannel.dart` (bulk), `ModuleStateEvent.dart`, both adapters, `GlobalListeners.dart`, `App.dart`, `BiometricStreamClient.dart`, `KeepAliveCoordinator.dart`, l10n, test migration. Each changed file read in full.
**Verification:** `flutter test test/Core/Grpc/` → 132 passed; earlier full run `test/Core/Grpc/ test/BreathModule/ test/MeditationModule/` → 464 passed; `flutter analyze` on changed production files → clean.
**Tree state:** advanced since reviews 1 and 2. Both prior findings are now fixed in the code:
- Review-1 (settling send while sink is gone) → `_resolveSettling` gates both send paths on `isConnected` (`ModuleStateChannel.dart:544-546,565`).
- Review-2 (carried re-send bypassed the 3-attempt budget) → a shared `_giveUp(type)` helper (`:521-524`) is now called from both `_onConfirmTimeout` (`:506`) and the carried loop (`:566-569`), so the budget/give-up is enforced on every retry path. Confirmed correct: the carried loop now `continue`s to `_giveUp` when `p.attempts >= 3` before any `_sendStart`, closing the INV-12 overshoot / stale-token duplicate window.

This pass re-derived the control flow independently and found no new code-level correctness bug. One coverage gap is worth recording on a test-mandated milestone.

## Findings

### [Low] The give-up surface — `SessionStartFailed` emission, type-scoped adapter reset, and carried-path budget enforcement — has zero test coverage on a "Testing: yes" milestone

`grep -rn SessionStartFailed test/` returns nothing, and the two adapter suites (`test/BreathModule/…`, `test/MeditationModule/…`) were not touched. The wire-level invariants (INV-8/9/10/11/12, SC-1/2/3/7) are well covered by `start_race_contract_test.dart`, but three **new, silently-failing** behaviors this milestone introduced are unguarded — and per the project's test-philosophy (test surfaces that fail with wrong output and no crash), these are exactly the surfaces that warrant a test:

1. **Type-scoped adapter reset** (`BreathModuleStateChannel.dart:53-58`, `MeditationModuleStateChannel.dart:35-40,50-56`). The correctness property is "a give-up for type X resets only X's adapter, never a live sibling." If the `event.type == ActivityType.breath` filter were dropped in a later edit, a meditation give-up would silently clear a **live** breath session's `_started`/`_moduleSessionId`/stopwatch mid-practice — wrong behavior, no crash, no failing test. The `wireConcurrent` harness already stands up both real adapters + the real registry, so a red/green assertion (drive meditation to give-up via 3 unconfirmed timeouts, assert the breath adapter still reports its live session) is cheap.
2. **Carried-path budget enforcement** (`_resolveSettling` → `_giveUp`, `:566-569`) — the exact behavior review-2 caught being wrong and that was just fixed reactively. There is no regression test pinning "a carried pending whose budget is spent gives up instead of re-sending on the next settling window," so the overshoot (and its past-dedup-window duplicate risk) could silently return. A fakeAsync test that spends the budget, drops the transport across a reconnect, and asserts `_starts(reopenedCall)` does not exceed 3 while a `SessionStartFailed` is emitted would lock it in.
3. **`SessionStartFailed` emission itself** — no test asserts the event fires after the 3rd unconfirmed attempt (INV-12's test only bounds the wire count `<= 3`; it never checks the give-up event or the snackbar wire in `App.dart:323`).

Not a code defect and not blocking, but on a milestone whose own settings declare `Testing: yes` and whose plan (Task 5) mandates one-pass test-migration of the full blast radius, the give-up half of the feature shipped without any assertion. Recommend adding at least the type-scoped-reset and carried-budget tests before close.

## Verified-correct (no action needed)

- **`_giveUp` shared across both retry paths** — budget is now enforced identically in `_onConfirmTimeout` and `_resolveSettling`; INV-12's ≤3 ceiling holds across reconnects, not just on a single connection.
- **No reentrancy during `_resolveSettling`** — `_events` is a `PublishSubject` (async delivery), so a `_giveUp` → `SessionStartFailed` → adapter-reset → potential re-tap lands on a later microtask, after the reconcile callback has set `_settlingActive = false` (`:217`); the re-tap then sends immediately (window closed) rather than re-entering the defer path mid-resolution.
- **Reconcile sweep precedes adopt** — the callback evicts non-re-arrived cached children (`:209-213`) before `_resolveSettling` consults `childOfType` for adopt (`:562`), so a stale same-type child cannot spoof an adopt and swallow a legitimate release.
- **Deferred vs carried disjointness** holds (step-2 `_pendingStarts.containsKey` guard in `start()`, `:403`); `carriedTypes` snapshot before the deferred loop prevents a released deferred start being re-sent twice.
- **Timer hygiene** — `_clearPendingStart`, `_giveUp`, `_resetWholeTree`, `dispose`, and the reconnect double-fire guard all cancel per-pending timers; the transport-down re-arm in `_onConfirmTimeout` is itself cancelled on reset/dispose/reconnect. No leaked `Timer`s or orphaned pendings that cannot recover on the next reconnect.
- **Adopt subsumes the removed `currentState.status == active` guard** — registry is upserted with every ACTIVE/RESUMED that flips single-state active, so same-type adopt is exact while cross-type suppression is gone (SC-1 / INV-10-cross-type green).
- **Meditation `_reset()` extraction** is behavior-identical to the previous inline reset; the `_onState` end path (`_childSessionId` addressing, re-arm) is unchanged.
- **Wiring/compile** — `SessionStartFailed` handled in both exhaustive switches; the sole `GlobalListeners(` site supplies the new required `sessionStartFailedStream`; l10n regenerated across arb + all three generated files.
