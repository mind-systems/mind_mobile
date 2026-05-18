# Code Review: Fix step-5 in `_onStateChanged` firing too early and cancelling fade-in

**Plan:** `.ai-factory/plans/06-fix-step-5-in-onstatechanged-firing-too-early-and-cancelling-fade-in.md`
**Reviewed file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Diff size:** 4 lines changed in one function (`_onStateChanged`, step 5).

## Scope of changes (from `git status` / `git diff HEAD`)

- New: `.ai-factory/plan-reviews/06-…-plan-review-1.md` (artifact, not code)
- New: `.ai-factory/plans/06-…-fade-in.md` (artifact, not code)
- Modified: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart` (the actual code change)

The code change is exactly the surgical edit described in the plan:

```diff
-        state.remainingTicks > 0 &&
-        state.remainingTicks <= 3) {
+        state.remainingTicks == 1) {
       final intervalMs = state.currentIntervalMs > 0 ? state.currentIntervalMs : 1000;
-      _fadeTo(0.0, Duration(milliseconds: state.remainingTicks * intervalMs));
+      _fadeTo(0.0, Duration(milliseconds: intervalMs));
```

## Correctness analysis

Read the file in full (lines 1–207). The relevant flow is:

1. `_switchToPhase` (line 165) sets volume to 0, seeks the playlist to the new index, calls `play()`, and starts a 2 s fade-in (`_fadeTo(1.0, const Duration(seconds: 2))` at line 186).
2. Subsequent `_onStateChanged` calls during the phase carry `remainingTicks` decrementing toward 0.
3. Previously, step 5 fired at `remainingTicks ∈ {3, 2, 1}` and cancelled the 2 s fade-in roughly 1 s after the phase started — confirmed bug.
4. With `remainingTicks == 1`, step 5 fires exactly once per phase, at the last tick, and the duration `intervalMs` matches the time remaining in the phase (since each tick is `intervalMs` long and one tick remains). The math `1 * intervalMs == intervalMs` is preserved.

The earlier guards on the same `if` (`_currentStatus == BreathSessionStatus.breath` and `_phaseAssets.containsKey(state.phase)`) are intact and still required:
- They prevent step 5 from firing during `pause`/`rest`/`complete` or during the rest phase, where no loop sound is playing.

No other branches of `_onStateChanged` (status change, phase change, tick-source change, load gate) are touched. `_switchToPhase`, `_onTick`, `_fadeTo`, `initialize`, `reset`, and `dispose` are unchanged.

## Runtime risk checks

- **Type safety:** `remainingTicks` is an `int`; `==` comparison is sound. `Duration(milliseconds: intervalMs)` receives an `int` — fine.
- **Negative / zero remainingTicks:** Old code guarded `remainingTicks > 0`; new code uses `== 1`, which implicitly excludes 0 and negative values. Equivalent or stricter than before. Safe.
- **Race with `_switchToPhase`:** `_switchToPhase` is async and awaits `_loadFuture` before calling `_fadeTo(1.0, 2s)`. If a state with `remainingTicks == 1` arrives before `_switchToPhase` completes (only possible on extremely short first phases or slow cold starts), the order will be: step-5 schedules a fade-out from current volume (0.0) → fade-in from `_switchToPhase` then overrides it. This pre-existed; the new condition narrows the window, not widens it.
- **Multiple emissions with `remainingTicks == 1`:** If the view-model emits more than one state event with `remainingTicks == 1` (e.g., a non-tick field changes mid-tick), `_fadeTo` will cancel its prior timer and restart from the current volume. Functionally idempotent; minor audible glitch only if a phase emits many such events. Same risk class as before — not worsened.
- **Concurrency / disposal:** No new timers, subscriptions, or players introduced. `_fadeTimer` lifecycle and `dispose()` are unaffected.
- **Migrations / persistence / network:** Not applicable — no schema, no API, no proto.
- **Module/architecture boundaries (CLAUDE.md, ARCHITECTURE.md, RULES.md):** Change is contained inside `packages/breath_module/` and touches only the audio coordinator. No domain types crossed the module boundary; no Service/Notifier/App.dart changes; no constructor wiring changes.

## Alignment with plan and roadmap

- ROADMAP entry (line 11): "trigger step-5 only at `remainingTicks == 1`; duration simplifies to `currentIntervalMs` (no multiplication needed)." — implemented verbatim.
- Plan: Task 1 enumerates the exact two edits; both present, nothing extra. Settings (no tests, no docs, minimal logging) respected; no superfluous additions.

## Findings

None.

REVIEW_PASS
