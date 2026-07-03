# Plan Review: Per-child RESUMED consumption (concurrent-duplicate closure)

**Plan:** `.ai-factory/plans/29-per-child-resumed-consumption-concurrent-duplicate-closure.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — accurate against the committed tree; ready to implement.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** No boundary/dependency violation. The plan is test-only (Phase 1) with a contingent single-chokepoint edit (Phase 2); it touches `test/Core/Grpc/` and, only if red, `ModuleStateChannel.dart`. No layering crossed. — OK
- **Rules (`.ai-factory/RULES.md`):** No rule engaged — the touched code is Core infra, not a Module Service; no App.dart change; no new external wiring. — OK
- **Roadmap (`ROADMAP.md:100`):** Milestone line matches the plan title exactly and the plan honors every clause of the contract line: "RED scenario first (2 children, reconnect, 2 RESUMED, assert both cleared + zero resend)" and "Route through the note-28 chokepoint." Depends-on ("the lift", note 28) is satisfied — task 26/note 28 is `[x]` at `ROADMAP.md:99`. — OK
- **Governing spec (`.ai-factory/notes/29-...md`):** Plan is faithful to the spec note. Spec §Verify ("Extend `start_race_contract_test.dart` (SC-1 concurrent shape)… assert both pending-starts cleared and zero resend") maps 1:1 to Phase 1. Spec §Guards ("no new hand-guarded resolution site", "never resend a start whose child the server already resumed") maps to Phase 2's constraint. — OK

## Codebase-accuracy verification

Every concrete assertion in the plan's "Key architecture finding" was checked against source:

- `_processProtoEvent` calls `_clearPendingStart(activityType)` on both the RESUMED branch (`ModuleStateChannel.dart:319`) and ACTIVE branch (`:329`), keyed by the frame's own `activity_type`. ✓
- `_clearPendingStart` (`:626-629`) is the sole confirmed-resolution chokepoint, and its doc comment (`:624`) explicitly names it as note-29's seam. ✓
- Reconnect open arms a settling window (`_settlingActive`, `:222`), cancels each carried pending's confirm timer (`:229-232`), and `_resolveSettling` snapshots `carriedTypes = _pendingStarts.keys` (`:594`) only after the 3 s window (`:234-242`). ✓
- Harness helpers named by the plan all exist and have the signatures used: `wireConcurrent`, `connectAndFlush`, `runningBreathState`, `activeMeditationState`, `childResumedFrame(type, id, {required isPaused})`, and file-local `_starts(...)`. ✓
- Target group string `'start-race contract — concurrent breath+meditation & settling window (note 19)'` exists verbatim at `start_race_contract_test.dart:177`. ✓

### Scenario trace (confirms expected-green outcome)

Walking the plan's 8 steps through the real control flow:

1. First `connectAndFlush` enters `_openSessionStream` from `disconnected` → `isReconnectOpen == false`, no settling. Registry empty.
2. Breath + meditation starts both reach the wire (per-type `_pendingStarts` from note 19); `_starts(latestCall).length == 2`; both unconfirmed → two live carried pendings, registry still has no children (children only upsert on ACTIVE/RESUMED).
3. Bare `responseCtrl.close()` → `onDone` with `_supersededOnThisStream == false` → `_closeSessionStream` (does **not** touch `_pendingStarts`) → `reconnecting`. `pushConnected` → `_openSessionStream` from `reconnecting` → `isReconnectOpen == true`, settling armed, carried timers cancelled. `snapshotChildIds` empty (no confirmed children) → the sweep is a no-op, so there is no eviction risk. ✓
4. Two per-child RESUMED frames each run `_clearPendingStart(own type)` immediately in `_processProtoEvent` (inside the window) and `_upsertRegistryEntry` records both arrivals and populates the registry. `_pendingStarts` now empty. ✓
5–6. At `elapse(3s)` the reconcile timer runs `_resolveSettling`: `carriedTypes` snapshot is empty, `_deferredStarts` empty → nothing sent → `_starts(reopenedCall)` isEmpty. ✓
7. Both children remain in the registry (sweep no-op over empty snapshot), so `childOfType(breath)`/`childOfType(meditation)` are non-null. ✓

The breath/meditation adapters do **not** subscribe to `sessionStreamOpened` (verified in `BreathModuleStateChannel.dart` — start is guarded by `_started` and only fires on a state-stream lifecycle transition), so no adapter re-sends a start on reopen. The reopened wire genuinely stays empty. Even in the hypothetical where an adapter re-tapped `start`, it would be deferred and then adopt the now-live child at window close — still zero resend. The step-7 teeth-assertion correctly guards against a false pass.

Conclusion: the test is **expected green on the committed tree**, exactly as the plan states. Phase 2's production edit is a correctly-scoped safety net that will not be needed.

## Non-blocking notes (no action required)

- **"RED-first" is aspirational here, and the plan says so.** Because the note-28 `_clearPendingStart` seam is already positioned and the API change is external, this test cannot be made red against the current *client* tree — the historical duplicate only manifested against the old single-collapsed-frame *API* behavior, which the test cannot reproduce (it injects two frames by construction). The plan is honest about this (Phase 1 annotation instructs documenting the green status and the collapsed-frame counterfactual), so this is a framing nuance, not a defect. Recommend the test's annotation explicitly state "cannot be red on this tree; the RED baseline is the pre-`47e6914` single-frame API" so a future reader doesn't mistake it for a broken RED-first.
- **New import required (already flagged in the plan).** Step 7 needs `import 'package:mind/Core/Grpc/ActivityType.dart';` for `ActivityType.breath`/`.meditation`; the file currently imports only `ModuleState.dart` and the proto. The plan calls this out ("import `ActivityType`") — noting it here only for completeness.

## Positive notes

- The plan correctly refuses to inject `globalResetFrame()` on the reconnect and explains why (a reset would clear `_pendingStarts` and destroy the carried-pending premise the test exists to exercise) — this is the exact trap the two existing INV-11 tests deliberately avoid in the opposite direction, and the author understood the distinction.
- Routing the contingent fix strictly through `_clearPendingStart` with an explicit "no fourth hand-guarded site / no re-check of `isConnected`/budget in a new caller" constraint directly enforces the note-28/note-29 §Guards invariant and prevents reintroducing the scattered-guard root cause that caused task 26's multi-round chain.
- The step-7 registry-adoption assertion is a genuine strengthening — without it, an `isEmpty` check alone would pass even if the frames were silently dropped rather than consumed.

PLAN_REVIEW_PASS
