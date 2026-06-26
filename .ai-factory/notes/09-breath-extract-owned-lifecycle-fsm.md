# Extract the owned lifecycle FSM, remove _hasStarted (behavior-preserving) (T7)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- After [[05-breath-derive-lifecycle-islive]] (derived `lifecycle`) and the consumers are migrated ([[06-breath-audio-islive]] / [[07-breath-fgs-local-keepalive]] / [[08-breath-channel-explicit-lifecycle]]), the engine's `status`/`_hasStarted` smear is redundant scaffolding. This task makes the lifecycle a **first-class owned sub-machine** so there is one source of truth, not a derivation — Option A, done surgically.
- Pure cleanup: **zero observable change** (the golden master [[04-breath-activity-characterization-golden-master]] + the `isLive` suite [[05]] stay green). The keep-alive fix already shipped on the derived signal, so this carries no feature risk.

## Details

- Introduce a small `BreathLifecycleMachine` owning `BreathLifecycle` + the `notStarted → running ⇄ paused → completed` transitions. `BreathSessionStateMachine.pause()`/`resume()`/`complete()` (`BreathSessionStateMachine.dart:164/183/208`) delegate to it. **`_hasStarted` (`:83`) is removed** — its job (first-resume `ResetReason.start`, `:189`) becomes "lifecycle was `notStarted` at the moment of resume".
- The tick FSM consults `lifecycle.isRunning` instead of reading its own `status` to gate tick processing (`_onTick:237`). `lifecycle` is now **sourced** from the machine, not derived.
- **Restart stays a rebuild** (`restartEngine:282` → `_setupEngine:139` re-instantiates at `notStarted`) — do **NOT** add a `completed → notStarted` self-transition; counters reset via rebuild as today.
- Progression math (`_onBreathTick`/`_onRestTick`/`_advanceExercise`/`_startRest`/`_startNewCycle`) is **not** touched — it only gains the `lifecycle.isRunning` gate at its entry.

## Guards

- Behavior-preserving (green→green); no assertion edits to [[166]] / [[05]].
- `status` may still be **derived** from `(lifecycle, phase)` until [[10-breath-retire-derived-status]] retires it — keep it so any not-yet-migrated reader and the golden master stay green.
- Don't touch tick progression. Don't re-add Phase 51's auto-`pause()`.

## Verify

- [[166]] golden master + all SM/channel suites green with **no** assertion changes.
