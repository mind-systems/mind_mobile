# Breath dot motion engine — phase velocity & continuous flow fix

**Date:** 2026-06-20
**Source:** conversation context

## Key Findings

- The breathing dot mistimed and stalled on **uneven phase durations** (e.g. inhale 2s / exhale 1s): the shorter phase covered only a quarter of its arc, then snapped from ~75% straight to the target, and the dot hard-stopped at the bottom of every cycle.
- These were **four latent bugs that surfaced together**, not new regressions. The motion engine had been tuned over time for the *common case* — symmetric, multi-tick phases on a 1s clock tick. Asymmetric phases broke four baked-in assumptions at once.
- Root cause is a single blind spot: the engine was a **velocity feedback controller bolted onto a tick-discrete state machine**, never designed to be continuous or scale-invariant. We made it both.
- Fix lives entirely in two files: `BreathAnimationCoordinator.dart` and `BreathMotionEngine.dart` (`packages/breath_module/lib/src/BreathSession/Animation/`). No proto, no API, no state-machine change.
- Verified with temporary `[MOTION]`/`[ANIMCOORD]` instrumentation streamed to the local Loki backend (`project=mind`, `service=mind_mobile`), since removed. Logs proved phase delivery is exactly on the tick schedule; the residual phase-boundary hitch is render-side jank, not the engine.

## Details

### How the motion engine works (context)

The dot travels a closed contour once per breath cycle: `_position` runs `0.0 → 1.0`. Phase boundaries sit at equal perimeter fractions — `_phaseTargetPosition = (currentPhaseIndex + 1) / totalPhases` — so each step (inhale/hold/exhale) owns `1/N` of the circle **regardless of its duration**. The state machine emits ticks (1s clock, or per-RR-interval for heart-rate sources); each tick advances the phase. `BreathAnimationCoordinator` translates state into engine calls (`setPhaseInfo`, `setRemainingPhaseTicks`, `setActive`, `resetPosition`). `BreathMotionEngine` is a per-frame Ticker that drives `_position` via a velocity controller.

### Bug 1 — `setRemainingPhaseTicks` skipped on a phase boundary (the original symptom)

`BreathAnimationCoordinator._onStateChanged` block 3 re-armed phase duration **only when `remainingTicks` changed** — a guard meant to avoid redundant re-computation. Hidden assumption: *a phase change always coincides with a remaining-tick change.* It breaks when two adjacent phases share the same boundary tick count: inhale's last tick emits `remaining=1`, and a 1-tick exhale starts with `remaining=1` — so `1 == prev` and the call was skipped. The engine kept the inhale's `_targetDurationMs`/velocity and stayed linear-locked; the exhale never accelerated, the dot covered a quarter instead of half, then `newCycle` snapped it to the target.

**Fix:** track `_previousPhaseIndex` and re-arm on `remainingTicks != prev || currentPhaseIndex != prev`. Kept in sync in `_syncInitialState`, `_handleReset`, the activity branch, and `reset()`.

Why it never showed before: symmetric phases (e.g. 4s/4s) never collide on the boundary tick count.

### Bug 2 — fixed-millisecond ramp (not scale-invariant)

The velocity ramp used a constant `_dampingFactor` (~67ms time constant) — a fixed **wall-clock** ramp. Assumption: *all phases are roughly equal length*, so a fixed ramp looks proportional. It doesn't: ~20% of a 1s phase but ~1% of a 20s phase (visible jump on long phases).

**Fix:** `_rampTimeConstantFraction = 0.1`; compute `damping = 1 / (fraction * _targetDurationMs)` per frame. The ramp now occupies the same *share* of the phase whether it is 1s or 20s.

### Bug 3 — linear-lock froze an overshot velocity

`_isLinearLocked` froze the velocity once it converged to the target, then disabled further recomputation. It was almost certainly a patch against end-of-phase jitter (`remainingDist/remainingTime` blows up as `remainingTime → 0`). But it latched **during the ramp transient**, capturing an overshot catch-up velocity (e.g. 0.53/s vs nominal 0.49/s) and never correcting — so the dot arrived early and waited. Assumption: *by the time velocity converges, the dot is on the steady-state trajectory.* False while still ramping.

**Fix:** removed the lock. The controller now recomputes `remainingDist / remainingTime` every frame (a self-correcting P-controller), guarded by `_minRemainingTimeMs = 16` so the final frames coast instead of dividing by ~zero. An overshoot now eases back down; the dot arrives on time without rushing.

### Bug 4 — hard stop at the bottom of every cycle

Velocity was zeroed in two places: the `_position >= 1.0` clamp, and `resetPosition` on every reset. So at the cycle bottom the dot went `0.5/s → 0` in one frame, froze, then the next inhale started from zero. Assumption: *each cycle is an independent restart.* That treats a continuous loop as discrete restarts and creates a velocity discontinuity at the seam. The equal-perimeter geometry makes it worse — different-duration phases run at different speeds, so the seam velocity gap is large.

**Fix:** removed the 1.0 clamp; `normalizedPosition => _position % 1.0` wraps for rendering (1.0 and 0.0 are the same point on the closed contour), so the dot flows across the bottom. Added `resetPosition(newPosition, preserveVelocity)` and pass `preserveVelocity: true` for `newCycle`/`exerciseChange` so motion carries into the next iteration. Velocity reaches zero only when the exercise completes — `complete` stops the ticker, which is the real "drop to zero". `start`/`rest` still reset velocity (the dot begins each fresh start from rest).

### How we got here (debugging path)

1. Hypothesised the dedup-guard from a static read of the coordinator; confirmed with Loki logs showing `setRemainingPhaseTicks SKIPPED` exactly at inhale→exhale.
2. After the re-arm fix, logs showed the exhale velocity locking at 0.53/s and arriving early → identified the lock + fixed damping.
3. Lowered damping, then made it scale-invariant after the user flagged the 20s/1s genericity concern.
4. Removed the lock for continuous self-correction.
5. User reframed the symptom as "how long the dot stands still before the next phase" — added a phase-interval probe. Logs proved delivery is exactly on schedule (1000ms / 2000ms, symmetric), so the stall was the engine's hard stop, not delivery lag → velocity continuity through the bottom.
6. Final logs showed the dot never reaches zero velocity mid-session; the remaining equal hitch at both boundaries is render-side jank (heavy frame on the structural Riverpod publish + shape morph), consistent with `docs/breath/session/stutter-investigation.md`. Accepted as out of scope for the engine.

### The underlying lesson

Not four independent bugs — one blind spot. The engine accreted patches (rebuild optimisation in Phase 15/16, the stutter investigation, the offset axis in Phase 42), each adding an assumption fit to its moment: equal-perimeter geometry, discrete ticks, absolute-time damping, per-cycle position/velocity reset. They held while input was "manual" (symmetric phases). Asymmetric phases passed through all four cracks at once. The fix reshapes the engine to be **continuous** (velocity carries across phase and cycle seams, only the exercise end stops it) and **scale-invariant** (ramp proportional to phase length).

## Open Questions

- The exhale→inhale seam carries the faster exhale velocity (~0.5/s) into the slower inhale (~0.25/s), so the dot enters the bottom fast and decelerates ("zoom-and-brake"). Currently acceptable; if it ever reads as uneven, cap the carried velocity at the next phase's nominal.
- The residual phase-boundary hitch is render-side (publish + morph repaint). A future pass could profile it (`RepaintBoundary` on the shape, morph cost, `Consumer.select` scope) — separate from the motion engine.
