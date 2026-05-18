# Plan Review (v2): Adaptive crossfade duration based on incoming phase length

**Plan:** `.ai-factory/plans/10-adaptive-crossfade-duration-based-on-incoming-phase-length.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Context Gates
- **Architecture:** No `mind_mobile/.ai-factory/ARCHITECTURE.md` present. The change is internal to `packages/breath_module` and respects the existing module boundary (no domain leakage, no `_switchToPhase` signature change). No architectural concerns.
- **Rules:** No `mind_mobile/.ai-factory/RULES.md` present. Plan keeps the existing `intervalMs > 0 ? … : 1000` guard pattern already used in the file.
- **Roadmap:** Plan corresponds to the unchecked milestone in `mind_mobile/.ai-factory/ROADMAP.md` line 19. Linkage is explicit; the plan's `## Context` block acknowledges and resolves the table/constants mismatch in that milestone.
- **Skill-context:** No `mind_mobile/.ai-factory/skill-context/aif-review/SKILL.md`. No project-specific overrides to apply.

## Codebase verification
- `state.currentPhaseTotalDuration` (ticks) and `state.currentIntervalMs` exist (`packages/breath_module/lib/src/BreathSession/Models/BreathSessionState.dart:22,35`). Semantics: `currentPhaseTotalDuration` is the number of ticks in the current phase (set from `steps[currentPhaseIndex].duration` in the state machine). The plan's `nextPhaseMs = phaseTicks * intervalMs` derivation is correct. ✓
- At the **status‑change → breath** call site (`BreathSoundCoordinator.dart:152–156`), the state machine has already populated `currentPhaseTotalDuration` for the incoming phase before this listener fires, so reading it here yields a non‑stale value. ✓
- At the **phase‑change** call site (`BreathSoundCoordinator.dart:168–174`), `currentPhaseTotalDuration` is re‑emitted on `_onBreathTick` with the new phase's duration. ✓
- `dart:math` is already imported (`BreathSoundCoordinator.dart:2`), so `pow` is available without a new import. ✓
- The four other `_fadePlayer` calls (pause→200ms at line 151, in‑phase volume bump at line 158, complete/rest at line 162, non‑phase‑asset at line 176) are correctly left untouched — those are fixed UX timings, not derived from phase length. ✓
- Formula verification against the plan's source‑comment table (`k=3.83`, exponent `0.65`, clamp `[150,1500]`):
  - 1000ms → 341.4 → **341ms** ✓
  - 2000ms → 536.2 → **536ms** ✓
  - 3000ms → 705.5 → **706ms** ✓
  - 4000ms → 842.6 → **843ms** ✓
  - 8000ms → 1320  → **1320ms** ✓
  - Cap (1500ms) hits at ~10470ms → **~10.5s** ✓
  All values match the table written in Task 1.
- Type check on the helper: `pow(double, double)` returns `num`; `num * double` is `num`; `num.clamp(double, double)` returns `num`; `.toInt()` is valid. Compiles cleanly.
- The `phaseTicks <= 0` fallback path uses `intervalMs.clamp(_kMinFadeMs, _kMaxFadeMs)`. `int.clamp(int, int)` returns `int`, which `Duration(milliseconds:)` accepts. ✓

## Resolution of review‑1 concerns
- **Reference table vs constants mismatch:** the plan's `## Context` block now explicitly acknowledges the mismatch in the roadmap description and chooses the constants as the source of truth, writing the *correct* table into the Task 1 source comment. Future tuners will see numbers that actually match the formula. ✓
- **Task 4 ambiguity:** the instruction is now unconditional ("Unconditionally extend the two existing `debugPrint` lines"). ✓

## Concerns

### 1. Task 4 — preferred placement at line 148 (advisory, non‑blocking)
The status‑change `debugPrint` at line 148 fires for **all** status transitions (`pause`, `breath`, `rest`, `complete`), but `fadeDuration` is only computed inside the `BreathSessionStatus.breath` branch where the phase asset changes. The plan offers two options:

> "move the `debugPrint` if needed so `fadeDuration` is in scope, **or** add a second `debugPrint` inside the branch immediately before the `_switchToPhase` call"

The first option ("move the debugPrint") would lose the existing log for pause / rest / complete status transitions, which is a small but real regression in observability. The second option (add a second `debugPrint` inside the `breath` + new‑phase branch, after computing `fadeDuration` and before `_switchToPhase`) is strictly preferable. Worth nudging the implementer toward the additive approach so the existing top‑level status log stays intact.

Suggested rewording: "**Prefer adding a second `debugPrint`** inside the `case BreathSessionStatus.breath` branch (specifically inside the `state.phase != _currentPhase` sub‑branch, after `fadeDuration` is computed) rather than moving the existing line‑148 log — moving it would drop the status log for pause/rest/complete transitions."

This is advisory; the plan is acceptable as written.

## Positive Notes
- Constants are `static const` and clustered with `_phaseAssets` / `_phaseOrder` / `_tickAssets`, matching the file's existing style.
- Helper is a private method with no signature change to `_switchToPhase` — minimal blast radius, easy to revert.
- Fallback for `phaseTicks <= 0` degrades gracefully to a clamped one‑tick interval, never producing a zero‑length fade or throwing.
- The plan correctly preserves the `currentIntervalMs > 0 ? … : 1000` guard already established in the file.
- The accurate reference table in Task 1's source comment will keep future tuners from re‑introducing the milestone's documentation drift.
- Task 4 logs are explicit about the convenience nature (call‑site grepping) and acknowledge the existing `fadeDuration=…ms` log inside `_switchToPhase` at line 203.

## Summary
The plan is functionally correct, type‑safe, and addresses both concerns raised in review‑1. The only remaining nit is preferring an additive `debugPrint` over a moved one in Task 4, so the existing pause/rest/complete status log isn't lost. Non‑blocking — implementer can decide at the keyboard.

PLAN_REVIEW_PASS
