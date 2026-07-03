# Code Review: Per-child RESUMED consumption (concurrent-duplicate closure)

**Scope reviewed:** `git diff HEAD` — the only production/test code change is the new test in
`test/Core/Grpc/start_race_contract_test.dart`. The remaining staged files are planning
artifacts (plan `.md`/`.json`, plan-review `.md`), not code.

**Result:** No production code was changed. Phase 2 correctly concluded that the concurrent
path is already closed by the API fix (`mind_api 47e6914`) plus the pre-positioned
`_clearPendingStart` seam (note 28), so the deliverable is the RED-first regression test.

## Verification performed

- Ran `flutter test test/Core/Grpc/` → **137/137 pass**, including the new
  `note 29: concurrent per-child RESUMED frames each consume their own carried pending — zero resend`.
  No existing assertion weakened or broken.
- Ran the new test in isolation (`--plain-name "note 29"`) → passes (+1).
- Read the full test file and `Support/reconnect_concurrency_harness.dart`, and hand-traced
  the scenario through `ModuleStateChannel` (`_openSessionStream`, `onDone`, `_processProtoEvent`
  RESUMED branch, `_clearPendingStart`, `_resolveSettling`).

## Correctness analysis (test change)

- **Carried-pending path genuinely exercised.** Two unconfirmed starts land on the first
  call; a bare `responseCtrl.close()` drives `onDone` with `_supersededOnThisStream == false`,
  which calls `_closeSessionStream()` (does **not** touch `_pendingStarts`) → `reconnecting`.
  `pushConnected` reopens from `reconnecting` (`isReconnectOpen == true`,
  `ModuleStateChannel.dart:207`), arming the settling window and cancelling both confirm timers
  (`:229-232`) → both pendings are truly *carried*, which is the exact state note 29 targets.
- **The test has teeth.** If the RESUMED-branch `_clearPendingStart` regressed, both pendings
  would remain carried and `_resolveSettling`'s `carriedTypes = _pendingStarts.keys` snapshot
  (`:594`) would re-send both at `elapse(3s)` → `_starts(reopenedCall).length == 2`, failing the
  `isEmpty` assertion. The assertion is not vacuous.
- **No spurious-resend contamination.** Only `flushMicrotasks` (no time elapse) separates the
  initial sends from the reconnect, so the 5 s confirm timers never fire before being cancelled
  at reopen; `elapse(3s)` fires only the 3 s reconcile timer. The observed empty wire is
  attributable solely to the per-child RESUMED consumption, not to timer quiescence.
- **Asserts on the right call.** `reopenedCall` is captured after `pushConnected`; the two
  initial starts were recorded on the first `TrackActivityCall`, so `_starts(reopenedCall)`
  isEmpty correctly reads as "zero resend after reconnect."
- **Registry teeth-assertion is sound.** `childOfType(breath)`/`childOfType(meditation)` non-null
  confirms both frames were consumed (via `_upsertRegistryEntry`) rather than silently dropped;
  the empty `snapshotChildIds` makes the reconcile sweep a no-op so neither adopted child is
  evicted. Added `ActivityType` import is used and necessary.
- **No reset injected on reconnect** — correct and deliberate; a `globalResetFrame()` would clear
  `_pendingStarts` via `_resetWholeTree()` and destroy the carried-pending premise. The plan and
  test both avoid this trap.

## Non-blocking observations (no action required)

- The test proves "2 frames → 0 resend" but does not independently pin the *per-type* nature of
  the clear (e.g. "1 frame arrives → only that type clears, the other still resends 1"). The
  `isEmpty` teeth plus the existing INV-11 defer/adopt tests already cover the mechanism, so this
  is a possible future strengthening, not a gap in the milestone's contract (spec §Verify asks
  specifically for the 2-frame closure).
- The comment block accurately labels the test GREEN-on-current-tree and explains the historical
  collapsed-frame counterfactual — good documentation of why "RED-first" is a methodology note
  here rather than a literal red-on-this-tree state (the pre-fix duplicate manifested only
  against the old single-frame *API*, which the test cannot reproduce by construction).

REVIEW_PASS
