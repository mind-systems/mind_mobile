# Plan Review: Wire active `_TimelineItem` countdown to `remainingTicksNotifier`

**Plan file:** `.ai-factory/plans/27-wire-active-timelineitem-countdown-to-remainingticksnotifier.md`
**Risk Level:** 🟢 Low

## Context verification

- ✅ `remainingTicksNotifier` exists on `BreathViewModel` (`BreathSessionViewModel.dart:43`) as `ValueListenable<int> get remainingTicksNotifier => _remainingTicks;`. Plan #26 is fully implemented ([x] all tasks).
- ✅ `_remainingTicks` is updated in `_setupEngine` (line 116) and `_onEngineState` (line 156), both before the Riverpod `state =` publication, so the value is always available when the screen rebuilds with a new `activeStepId`.
- ✅ `BreathTimelineWidget` is referenced from a single production call site — `BreathSessionScreen.dart:215`. No tests instantiate it. Making the new param `required` is safe.
- ✅ `_TimelineItem` is a private `StatelessWidget` inside the same file; adding a nullable `ValueListenable<int>?` is contained.
- ✅ `ref.read(breathViewModelProvider.notifier)` returns the same `BreathViewModel` instance for the screen's lifetime (Riverpod `NotifierProvider`), and the `_remainingTicks` field is created once in the constructor area and only disposed via `ref.onDispose`. So `ref.read` (not `watch`) is the correct call style — the `ValueListenable` reference is stable.

## Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Not consulted directly here, but the plan respects the package boundary — the change is entirely inside `packages/breath_module/`, no domain types cross the boundary, and no new dependencies are added. WARN: not explicitly cross-checked.
- **Rules (`.ai-factory/RULES.md`):** No project rules file referenced; no obvious violation.
- **Roadmap (`.ai-factory/ROADMAP.md`):** The ROADMAP references the rebuild-scope work; this plan implements step 1 of the note-11 treatment sequence.

## Critical Issues

None. The plan is implementable as written and the targeted file paths, line ranges, and API references all line up with the codebase.

## Suggestions / Minor Observations

1. **Goal phrasing is slightly aspirational for this milestone.** The plan's Context says "only the active `_TimelineItem`'s duration `Text` rebuilds at 1 Hz instead of the whole screen subtree." That outcome requires steps 2 and 3 from `notes/11` (Riverpod `select`, and `_onEngineState` not reallocating `timelineSteps`). Today `BreathSessionScreen.build` still does `ref.watch(breathViewModelProvider)` without `select`, and `_onEngineState` rebuilds `timelineSteps` per tick — so after this plan lands the active row's `Text` will still be re-created by the screen's per-tick rebuild. The wiring introduced here is a structural prerequisite that becomes the *sole* trigger only after the follow-up steps. Not a defect — worth restating as "wire the channel; full benefit lands when `_onEngineState` stops mutating `timelineSteps` and the screen switches to `select`."

2. **`flutter/foundation.dart` import is unnecessary.** `ValueListenable` and `ValueListenableBuilder` are already re-exported through `package:flutter/material.dart`, which `BreathTimelineWidget.dart` already imports. Adding `foundation.dart` is harmless but redundant. Either drop the explicit import note in Task 1, or note it as optional.

3. **Active-step transition consistency (no action required, just confirm).** When `activeStepId` flips from A → B:
   - `_remainingTicks.value` is set to the new remaining for B before `state` is published (line 156 → 159).
   - The previous active step A is mutated to `duration: 0` in `timelineSteps` (line 151).
   - After the rebuild, A becomes inactive and renders `Text('${step.duration ?? 0}')` → "0".
   - B becomes active and renders `ValueListenableBuilder` → current `_remainingTicks.value`.

   This is the same visual contract as today. The plan preserves it correctly. Worth noting in the task description so future readers know the previous-active "0" flash is intentional and pre-existing.

4. **Conditional rendering wording could be tighter.** Task 2 says "when `isActive && remainingTicksListenable != null`". Since Task 1 guarantees the listenable is only passed when `isActive == true`, the `isActive` check inside `_TimelineItem` is structurally redundant — `remainingTicksListenable != null` is already a proxy for "this item is active." Leaving both checks is defensive and fine. Optional simplification.

5. **`step.duration` for the active step under the new path.** With the listenable wired, the active row never reads `step.duration` anymore. That means the per-tick mutation `step.copyWith(duration: remaining)` at `BreathSessionViewModel.dart:150` becomes dead work *for the active row's display* once this lands (it's still used as the "0" value for the previously-active row via line 151). This is consistent with note-11 step 3 (stop reallocating `timelineSteps`), which is intentionally out of scope here.

## Positive Notes

- Tight, well-scoped patch — three tasks, two files, clear dependency chain.
- Correctly threads the listenable only to the *active* row at the widget API layer (`BreathTimelineWidget._buildList`), avoiding the trap of every `_TimelineItem` subscribing to the same notifier.
- Correct use of `ref.read` vs `ref.watch` for the stable notifier handle.
- No proto changes, no migrations, no DI/wiring changes — the existing `breathViewModelProvider` override flow is untouched.
- Documentation pointer to `.ai-factory/notes/11-breath-session-tick-render-scope.md` preserves the architectural rationale.
- Preserves existing `textStyle`, `Row`/`AnimatedScale`/`AnimatedOpacity` structure, so layout and animation behavior are unaffected.

PLAN_REVIEW_PASS
