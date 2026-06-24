# Plan Review: C1 · Actor / serial command queue refactor (green→green)

**Plan:** `.ai-factory/plans/89-c1-actor-serial-command-queue-refactor-green-green.md`
**Target:** `lib/Bci/NeiryBciProvider.dart` (547 lines, confirmed)
**Risk Level:** 🟢 Low — plan is accurate and implementable; advisory notes below.

## Verification performed

I read the production file, the spec note (`157-...`), both characterization suites
(B1 `neiry_bci_provider_locator_device_races_test.dart`, B2 `neiry_bci_provider_full_teardown_test.dart`),
and the sole external consumer (`BciDeviceManager.dart`).

**Line references — all accurate.** Every symbol/line the plan cites matches the current file:
`_teardownComplete` :47 ✓ · scan drain :118 ✓ · connect drain :160 ✓ · disconnect drain :475 ✓ ·
teardown microtask :404 / finally :437-439 ✓ · `_teardownAfterUnexpectedDrop` :375 ✓ ·
`_onConnectionStatus` drop branch :250-262 ✓ · `_resetLocatorSession` :357-366 ✓ ·
`_doDispose` :516 ✓ · connect :158 ✓ · disconnect :473 ✓ · scan :116 ✓. The plan's decision to
re-anchor on symbols rather than the spec's stale numbers was correct and executed well.

**External surface — safe.** Grep confirms `_provider.scan()` / `connect()` / `disconnect()` are
called only from `BciDeviceManager` (:179, :220, :269, :277). No file references `_teardownComplete`
outside the provider. Public signatures are preserved (scan stays `async*`; connect/disconnect stay
`Future<void>`). The target files `SerialCommandQueue.dart` and the new test file do not yet exist.

## Context Gates

- **Architecture (WARN-clear):** `SerialCommandQueue` as pure Dart with no Flutter/Riverpod imports
  honors the documented domain-layer rule. Single-resource actor around the BCI locator/device only —
  the plan's explicit anti-goal (do not fold in `ModuleStateChannel` / `BiometricStreamClient` latches)
  aligns with the module-boundary architecture. No boundary violation.
- **Rules (clear):** Logging constraint satisfied — "preserve existing `logPrint`, add none." No new
  `print`/`debugPrint`. No proto changes. No manual `pubspec.yaml` edits (no new deps).
- **Roadmap (clear):** Plan self-identifies as Phase 55 layer C, last in the chain; refactor-only,
  no roadmap milestone linkage needed.

## Critical Issues

None. No blocking defects found.

## Highest-risk area (must get right, but plan describes it correctly)

**The fire-and-forget unhandled-error semantics in Task 3 / Task 1.** B2's "throwing connection-sub
cancel" test (`full_teardown_test.dart:618`) asserts the injected `StateError` surfaces as an
*unhandled async error* in the surrounding zone (`asyncErrors` non-empty). The current code achieves
this because the teardown microtask future is assigned to `_teardownComplete` but never observed on
this path, so its rejection is reported as unhandled.

The queue design must preserve exactly this: the `enqueue` return future (Completer-backed) must
**complete with the command's error**, and since the teardown enqueue is fire-and-forget (Task 3:
"do not await the returned future"), that error future stays unobserved → unhandled → delivered to the
zone. The plan states this correctly in Task 1 ("carries the command's result/error to the caller,
while `_tail` never rejects") and Task 3. **Implementation trap to avoid:** do not attach a blanket
`.catchError((_){})` to the *returned* future as well — only `_tail` may be insulated from rejection.
If the returned/caller future is also swallowed, B2's throwing-cancel test fails (`asyncErrors` empty).
This is the single most fragile assertion in the suite; call it out in the Task 3 implementation.

## Advisory notes (non-blocking)

1. **Why green→green actually holds (timing).** Both suites pump with
   `await Future<void>.delayed(Duration.zero)` (a zero-duration *timer*), and all pending microtasks
   drain before a timer fires. The queue introduces extra microtask hops (Completer chaining,
   `_tail` continuation), but these are fully absorbed within each timer pump, so the suites' existing
   pump counts in `_completeTeardown` (4 pumps) and the throwing-cancel path (3 trailing pumps) remain
   sufficient. One thing to confirm in Task 7: after the drop emit + single pump in `_connectThenDrop`,
   the enqueued teardown command must have *started* and reached its first `await device.stopStream()`
   (so `stopStreamCallCount` ticks and it blocks on the gate). Chaining onto an already-resolved
   `_tail` runs the body on the next microtask, which lands inside that same pump — so this holds, but
   it is the assumption the whole green→green argument rests on; verify empirically, don't infer.

2. **`_doDispose` ordering nuance.** Task 2 sets `_disposed = true` *before* `await _queue.idle`.
   Consequence: if a teardown command is in-flight when dispose runs, its `finally` →
   `_resetLocatorSession()` will observe `_disposed == true` and skip the recreate. This is the
   desired poison-pill behavior (and exactly what Task 6's third sub-test asserts), and it does **not**
   regress B1/B2 because both suites fully complete teardown *before* calling `dispose()`. Worth a
   one-line code comment so a future reader doesn't "fix" the ordering.

3. **`await _queue.idle` can block on a gated command.** In Task 6's third sub-test (gate a
   drop-teardown, then `dispose()`), `_doDispose` will suspend at `await _queue.idle` until the gated
   command settles. The no-recreate assertion (createdCount unchanged) is observable *before* the gate
   is released because the in-flight teardown hasn't reached recreate — but the test author must either
   assert before releasing, or release the gate so `_doDispose` can finish. Since Task 6 is new code
   the implementer owns, just flag it in that test's construction; the plan's description is adequate.

4. **scan() poison-pill after dispose.** Once `dispose()` closes the queue, a still-queued `scan`
   command's future rejects with `StateError`, which propagates out of the `async*` generator as a
   scan-stream error. Confirmed non-regression: `BciDeviceManager`'s scan `onError` (`:198-208`,
   `:293`) handles arbitrary errors gracefully (non-permission → `BciIdle`), so no crash. The old code
   had undefined behavior here (it would call `requestDevices` on a disposed locator), so this is a
   strict improvement. No action needed; noted for completeness.

5. **Constraint 1 (no self-deadlock) is structurally satisfied.** Every command body that the plan
   defines — teardown, connect-failure cleanup, disconnect — calls `_resetLocatorSession()` *directly*
   (which calls `_locator.dispose()` directly), never via `enqueue`. No command awaits another enqueued
   command. The only cross-command dependency (`reconnect-scan → teardown`) is one-directional as
   required. Good.

## Positive Notes

- Outstanding precision: the plan converted the spec's stale line numbers to verified current symbols
  and explicitly warned against trusting the spec's `:513`/`:617` figures.
- The three binding constraints are correctly mapped onto concrete code edits, and the subtle
  distinction in Constraint 3 ("remove the detached `Future.microtask`, *keep* the inner
  `try/finally` recreate") is exactly what B2's throwing-cancel test requires — a trap the plan
  defuses up front.
- Commit plan is sensibly staged so the suite is runnable between groups (1–2 wire dispose, 3–5 route
  ops, 6–7 verify).
- Task 7 correctly frames the inverted-test discipline: a needed assertion edit means the production
  code is wrong, not the test.

The plan is solid and implementable as written; the notes above are guard-rails for implementation,
not plan defects.

PLAN_REVIEW_PASS
