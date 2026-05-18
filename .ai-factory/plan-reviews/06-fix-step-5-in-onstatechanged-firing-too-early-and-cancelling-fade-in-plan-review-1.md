# Plan Review: Fix step-5 in `_onStateChanged` firing too early and cancelling fade-in

## Plan Review Summary

**Plan File:** `.ai-factory/plans/06-fix-step-5-in-onstatechanged-firing-too-early-and-cancelling-fade-in.md`
**Target File:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** PASS — change is confined to a single coordinator inside `packages/breath_module/`, respects module boundaries, does not touch domain layer, App.dart, or any cross-module wiring.
- **RULES.md:** PASS — none of the listed rules apply (no Service/StreamController/App.dart changes; no constructor wiring changes).
- **ROADMAP.md:** PASS — the plan is a verbatim implementation of the existing roadmap entry: "Fix step-5 in `_onStateChanged` firing too early and cancelling fade-in — … Fix: trigger step-5 only at `remainingTicks == 1`; duration simplifies to `currentIntervalMs`". Roadmap alignment is exact.

### Verification Against Source

Read `BreathSoundCoordinator.dart` to verify the plan's assumptions:

- **Line range (138–145).** Plan says "currently lines ~139–145"; actual is 138–145. Acceptable.
- **Current condition** at lines 141–142 is `state.remainingTicks > 0 && state.remainingTicks <= 3` ✓ matches plan.
- **Current duration** at line 144 is `Duration(milliseconds: state.remainingTicks * intervalMs)` ✓ matches plan.
- **Fallback expression** at line 143 (`state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000`) ✓ matches plan and is correctly preserved.
- **Untouched siblings** — `_switchToPhase` (lines 165–187) starts a 2 s fade-in at line 186 (`_fadeTo(1.0, const Duration(seconds: 2))`). The plan's narrative — "the 2 s fade-in started by `_switchToPhase` runs uninterrupted earlier in the phase" — is consistent with this.
- **Status/phase guards** (`_currentStatus == BreathSessionStatus.breath`, `_phaseAssets.containsKey(state.phase)`) at lines 139–140 are correctly identified as conditions to preserve.

### Critical Issues

None.

### Minor Observations (Non-Blocking)

1. **"Logging: minimal" but no log statements added.** Settings declare minimal logging; the task makes no logging changes. Reading "minimal" as "nothing additional needed for a 2-line tweak" is reasonable here, but worth noting that the plan does not explicitly say so. Not blocking.

2. **Re-fire on duplicate `remainingTicks == 1` state events.** `_onStateChanged` listens to every state emission; if the view-model emits two states with `remainingTicks == 1` within the same tick (e.g., due to a non-tick field change), `_fadeTo` will cancel and restart the 1-tick fade-out. `_fadeTo` already cancels the previous timer (line 190), so behaviorally this just resets the fade — minor audible glitch in pathological cases. Same risk class as the original code (the existing condition could fire 3 times); the fix does not make this worse. No action recommended.

3. **Short phases edge case.** For a phase with only 1 tick total, `_switchToPhase` is awaited via `_loadFuture`, so its `_fadeTo(1.0, 2s)` may be issued *after* the `remainingTicks == 1` fade-out at line 144, restoring volume to 1.0 just as the phase ends. This pre-existed in the current code and is not in scope for this fix. Plan correctly leaves `_switchToPhase` untouched.

### Positive Notes

- Plan is minimal, surgical, and the diff will be ~2 lines — exactly what a targeted bug fix should look like.
- Plan explicitly enumerates *what not to touch* (`_switchToPhase`, `_onTick`, `initialize`, `reset`, `dispose`), preventing scope creep.
- The diagnosis in the Context section (fade-in cancelled ~1 s into a 4-tick phase by a fade-out scheduled at `remainingTicks <= 3`) matches the actual control flow in the source file.
- Roadmap and plan agree on both the condition (`== 1`) and the simplified duration.
- File path is correct and exists at the stated location.

PLAN_REVIEW_PASS
