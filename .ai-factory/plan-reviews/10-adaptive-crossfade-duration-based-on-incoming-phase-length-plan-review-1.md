# Plan Review: Adaptive crossfade duration based on incoming phase length

**Plan:** `.ai-factory/plans/10-adaptive-crossfade-duration-based-on-incoming-phase-length.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Context Gates
- **Architecture:** No `.ai-factory/ARCHITECTURE.md` present at `mind_mobile/.ai-factory/` for direct check. The change stays inside the breath_module package and does not cross module boundaries — no architectural concerns.
- **Rules:** No `.ai-factory/RULES.md` present. The plan respects existing `BreathSoundCoordinator` shape (no signature changes, no domain leakage into `packages/breath_module`).
- **Roadmap:** Plan corresponds to the unchecked milestone in `mind_mobile/.ai-factory/ROADMAP.md` line 19. Linkage is clear.
- **Skill-context:** No `mind_mobile/.ai-factory/skill-context/aif-review/SKILL.md`. No project-specific overrides to apply.

## Codebase verification
- `BreathSessionState.currentPhaseTotalDuration` and `state.currentIntervalMs` exist (`packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart:35,22`). ✓
- `currentPhaseTotalDuration` semantics confirmed: total duration of the current phase in **ticks** (set from `steps[currentPhaseIndex].duration` in `_computeEnrichedFields`, `BreathSessionStateMachine.dart:437–441`; docs at `docs/breath/session/view-model.md:54`). The plan's `nextPhaseMs = phaseTicks * intervalMs` math is correct. ✓
- At the **status-change → breath** call site (line 152–156), the state machine has already populated `currentPhaseTotalDuration` for the incoming phase via `_initialBreathState` / `resume()`, so reading it here yields the correct value (not stale). ✓
- At the **phase-change** call site (line 168–174), `currentPhaseTotalDuration` is re-emitted on every `_onBreathTick` with the new phase's duration — fine. ✓
- `dart:math`'s `pow` is already imported at line 2 of `BreathSoundCoordinator.dart`. ✓
- The fallback `intervalMs.clamp(_kMinFadeMs, _kMaxFadeMs)` compiles cleanly: Dart's `int.clamp(int, int)` returns `int`, usable directly as `Duration(milliseconds:)`. ✓
- The two call sites that should be touched are correctly identified; the pause/rest/complete `_fadePlayer(... 200ms/500ms)` branches are correctly left alone. ✓

## Critical Issues

None blocking — the plan is functionally sound and will compile and run correctly. The issues below are accuracy/clarity concerns.

## Concerns

### 1. The reference table in Task 1 does NOT match the formula (WARN — inherited from roadmap)

Task 1 instructs adding a comment with this reference table:
> 1s → ~160ms, 2s → ~310ms, 3s → ~680ms, 4s → ~1000ms, 8s+ → 1500ms capped

But with the prescribed constants (`k = 3.83`, exponent = `0.65`, clamp `[150, 1500]`), the actual values are:

| nextPhaseMs | `3.83 * pow(ms, 0.65)` | clamped |
|---|---|---|
| 1000 | 341.4 | **341ms** (not 160) |
| 2000 | 536.2 | **536ms** (not 310) |
| 3000 | 705.5 | **706ms** (close to 680) |
| 4000 | 842.6 | **843ms** (not 1000) |
| 8000 | 1320  | **1320ms** (not capped at 1500) |
| ~10500 | 1500 | 1500ms (cap actually hits here) |

To make the table true, either the constants need to change (e.g. to land 4s ≈ 1000ms, `k` should be ~4.55, not 3.83) or the table values should be replaced with the correct ones. The mismatch was inherited from the ROADMAP description (line 19) — the plan faithfully copies it, but copying an error forward will mislead future readers and is worth flagging back to the milestone author.

**Recommended action:** before implementing Task 1, ask the user which is the intended ground truth — the constants (and update the table) or the table (and recompute the constants). The fade behavior the user actually feels is determined by the constants, so if 1s → ~160ms is the design intent the formula as planned will be perceptually wrong (over twice as long).

### 2. Task 4 instruction is conditional and slightly ambiguous (WARN — minor)

Task 4 says:
> if the existing status/phase `debugPrint` lines mention interval, append the computed fade duration

The current logs at lines 148 and 171 do **not** mention `intervalMs` at all (they print status, phase, active player, volumes). So under a literal reading of the condition, nothing changes. But the next sentence says "extend the two lines that now compute `fadeDuration`" — implying the log should be extended unconditionally. Recommend rewording Task 4 to explicitly state: "append `fade=${fadeDuration.inMilliseconds}ms` to the existing `debugPrint` at line 148 (status change) and line 171 (phase change)". Otherwise the implementer may skip the log change.

Note also that `_switchToPhase` already prints `fadeDuration=...ms` at line 203, so this is purely a convenience for log grepping — non-blocking.

## Positive Notes

- The plan correctly preserves the existing `intervalMs > 0 ? ... : 1000` guard pattern already used in the file.
- Adding the helper as a private method (no signature changes to `_switchToPhase`) keeps the change surgical and reviewable.
- Leaving pause/rest/complete/non-phase-asset fade calls untouched is the right call — those are fixed UX timings, not phase-length-derived.
- The fallback for `phaseTicks <= 0` (initial state, error state) gracefully degrades to a clamped one-tick interval rather than throwing or producing a zero-length fade.
- Constants are `static const` and placed alongside the other tuning maps, matching the file's existing style.

## Summary

The implementation logic is correct and safe. The only substantive issue is documentation accuracy: the reference table that Task 1 asks to copy into the source comment does not match the formula. This should be reconciled with the user (likely by re-checking the milestone's intent) before Task 1 is committed — otherwise the source comment will mislead anyone trying to tune the curve later.

If you accept the inherited table mismatch as out-of-scope (since it was authored upstream in the roadmap) and only want a clarifying tweak to Task 4's debug-log instruction, the plan is otherwise ready to execute.
