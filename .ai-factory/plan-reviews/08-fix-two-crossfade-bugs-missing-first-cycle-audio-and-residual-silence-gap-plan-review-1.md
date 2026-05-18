# Plan Review: 08-fix-two-crossfade-bugs

**Plan reviewed:** `.ai-factory/plans/08-fix-two-crossfade-bugs-missing-first-cycle-audio-and-residual-silence-gap.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — WARN: not re-inspected; change is internal to a presentation package coordinator with no cross-module surface, so no boundary impact.
- **Rules (`.ai-factory/RULES.md`)** — PASS: rules concern module Service statelessness and App.dart purity; `BreathSoundCoordinator` is a presentation-side coordinator and is unaffected.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — PASS: plan aligns with the open milestone "Fix two crossfade bugs: missing first-cycle audio and residual silence gap" (Phase 12 — Breath Sound, line 15).

## Critical Issues

None. No missing migrations, no security implications, no incorrect file paths or API usage.

## Important Findings

### 1. Bug 1 (Task 1) appears to be ALREADY fixed in the current file — plan Context is stale
The plan's Context says: *"only player A's `setAudioSources` future is tracked"*. But the current `initialize()` at lines 58–61 of `BreathSoundCoordinator.dart` already uses:

```dart
_loadFuture = Future.wait<void>([
  _loopPlayerA!.setAudioSources(sources, preload: true),
  _loopPlayerB!.setAudioSources(sources, preload: true),
]).then((_) {});
```

This is exactly the snippet the plan instructs to write. The plan does anticipate this ("If the code already has this shape, leave it; no other change is required for Bug 1.") — so Task 1 is effectively a no-op audit, not a behavior change.

**Impact:** Cosmetic/expectations. The implementer should be told Phase 1 is verification, not new work. Otherwise they may waste cycles searching for an out-of-date code state. Consider re-labeling Task 1 to "Verify `_loadFuture` already wraps both players" and dropping the "do NOT leave …" instruction, which describes a non-existent state.

### 2. Behavior change to crossfade duration is intentional but worth flagging
The current `_switchToPhase` uses `const duration = Duration(seconds: 2)` for both fade-in (line 216) and fade-out (line 217). Task 3 replaces this with the caller-supplied `fadeDuration`, which Task 4 derives from `state.currentIntervalMs` (the **tick** interval — confirmed at `BreathSessionStateMachine.dart` lines 276/313/341/371 where `intervalMs` is the per-tick callback interval, e.g. ~1000ms for clock).

So the perceptual change is: phase crossfade goes from a fixed 2 s to ~1 tick (~1 s under clock source, variable under heartbeat). The plan correctly preserves this semantic (matches deleted step-5's `currentIntervalMs > 0 ? ... : 1000` fallback), and the milestone in ROADMAP.md line 15 explicitly states the desired fix is "fire both fades concurrently … with `fadeDuration` derived from `state.currentIntervalMs`". No bug — but the implementer should not be surprised that the 2-second const is intentionally going away.

## Minor Notes

- **Guards retained correctly.** Task 3 keeps the `_switchGen` and `_currentStatus != BreathSessionStatus.breath` checks immediately before the concurrent fades, matching the existing post-`play()` guard at lines 213–214. Good — this preserves the cancel-on-reset/pause semantics validated in code review #07.
- **`unawaited` import.** Call sites already use `unawaited(_switchToPhase(...))` and `dart:async` is already imported (line 1). No new import needed.
- **`_fadePlayer` cancels prior fades per-player.** `_cancelFadeFor(player)` at the top of `_fadePlayer` (line 231) clears the timer for that specific player, so the two concurrent fades on different players do not interfere. Plan does not need to address this explicitly — already safe.
- **No external callers of `_switchToPhase`.** `Grep` over `packages/` confirms only the two call sites at lines 142 and 157 plus the definition at line 190. Since the method is private (`_`-prefixed) and Dart privacy is library-scoped, no test double or other file can reference it. Task 5's "no other call sites or tests reference the old signature" check will pass trivially.
- **Step-3 still has `state.phase != _currentPhase` guard.** With step-5 deleted, the only way the new active sound starts is via `_switchToPhase`. The else branch at line 144 (`_fadePlayer(_activeLoop!, 1.0, 200ms)`) still fires when status flips to `breath` and `phase` is already `_currentPhase` — that's the correct behavior for resume-from-pause and is untouched by the plan. ✅
- **First-emit safety.** When `_currentPhase` is initially `null` and `state.phase` is e.g. `inhale`, the step-3 branch (status transitioning into `breath`) handles initialization by calling `_switchToPhase(state.phase)`. After the plan's change, the call becomes `_switchToPhase(state.phase, Duration(milliseconds: intervalMs))` — and since `currentIntervalMs` is initialized to `-1` (`BreathSessionState.dart:66`, `BreathSessionStateMachine.dart:126/150`), the `> 0 ? : 1000` fallback correctly substitutes 1000 ms during the very first emit. Plan handles this correctly.

## Positive Notes

- Plan is **minimal and surgical**: 5 tasks, all in one file, with explicit dependency chain.
- **Bug attribution is correct** (modulo Finding 1): the timing analysis of step-5 firing one tick before `_switchToPhase` is accurate — `remainingTicks == 1` fires before the phase boundary, leaving `_activeLoop` at 0 by the time `_switchToPhase` runs.
- **Concurrent fade approach is the right fix**: with both `play()` issued before either fade starts, and both fades launched without `await`, there is genuine overlap between outgoing and incoming sound — no silence window.
- Plan correctly **scopes the change** — explicitly tells the implementer NOT to touch `_fadePlayer(_activeLoop!, 0.0, ...)` calls in the pause/complete/rest branches or in step-4's else branch.
- Task 5's verification checklist is concrete and matches the actual edit surface.

## Recommendation

Apply Tasks 2–5 as written. Re-label Task 1 to make clear it is a verification step (the code already matches the desired shape). The plan is otherwise solid and ready to implement.

PLAN_REVIEW_PASS
