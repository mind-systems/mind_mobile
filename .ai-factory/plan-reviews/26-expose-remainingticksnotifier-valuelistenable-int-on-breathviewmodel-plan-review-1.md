# Plan Review: Expose `remainingTicksNotifier: ValueListenable<int>` on `BreathViewModel`

**Plan file:** `.ai-factory/plans/26-expose-remainingticksnotifier-valuelistenable-int-on-breathviewmodel.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md:** No conflict. The change adds a sibling channel inside the existing module boundary (`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`). The package already depends on `flutter_riverpod` (which transitively re-exports `flutter/foundation`), but the plan's explicit `package:flutter/foundation.dart` import is cleaner and conventional. No domain layer is touched. **PASS.**
- **RULES.md:** No violation. The rules constrain Module Services (statelessness, no `dispose()`) — `BreathViewModel` is a Riverpod `Notifier`, not a Service. Disposing `_remainingTicks` inside the existing `ref.onDispose` block follows the rule that "Riverpod manages the subscription lifecycle via `ref.onDispose` in the ViewModel". **PASS.**
- **ROADMAP.md:** This plan is the first task of Phase 15 — Breath Session Render Performance (`.ai-factory/ROADMAP.md:59`). Plan scope matches the milestone description verbatim (additive only, no consumers, no removal from `BreathSessionState`). **PASS.**
- **Background note:** `.ai-factory/notes/11-breath-session-tick-render-scope.md` confirms the architectural intent and explicitly resolves that `remainingTicks` must remain on `BreathSessionState` (animation coordinators read it from the raw stream). Plan honours this. **PASS.**

## Codebase Verification

Cross-checked the plan against `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`:

- **Imports (Task 1):** Existing imports are `dart:async`, `package:flutter_riverpod/flutter_riverpod.dart`, then relative project imports. Inserting `package:flutter/foundation.dart` between `dart:async` and `flutter_riverpod` is correct and matches Dart conventions.
- **Field declaration site (Task 2):** Private fields cluster at lines 26–35 (`_stateMachine`, subscriptions, `_sessionDTO`, `_stateController`). Placement is unambiguous.
- **`_setupEngine` (Task 3):** Line 104 (`final initialEngineState = _stateMachine!.currentState;`) and line 106 (`state = BreathSessionState(...)`) exist as described. Inserting the assignment between them is exact.
- **`_onEngineState` (Task 3):** Line 130 (`final remaining = engineState.remainingTicks;`) and the publication starting at line 146 exist as described. Pushing `_remainingTicks.value = remaining;` immediately after line 130 is correct and front-runs any future `super.state =` short-circuiting (milestone 4 in the roadmap).
- **`ref.onDispose` block (Task 4):** Lines 56–63 hold the existing teardown. Adding `_remainingTicks.dispose();` after `_stateController.close();` is consistent with the construction-order mirroring described.
- **No consumer impact:** `BreathSessionState.remainingTicks` is preserved; nothing in `BreathAnimationCoordinator`, `OrbAnimationCoordinator`, `BreathSoundCoordinator`, or `BreathModuleStateChannel` is affected (confirmed by the subscriber audit in the linked note).

## Correctness & Safety

- **Initial value 0:** `BreathSessionState.initial()` is returned from `build()` before `initState()` runs. Initializing `_remainingTicks` to `0` matches that pre-engine state. After `_setupEngine`, the value is rewritten from `initialEngineState.remainingTicks`. Consistent.
- **Disposal lifecycle:** `BreathViewModel` is a `Notifier`, so a fresh `ValueNotifier` is created when the provider is (re)built — disposal in `ref.onDispose` will release the correct instance. No risk of cross-build leakage.
- **No early-return concern:** The plan explicitly orders the `_remainingTicks.value = ...` assignment *before* `state = ...`, anticipating the milestone 4 publication filter. Good forward-compatible ordering.
- **Equality short-circuit:** Plan correctly notes `ValueNotifier` skips notification when the new value equals the old one. No manual guard needed.
- **No engine restart bug:** `_setupEngine` is invoked on both initial load and `observeSession` updates. Re-assigning `_remainingTicks.value` in `_setupEngine` keeps the channel correct across session DTO updates without recreating the notifier — listeners stay attached. Correct.

## Minor Observations (non-blocking)

- The plan does not explicitly mention that `flutter_riverpod` transitively re-exports `foundation`. The explicit import is preferable (clearer dependency surface) — the plan's instruction is correct as written.
- Task 4's example dispose ordering (`after _stateController.close()`) is reasonable. `ValueNotifier.dispose()` is order-independent relative to the other teardown calls here, so the suggested placement is fine.
- No tests are added (Settings: `Testing: no`). Given the additive nature and the explicit lack of consumers in this milestone, deferring tests to the consumer-wiring milestone (next roadmap task) is appropriate.

## Critical Issues

None.

## Positive Notes

- Plan correctly preserves `BreathSessionState.remainingTicks`, honoring the subscriber audit conclusion.
- Forward-compatible ordering: `_remainingTicks.value = ...` precedes `state = ...`, so the milestone 4 publication filter won't accidentally starve the new channel.
- File paths, line locations, and surrounding code references all match the actual codebase.
- Scope is tight and additive — zero behavioral change for current consumers, minimum surface area for review of the follow-up tasks.

PLAN_REVIEW_PASS
