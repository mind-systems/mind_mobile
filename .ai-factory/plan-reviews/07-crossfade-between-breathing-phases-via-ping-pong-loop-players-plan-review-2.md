# Plan Review v2: Crossfade between breathing phases via ping-pong loop players

**Plan file:** `.ai-factory/plans/07-crossfade-between-breathing-phases-via-ping-pong-loop-players.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md**: PASS — change is localized to one coordinator inside the `breath_module` package. No boundary crossing, no DTO/domain leakage, no new dependencies, no App.dart wiring touched.
- **RULES.md**: PASS — `BreathSoundCoordinator` is internal to the package (not a Module Service). Its `initialize`/`reset`/`dispose` lifecycle stays inside the package; stateless-service rule does not apply. No constructor-injection violations.
- **ROADMAP.md**: PASS — Phase 12 entry "Crossfade between breathing phases via ping-pong loop players" matches the plan's approach (A/B players, swap refs, `_fadePlayer`, step-5 active-only). Plan v2 even narrows the roadmap's looser wording ("`_loadFuture` can remain a single future assigned from `_loopPlayerA.setAudioSources(...)`; `_loopPlayerB.setAudioSources(...)` is fired unawaited") to a stricter `Future.wait` over both — better than the roadmap requires.

## Review of v1 follow-ups

All four blocking / should-fix items from `plan-review-1.md` are addressed:

| v1 issue | v2 resolution | Verdict |
|---|---|---|
| #1 `_loadFuture` only awaits A | Task 2 uses `Future.wait<void>([A.setAudioSources, B.setAudioSources]).then((_) {})` — covers both, preserves `Future<void>?` field type | Fixed |
| #2 Inactive's leaked fade tick clobbers volume baseline | Task 3 introduces `_cancelFadeFor(player)`; Task 4 calls it on `inactive` before `setVolume(0.0)` | Fixed |
| #4 `_loadFuture` type drift | Inline `.then((_) {})` keeps the field as `Future<void>?` (Task 2) | Fixed |
| #5 `_currentPhase` ambiguity post-swap | Context section now states `_currentPhase` tracks the active player (the fading-in one) and is set in `_onStateChanged` before `_switchToPhase` | Fixed |

Issues #3 (stop outgoing after fade-to-0) and #6 (reset-during-crossfade) are explicitly noted in "Out of scope" with sound reasoning. Acceptable.

## Critical Issues

None.

## Minor Issues / Observations

### 1. "Crossfade" is actually sequential fade due to step-5 (INFO)

Step-5 in `_onStateChanged` fires at `remainingTicks == 1` and fades the active player to 0 over `currentIntervalMs` — typically ~1 s — completing roughly at the phase boundary. The Task 4 crossfade then dispatches `_fadePlayer(active, 0.0, 2s)` (a no-op since `active` is already ~0) and `_fadePlayer(inactive, 1.0, 2s)`.

Net effect: outgoing audio fades over the last ~1 s of phase N; incoming audio fades over the first ~2 s of phase N+1. There is no overlapping "both phases audible" window — the transition is sequential, not truly cross-faded. This still eliminates the silence gap (the deliverable in the roadmap entry), so functionally correct, but the title "crossfade" oversells the perceptual outcome. Not a blocker; just calibrate expectations.

If true overlap is desired later, step-5 has to be removed (or capped to a much smaller tail) and the 2-s fade-down delegated entirely to `_switchToPhase`. Worth noting in the implementation commit message, not in the plan.

### 2. First `_switchToPhase` plays on `_loopPlayerB`, not A (INFO)

Task 2 initializes `_activeLoop = _loopPlayerA`, but Task 4 has `_switchToPhase` operate on `inactive` (= B) for `seek`+`play`, then swaps. So on a cold start, the very first audible phase is produced by B; A never plays its first phase. This is fine — A and B are interchangeable preloaded clones — but the initial pairing assignment in Task 2 is cosmetic, not semantic. A reader might wonder why A is named "active" if B is what plays first. Could be clarified with one line in Task 2, but not required.

### 3. `_cancelFadeFor` identity dispatch when player is neither A nor B (INFO)

Plan says: "if `player == _loopPlayerA`, cancel `_fadeTimerA` and set it to null; otherwise cancel `_fadeTimerB`". If called with anything that isn't A (e.g., a stale reference post-dispose where `_loopPlayerA` is now `null`), it falls through to the B branch. Realistically this never fires because `_cancelFadeFor` is only invoked from `_fadePlayer` and `_switchToPhase` with locals captured live, and dispose cancels both timers up-front. Still, a defensive `else if (player == _loopPlayerB)` would be slightly safer than an `else` catch-all. Optional.

### 4. `_loadFuture` not nulled in `reset()` — still correct, worth pinning (INFO)

`reset()` does not null `_loadFuture`. Since the players themselves remain non-null after `reset()` (only `dispose()` nulls them) and `setAudioSources` is not called again, the already-resolved Future stays usable for the post-reset re-entry into `_switchToPhase`. Plan is correct to leave this alone — just noting that an implementer who "tidies up" by nulling `_loadFuture` in `reset()` would introduce a regression (the cold-start guard would skip the await). The plan should ideally say "leave `_loadFuture` as-is in `reset()`" to forestall that mistake.

## Positive Notes

- All v1 review issues are addressed inline with traceable references ("must-fix from review issue #1", "must-address from review issue #2") — easy to verify each correction.
- Adding `_cancelFadeFor(player)` as a named helper (rather than inlining the identity check inside `_fadePlayer` and `_switchToPhase`) is the right factoring; it makes the contract "cancel this player's slot, nothing else" explicit.
- The `Future.wait<void>([...]).then((_) {})` form is exactly the right way to preserve `Future<void>?` without widening to `Future<List<void>>?`. Plan calls this out explicitly.
- The plan re-asserts the generation guard and `_currentStatus` re-check between awaits in Task 4 — preserves the reset-during-switch and rapid-switch safety from roadmap item 12.7.
- "Out of scope" section is honest and bounded — pause-after-fade-to-0 optimization is correctly identified as non-functional, and the reasoning (decoder CPU on silenced player is harmless) is sound.
- Commit segmentation (wiring → switch logic → lifecycle) is buildable at each step.

## Verdict

The plan is implementable as-is. Both blocking issues from v1 are resolved, the should-fix is resolved, and the remaining observations are non-blocking nuance. Ready to ship.

PLAN_REVIEW_PASS
