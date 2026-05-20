# Code Review: Wire active `_TimelineItem` countdown to `remainingTicksNotifier`

**Plan:** `.ai-factory/plans/27-wire-active-timelineitem-countdown-to-remainingticksnotifier.md`
**Files changed:**
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
- `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`

## Verification

- `BreathTimelineWidget` is referenced from a single production call site (`BreathSessionScreen.dart:215`). Making the new param `required` is safe — `grep -rn 'BreathTimelineWidget('` confirms no other instantiations exist (tests or otherwise).
- `remainingTicksNotifier` is exposed on `BreathViewModel` (`BreathSessionViewModel.dart:43`), backed by `_remainingTicks` (line 36), updated in `_setupEngine` (line 116) and `_onEngineState` (line 156) before the Riverpod publication, and disposed in `ref.onDispose` (line 72). Reference is stable for provider lifetime, so `ref.read(...)` (not `watch`) is correct.
- `ValueListenable` is available via `package:flutter/foundation.dart` (newly imported). It is also re-exported by `package:flutter/material.dart`, so the explicit `foundation.dart` import is technically redundant but harmless — no functional issue.
- Widget wiring: `_buildList` passes the listenable only when `isActive == true`, so non-active rows never subscribe. `_TimelineItem.build` further guards with `isActive && remainingTicksListenable != null` — defensive double-check, fine.
- `ValueListenableBuilder<int>` is correct usage; the `Text` rebuild scope is limited to the builder subtree as intended.

## Findings

### Minor

1. **Redundant `flutter/foundation.dart` import.** `BreathTimelineWidget.dart:1` imports `package:flutter/foundation.dart`, but the file also imports `package:flutter/material.dart` (line 2), which re-exports `ValueListenable` and `ValueListenableBuilder`. The import is harmless and matches the plan, so no change is required, but it can be removed for tidiness.

2. **Active-step transition visual contract (informational, no defect).** When `activeStepId` flips from A → B, the previously-active step A is mutated in `timelineSteps` to `duration: 0` by `BreathViewModel._onEngineState` (line 151). After the next screen rebuild, A renders `Text('${step.duration ?? 0}')` → "0" via the `else` branch, and B renders the listenable subscription with the new remaining value. This matches the prior visual behavior — confirmed correct.

3. **Goal vs. milestone scope (informational).** The plan's `## Context` says only the active row's `Text` rebuilds at 1 Hz "instead of the whole screen subtree." That outcome lands only after the two follow-up milestones (stop reallocating `timelineSteps` in `_onEngineState`, and filter Riverpod publication of tick-only updates). After this patch, the screen still rebuilds per tick (because `ref.watch(breathViewModelProvider)` watches the whole state without `select`), so the active row's `_TimelineItem` is still re-instantiated on every tick — the `ValueListenableBuilder` does its job, but the parent `_TimelineItem`'s `build` also runs. This is the structural prerequisite for the upcoming gains, not the gain itself. No code change needed; just calibrating expectations against the ROADMAP sequencing.

## Correctness / Runtime Risks

- No null-safety issues: `remainingTicksListenable!` is dereferenced only after the `!= null` guard.
- No type mismatches: `ValueListenable<int>` flows end-to-end (`BreathViewModel` getter → `BreathTimelineWidget` field → `_TimelineItem` field → `ValueListenableBuilder<int>`).
- No race conditions: `_remainingTicks` is mutated synchronously inside the engine state callback before any rebuild publication.
- No new dependencies, no DI changes, no proto changes, no migrations.
- No breakage in `getItemScrollOffsetById` / `getItemOffsetById` — those scan `widget.steps` and use `GlobalKey`s, both unaffected.
- Hot reload safe: adding a `required` field is a compile-time error if missed, but the sole call site is updated atomically in the same patch.

REVIEW_PASS
