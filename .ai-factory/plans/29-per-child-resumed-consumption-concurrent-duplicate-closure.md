# Plan: Per-child RESUMED consumption (concurrent-duplicate closure)

## Context
Close the last concurrent-duplicate residue from task 26: with ≥2 live children under one root, a reconnect now delivers a **per-child** RESUMED frame per child (mind_api `47e6914`), so each child's pending-start must clear on its own `activity_type` — zero resend, no past-dedup-window duplicate. Lock this closure with the RED-first concurrent scenario, routing all clearing through the note-28 chokepoint.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Key architecture finding (read before implementing)

The consumption seam **already exists** — do not add a new resolution site.

- `_processProtoEvent` (`lib/Core/Grpc/ModuleStateChannel.dart:309-358`) calls `_clearPendingStart(activityType)` on **both** the RESUMED branch (`:319`) and the ACTIVE branch (`:329`), keyed by the frame's own `activity_type`.
- `_clearPendingStart` (`:626-629`) is the note-28 **confirmed-resolution chokepoint** — its own doc comment (`:624-625`) states it "is the seam note-29's per-child RESUMED consumption will call."
- On a reconnect open (`_openSessionStream:197-298`), a settling window arms (`_settlingActive`, `:222`), each pending-start is carried (its confirm timer cancelled, `:229-232`), and `_resolveSettling` (`:591-613`) snapshots `carriedTypes = _pendingStarts.keys` (`:594`) only **after** the 3 s window elapses (`:234-244`).
- Because mind_api now emits **two** per-child RESUMED frames (one per live child, each `_clearPendingStart`-ing its own type) inside that window, `_pendingStarts` is empty by the time `_resolveSettling` snapshots → `carriedTypes` empty → **zero resend**. The historical single collapsed frame (root only) cleared no child pending → both carried → both resent past the dedup window → duplicate.

**Expected outcome:** the closure test goes green on the current committed tree — the API fix plus the pre-positioned `_clearPendingStart` seam already close the concurrent path. Write the test RED-first (author it, run it); only if it surfaces a genuine gap, route the fix through `_clearPendingStart` (never a fourth hand-guarded resolution site, per note 28 §Guards).

## Tasks

### Phase 1: RED-first concurrent-duplicate closure test

- [x] **Task 1: Add the concurrent per-child RESUMED consumption test (SC-1 concurrent shape)**
  Files: `test/Core/Grpc/start_race_contract_test.dart`
  Add one test to the existing `'start-race contract — concurrent breath+meditation & settling window (note 19)'` group. Reuse the harness helpers from `Support/reconnect_concurrency_harness.dart` (`wireConcurrent`, `connectAndFlush`, `runningBreathState`, `activeMeditationState`, `childResumedFrame`, and the file-local `_starts(...)`).
  Scenario (mirror the `fakeAsync` + `async.flushMicrotasks()` pumping style already used in this file — never `Future.delayed`):
  1. `wireConcurrent()`; `connectAndFlush(f, async)`.
  2. Drive `f.breathStateCtrl.add(runningBreathState())` then `f.meditationStateCtrl.add(activeMeditationState())`, flushing after each → both starts reach the wire on the first call, both **unconfirmed** (no ACTIVE/RESUMED received). Sanity-assert `_starts(f.service.latestCall!).length == 2`.
  3. Reconnect **without** a reset: `f.service.latestCall!.responseCtrl.close()` (bare close → `onDone` → `reconnecting`; flush), then `f.connManager.pushConnected()` (flush) → capture `reopenedCall = f.service.latestCall!`. Do **not** inject `globalResetFrame()` — a reset would clear `_pendingStarts` and defeat the point; the pendings must survive the reconnect as **carried**.
  4. Inject **two** per-child RESUMED frames on `reopenedCall.responseCtrl`: `childResumedFrame(proto.ActivityType.BREATH, 'breath-1', isPaused: false)` and `childResumedFrame(proto.ActivityType.MEDITATION, 'med-1', isPaused: false)`, flushing after each.
  5. `async.elapse(const Duration(seconds: 3))` (close the settling window); flush.
  6. Assert `_starts(reopenedCall)` **isEmpty** — both per-child RESUMED cleared their own type's pending-start before the settling window resolved, so `_resolveSettling` resends neither (zero duplicate). Add reason text tying it to note 29 (the collapsed-frame past-behaviour would have resent both here).
  7. Strengthen the assertion so it has teeth vs a false pass: also assert both children are now adopted in the registry — `f.channel.childOfType(ActivityType.breath)` and `childOfType(ActivityType.meditation)` are non-null (import `ActivityType`), proving both frames were genuinely consumed, not merely absent.
  8. `f.channel.dispose()`.
  Annotate the test with the note-29 rationale and its status against the current tree (green — the per-child RESUMED consumption reuses the `_clearPendingStart` chokepoint positioned by note 28; the historical single collapsed frame would have left both carried → 2 resends).

### Phase 2: Green + confirm no new resolution site

- [x] **Task 2: Run the suite; confirm closure routes through the chokepoint (contingent fix only)** (depends on Task 1)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart` (only if the test is red)
  Run `flutter test test/Core/Grpc/` (use `/usr/local/bin/flutter`). Expected: the new test passes on the current tree and every existing assertion stays green — `start_race_contract_test.dart` (notes 19), `reconnect_eviction_contract_test.dart` (note 20), and the note-27/28 golden masters — none modified.
  - If the new test is **green** (expected): the concurrent-duplicate closure is already in place via the pre-positioned `_clearPendingStart` seam; no production change. Done.
  - If the new test is **red**: the per-child RESUMED for one type is not clearing its pending before `_resolveSettling` snapshots. Route the fix through the existing `_clearPendingStart` confirmed-resolution chokepoint (`ModuleStateChannel.dart:626-629`) — e.g. ensure the RESUMED branch's clear runs for every arriving per-child frame during the settling window. **Do not** add a fourth hand-guarded resolution site and **do not** re-check `isConnected`/budget in a new caller (note 28 §Guards; note 29 §Guards). Re-run until the full `test/Core/Grpc/` suite is green with no pre-existing assertion weakened.
