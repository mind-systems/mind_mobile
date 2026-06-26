# Plan Review 2 — Add `BreathLifecycle` + `isLive`, derived from status + `_hasStarted`

**Plan:** `.ai-factory/plans/05-add-breathlifecycle-islive-derived-from-status-hasstarted.md`
**Scope:** `packages/breath_module` (state model, state machine, view model) + breath test suite
**Risk Level:** 🟢 Low

## Verification Summary

Every structural claim in the plan was checked against the live codebase. The plan is accurate and implementable. Findings below are limited to one non-blocking guidance correction.

### Line numbers / construction sites — all confirmed ✅
- State machine 9 emit construction sites match exactly: `_initialRestState` (117), `_initialBreathState` (141), `pause` (167), `resume` (191), `complete` (216), `_onBreathTick` (278), `_onRestTick` (315), `_startRest` (343), `_startNewCycle` (373).
- `BreathSessionStateMachineState` field (13) / constructor (29) / `copyWith` (44) — confirmed.
- `_hasStarted = true` flips at line 205, **after** the resume emit (191–204) — confirmed. The derivation note (status ∈ {breath,rest} → `running` regardless of `_hasStarted`) makes the ordering irrelevant, which the plan correctly states.
- ViewModel full-constructor sites `_setupEngine` (152) and `_onEngineState` (189) — confirmed; both build `BreathSessionState(...)` from the engine state and will carry `lifecycle` cleanly. All other ViewModel writes are `copyWith`-based and never change `status`, so the `?? this.lifecycle` passthrough is correct.
- Harness placeholder `bool get isLive => false;` at line 64, doc at 62–63 — confirmed.

### Constructor-safety claims — confirmed ✅
- `BreathSessionState(` full-constructor call sites exist in exactly 5 `.dart` files: the model itself, `BreathSessionViewModel.dart` (2 production sites, Task 4), and 3 test files. No site was missed. The 5 test call sites (`breath_session_state_equality_test.dart:29/72/98`, `breath_session_enriched_state_test.dart:569`, `breath_module_state_channel_test.dart:111`) all omit `lifecycle` and would break under a `required` field — so the **default (`this.lifecycle = BreathLifecycle.notStarted`) is the correct decision**. This was the blocking fix from plan-review-1 and it is sound.
- The `const BreathSessionState(...)` at `enriched_state_test.dart:569` stays `const`-valid because the default value `BreathLifecycle.notStarted` is a compile-time constant. ✅
- `BreathSessionStateMachineState(` is constructed **only** inside `BreathSessionStateMachine.dart` — no external callers — so `required this.lifecycle` there is safe. ✅

### Barrel export — confirmed ✅
`breath_module.dart` whole-file-exports both `BreathSessionState.dart` (line 23) and `BreathSessionStateMachine.dart` (line 24), so `BreathLifecycle` is exported automatically — no barrel edit needed, as claimed.

### `equalsIgnoringTickFields` impact — confirmed safe ✅
Adding `lifecycle` to the structural comparison does not break existing tests: in all current call sites both operands inherit the same default (`notStarted`), so equality is preserved. It is also semantically correct — `lifecycle` changes only in lockstep with `status` (or with the `_hasStarted` flip that itself occurs only on a status-changing resume), so it never needs to suppress publication like the tick fields do. Including it matches the spec note §Details.

### Golden master stays green — confirmed ✅
`breath_activity_boundary_characterization_test.dart` asserts on individual fields (`status`, `phase`, `exerciseIndex`, `remainingTicks`, `resetReason`) — not full-state equality — so the additive `lifecycle` field cannot break it.

### Context Gates
- **Architecture** (`mind_mobile/CLAUDE.md` / module boundary): The change keeps domain→module DTO boundaries intact — `BreathSessionState` and `BreathSessionStateMachineState` both live inside `packages/breath_module`, and the additive field never crosses a new boundary. WARN: none.
- **Rules** (logging facade, no manual pubspec edits, etc.): Plan adds no logging and no dependencies; "Logging: minimal" is consistent with the existing `logPrint` usage. No violation.
- **Roadmap**: Plan is milestone 05 in an explicit T3→T9 sequence and correctly defers `_hasStarted` removal to milestone 09. Linkage present. No WARN.

## Findings

### Issues to Address (non-blocking)

**1. [WARN] Task 1 rest-phase test mechanism is inaccurate — `makeExercise` cannot build a rest-only exercise.**
The plan says to exercise the `rest`-status → `running` case via "a rest-only first exercise via `makeSession`/`makeExercise` ... then `resume()` → `status == rest`". This will not work as written:
- `BreathExerciseDTO.isRestOnly` is defined as `steps.isEmpty && restDuration > 0` (`BreathExerciseDTO.dart:17`).
- The `makeExercise` helper (`BreathActivityFakes.dart:191`) **always** emits two steps (`inhale`, `exhale`) and exposes no way to produce an empty-steps exercise. So a session built from `makeExercise` is never `isRestOnly`, and `resume()` on it yields `status == breath`, never `rest`.

To actually reach a `rest` status the implementer must do one of:
  - Construct a `BreathExerciseDTO(steps: [], restDuration: N, repeatCount: 1, shape: null)` **directly** (bypassing `makeExercise`) as the first exercise → initial state is rest-only → `resume()` → `status == rest`; or
  - Use `makeExercise(restDuration: N, repeatCount: 2)` and **tick through a full cycle** so the engine enters `_startRest` (`status == rest`) between repeats — this needs `tick()` calls, not just `resume()`.

Recommend updating Task 1's guidance to one of these concrete paths. Severity is WARN, not blocking: the `running` derivation is already covered by the breath-phase assertion (both `breath` and `rest` map to `running` through the single derivation rule), so the rest-specific case is a belt-and-suspenders contract check; and under TDD the implementer will observe the real emitted `status` and self-correct. But the stated mechanism would otherwise cost debugging time.

### Minor Notes
- Task 3's "smaller-surface alternative" (derive once in `_emit`) is noted as optional. For the record: with `lifecycle` declared `required` on `BreathSessionStateMachineState`, a pure `_emit`-central derivation would still need a `copyWith(lifecycle: _lifecycleFor(newState.status, _hasStarted))` inside `_emit` (the constructor field can't be left unset). The plan's chosen per-site default avoids this wrinkle and is the cleaner path — good call to make it the default.
- `_emit` does exist as a single sink (line 481), but it receives an already-constructed struct, so the plan's "no single construction point" framing is correct in substance.

## Positive Notes
- Correctly identifies and resolves the plan-review-1 blocker (default vs `required`) with a precise rationale tied to the `const` call site.
- Derivation rule is single-sourced and consistent across the spec note, the model, and the state machine.
- Purely-additive guard is respected: `status` semantics, progression counters, and `_hasStarted` lifetime are all left untouched; `_hasStarted` removal correctly deferred to milestone 09.
- All 14 referenced line numbers and all constructor call-site claims were verified exact — unusually high-fidelity recon.

PLAN_REVIEW_PASS
