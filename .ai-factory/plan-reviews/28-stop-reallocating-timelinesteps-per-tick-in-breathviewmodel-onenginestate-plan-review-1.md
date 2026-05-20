# Plan Review: Stop reallocating `timelineSteps` per tick in `BreathViewModel._onEngineState`

**Plan file:** `.ai-factory/plans/28-stop-reallocating-timelinesteps-per-tick-in-breathviewmodel-onenginestate.md`
**Risk Level:** 🟡 Medium

## Context Gates

- **ARCHITECTURE.md:** Pass. Change is confined to a single ViewModel method, no boundary crossings, no DI changes.
- **RULES.md:** Pass. Rules concern module Services, App.dart, and constructor injection — none touched here.
- **ROADMAP.md:** Not verified; this perf milestone clearly chains from items 26/27 (expose `remainingTicksNotifier`, wire active `_TimelineItem` to it) per the linked note `notes/11-breath-session-tick-render-scope.md`.

## Verified assumptions

- `_onEngineState` is at lines 139–178 in `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`. ✓
- The block to delete (lines 140–154) covers `previousActiveId`, `newActiveId`, `remaining`, the `List<TimelineStep> updatedSteps = state.timelineSteps;` declaration, and the `if (newActiveId != null) { … }` rebuild. ✓
- The active step's countdown is consumed via `remainingTicksListenable` inside `_TimelineItem` (`BreathTimelineWidget.dart:221-225`), so writing `remaining` into the active step's `duration` is already a dead write for the visible cell. ✓
- `_remainingTicks.value = engineState.remainingTicks;` keeps the per-tick channel ticking for the active `_TimelineItem`'s `ValueListenableBuilder`. ✓
- Raw-stream consumers (`BreathAnimationCoordinator`, `OrbAnimationCoordinator`, `BreathSoundCoordinator`, `BreathModuleStateChannel`) read `engineState`-derived fields off `BreathSessionState` directly, not off `timelineSteps`. ✓
- `_buildTimelineSteps` still references `TimelineStep`, so the import must stay — plan correctly calls this out. ✓
- `_setupEngine` rebuilds `timelineSteps` from scratch on restart/observe, so reusing `state.timelineSteps` per tick does not pin a stale list across restarts. ✓

## Issues

### 🟡 Behavioral change for completed timeline rows — not acknowledged

Today, when the active step transitions, the **previously active** step is rewritten via `step.copyWith(duration: 0)` (line 151). The inactive branch of `_TimelineItem` displays `'${step.duration ?? 0}'` (`BreathTimelineWidget.dart:227`). Net effect today:

- Upcoming steps render their original duration (e.g. `4`).
- Completed steps render `0`.
- Active step renders the live countdown via `remainingTicksListenable`.

After the plan, `state.timelineSteps` is reused verbatim for the whole session, so completed steps will render their **original** duration (`4`) instead of `0`. The timeline auto-scrolls the active row to `viewportHeight / 3` (`BreathSessionScreen._scrollToActive`), which means roughly the top third of the visible list is filled with completed rows under the fade — they remain visible.

This is a real, user-visible change. It is consistent with note 11's strategy ("keep the list stable, mutate only the active step's duration via the dedicated channel"), so it may be intentional — but the plan should either:
1. Call it out explicitly as an accepted side-effect, **or**
2. Add a tiny step to preserve the "completed → 0" affordance without per-tick reallocation. The cheapest option: in `_TimelineItem`, check `index < activeIndex` (or pass an `isCompleted` flag derived from `activeStepId` position once per state update) and render `0` in the completed case. This avoids any list mutation while preserving the current UX.

Either decision is fine; silently changing the completed-row display is not.

### 🟢 Minor: line-range hint is one off

The plan says "delete … (current lines 140–154)". Line 154 in the current file is a blank line; the `}` of the `if` block ends on line 154 with closing brace, while the structural span you actually delete is **140–154** (inclusive of the closing brace) — which matches. No action needed, just noting that line 144 (`List<TimelineStep> updatedSteps = state.timelineSteps;`) and line 154 (closing `}`) sit inside the range, so the "Delete the local variables … and the entire if block" instruction does in fact remove the `updatedSteps` declaration too. Good.

### 🟢 Performance note (informational, not a blocker)

Note 11 is explicit that the larger win — preventing screen-wide rebuilds on every tick — requires filtering the Riverpod publication (skip `super.state =` when only `remainingTicks` / `timelineSteps` changed) and/or `ref.watch(provider.select(...))` in `BreathSessionScreen` (`build` still reads `final state = ref.watch(breathViewModelProvider);` without `select`, line 162).

This plan **only** removes the per-tick `.map().toList()` allocation. That is a real win (it stops O(N) garbage per tick), but `_onEngineState` still calls `state = BreathSessionState(...)` every tick, so the screen will still rebuild at 1 Hz until the publication filter or `select` lands. The plan's claim "After the change, `_onEngineState` performs zero list allocations per tick" is accurate; the broader screen-rebuild fix is just a separate milestone that should follow.

## Positive notes

- Scope is tight and well-bounded — one method, one file.
- Correctly preserves the full-constructor pattern that `_onEngineState` already uses (because `copyWith` can't clear nullable fields like `resetReason`, `currentExerciseShape`, `nextExerciseShape`).
- Correctly identifies that `TimelineStep` is still referenced by `_buildTimelineSteps` and instructs to keep the import.
- The notifier publication (`_remainingTicks.value = engineState.remainingTicks`) is preserved verbatim in value, so the active-row countdown remains correct.
- Cleanly chains off the previously landed `remainingTicksNotifier` channel; no ordering risk.

## Verdict

The plan is technically correct but ships a quiet UX change (completed rows showing original duration instead of `0`). Add one sentence to the plan that either accepts this as desired, or adds a small UI-side fallback so completed rows still render `0`. Once that is decided, the plan is ready to implement.
