# Plan Review: Stop reallocating `timelineSteps` per tick in `BreathViewModel._onEngineState` (v2)

**Plan file:** `.ai-factory/plans/28-stop-reallocating-timelinesteps-per-tick-in-breathviewmodel-onenginestate.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** Pass. Change is confined to one ViewModel method and one StatelessWidget body — no boundary crossings, no DI changes, no module-package boundary impact.
- **RULES.md:** Pass. No App.dart, Service, DTO, or constructor-injection rules are touched.
- **ROADMAP.md:** Not verified individually, but the work chains cleanly from prior milestones 26/27 that exposed `remainingTicksNotifier` and wired the active `_TimelineItem` to it (per `notes/11-breath-session-tick-render-scope.md`).

## How v2 addresses plan-review-1

Plan-review-1's one substantive ask was: either accept the silent "completed rows now show original duration instead of `0`" UX change, or restore the affordance without per-tick allocation. v2 picks option (2) — preserve the affordance via UI-side derivation. The chosen approach (`activeIndex = steps.indexWhere(...)` in `_buildList`, then `isCompleted = activeIndex >= 0 && index < activeIndex` per item) is exactly the cheapest fix and keeps the domain `timelineSteps` list structurally stable. Issue resolved.

## Verified assumptions

- Phase 1 line refs in `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`:
  - `_onEngineState` spans 139–178. ✓
  - Locals to delete (`previousActiveId` 140, `newActiveId` 141, `remaining` 142, `updatedSteps` 144) and the `if (newActiveId != null) { … }` block (146–154) match the file exactly. ✓
  - The `_remainingTicks.value = remaining;` line at 156 must become `_remainingTicks.value = engineState.remainingTicks;` after deletion — plan calls this out. ✓
  - Constructor at 159–177 has `timelineSteps: updatedSteps` at line 167; plan correctly says to change only that one argument to `state.timelineSteps`. All other constructor arguments stay verbatim. ✓
  - `TimelineStep` is still imported and referenced by `_buildTimelineSteps` (line 182+). Plan correctly says to keep the import. ✓
  - `_setupEngine` rebuilds `timelineSteps` afresh on observe/restart (lines 105–137), so reusing `state.timelineSteps` per tick will not pin a stale list across restarts. ✓
  - Full-constructor (vs `copyWith`) requirement is correct — `copyWith` (lines 71–111 in `BreathSessionState`) cannot clear `resetReason`, `currentExerciseShape`, `nextExerciseShape` to null. ✓

- Phase 2 line refs in `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`:
  - `_buildList(bool isPausedOrComplete)` at line 131; `return ListView.builder(...)` at 132 — `activeIndex` insertion point is correct. ✓
  - `final isActive = step.id == widget.activeStepId;` at line 139 — `isCompleted` insertion point is correct. ✓
  - `_TimelineItem` constructed at lines 148–155; adding `isCompleted:` argument fits. ✓
  - `_TimelineItem` class is at 173; constructor at 184–191; inactive `Text('${step.duration ?? 0}', style: textStyle)` is at line 227; active `ValueListenableBuilder` branch is at 221–225. Changes to the inactive branch are precisely scoped. ✓
  - Separators short-circuit at 141–143 before `_TimelineItem` is built — confirmed; they are unaffected. ✓

- Edge-case correctness of `isCompleted` derivation:
  - When `widget.activeStepId == null` (e.g. before engine starts, initial state) → `activeIndex = -1` → `isCompleted = false` for every row → all rows show original duration. Matches old behavior at startup. ✓
  - When `activeStepId` references a step that exists → `indexWhere` returns its index; rows before render `0`, the active row renders the live countdown (unchanged), rows after render their original duration. Matches old behavior during play. ✓
  - On pause: `BreathSessionStateMachine.pause()` preserves `activeStepId` (line 170), so paused timeline keeps `0` for completed rows and the last live tick on the active row — matches today. ✓
  - On complete: `complete()` preserves `activeStepId` (line 208) as the last active id, so completed rows before it still show `0` and the final active row shows whatever `remainingTicks` was last published (typically `0`). Matches today. ✓
  - Separators have `step.id == null`, so they never match `activeStepId` (which is non-null when present) — separator rows short-circuit before `_TimelineItem` anyway. ✓

## Issues

### 🟢 Minor: inaccurate cost claim for `_buildList`

Plan §Phase 2 says: "The active-step index is computed once per `BreathTimelineWidget.build`, which only re-runs on structural state changes — not per tick — so the cost is amortized across an entire phase."

This is wrong about *why* the cost is small. `BreathSessionScreen.build` reads `final state = ref.watch(breathViewModelProvider);` without `select` (`BreathSessionScreen.dart:162`), so the screen — and therefore `BreathTimelineWidget` — rebuilds on every tick. `indexWhere` will run per tick, not per phase.

The change is still a clear net win: an O(N) string-equality scan per tick is far cheaper than the current per-tick `.map().toList()` that allocates new `TimelineStep` objects, and the plan's main claim ("`_onEngineState` performs zero list allocations per tick") remains accurate. Just fix the wording — e.g. swap that sentence for something like: "`indexWhere` over the small steps list (typically <50 entries) is much cheaper than the current per-tick `.map().toList()` that allocates new objects; the screen-level rebuild filter is a separate follow-up milestone."

Non-blocking — feel free to leave as-is and address in the follow-up milestone that wires `select` into `BreathSessionScreen`.

## Positive notes

- Phase split (domain reuse + UI-side derivation) cleanly isolates the perf change from the UX-preservation tactic.
- Surgical and well-bounded — one method in one file, one widget in another.
- Preserves the full-constructor pattern for the right reason and calls it out in the plan to prevent a later refactor from silently breaking nullable clears.
- Correctly identifies that `_setupEngine` rebuilds the list on restart, so frozen-list reuse during a session does not leak across sessions.
- The `isCompleted` derivation is the minimum viable fix — no extra state, no extra rebuild path, no ordering risk with `remainingTicksNotifier`.
- Explicitly scopes the broader screen-rebuild win to a separate milestone, avoiding scope creep.

## Verdict

v2 fully addresses the v1 feedback. The only remaining nit is an inaccurate sentence about when `_buildList` re-runs — the change itself is correct and ready to implement.

PLAN_REVIEW_PASS
