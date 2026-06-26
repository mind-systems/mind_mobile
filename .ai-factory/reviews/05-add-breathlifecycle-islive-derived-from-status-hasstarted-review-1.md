# Code Review: Add `BreathLifecycle` + `isLive`, derived from status + `_hasStarted`

**Plan:** `.ai-factory/plans/05-add-breathlifecycle-islive-derived-from-status-hasstarted.md`
**Reviewed:** working-tree diff (`git diff HEAD`) — 4 source files + 1 new test file.
**Risk Level:** 🟢 Low — purely additive, correct, and verified green against the new contract suite and the golden master.

## Scope of changes

- `BreathSessionState.dart` — new `enum BreathLifecycle`, `lifecycle` field (defaulted, not required), `isLive` getter, plus `copyWith` / `equalsIgnoringTickFields` inclusion.
- `BreathSessionStateMachine.dart` — `lifecycle` field on `BreathSessionStateMachineState` (defaulted) + central derivation in `_emit` via `_lifecycleFor(status)`.
- `BreathSessionViewModel.dart` — carries `lifecycle` through both full-constructor sites (`_setupEngine`, `_onEngineState`).
- `BreathActivityHarness.dart` — `isLive` getter now mirrors the last recorded state.
- New `breath_lifecycle_islive_test.dart` — 5 contract tests covering the derivation table.

## Correctness analysis

**Derivation is correct and exhaustive.** `_lifecycleFor` switches over all four `BreathSessionStatus` values with no `default` (relies on Dart enum exhaustiveness — compiles cleanly): `complete→completed`, `breath|rest→running`, `pause→ paused/notStarted` by `_hasStarted`. Matches the spec rule field-for-field.

**Central `_emit` derivation is sound** — this is the smaller-surface alternative the plan explicitly permitted. `_emit` stamps `newState.copyWith(lifecycle: _lifecycleFor(newState.status))` on every emission, so the per-site `lifecycle` defaults are always overwritten with the derived value before publication. No emit site can leak a stale default.

**The `resume()` timing subtlety is handled.** `_hasStarted` flips to `true` *after* the `resume()` emit, but at emit time `status ∈ {breath, rest}` → `running` independent of `_hasStarted`, so the off-by-one-in-time is immaterial. Verified by the passing "after resume() → running" test.

**The initial-state path that bypasses `_emit` is still correct.** `_initialRestState()` / `_initialBreathState()` are assigned directly to `_state` in the constructor (never through `_emit`), so they are *not* re-stamped — but they correctly inherit the `BreathLifecycle.notStarted` constructor default (status `pause`, `_hasStarted` false → `notStarted`). The VM's `_setupEngine` reads `currentState.lifecycle` (= `notStarted`) into the first recorded `BreathSessionState`. Confirmed by the "initial state → notStarted" test.

**Default-instead-of-required resolves the plan-review-1 blocker.** Both `lifecycle` fields default to `notStarted`, so the 5 pre-existing external `BreathSessionState(...)` call sites (incl. the `const` site) compile untouched. The two production full-constructor sites (`BreathSessionViewModel:152` and `:190`) and `factory .initial()` were all checked: the two VM sites pass `lifecycle` explicitly; `.initial()` correctly inherits `notStarted`. No other production constructor exists.

**`equalsIgnoringTickFields` inclusion is correct and non-regressive.** `lifecycle` is a pure function of `(status, _hasStarted)`; `status` is already compared, so adding `lifecycle` only adds publication on a same-`status` / different-`_hasStarted` transition — which only occurs across a status change anyway (notStarted→paused always routes through a running state). The raw `_stateController` fires on every `set state` regardless, so `harness.states` ordering is unaffected. Golden master re-run confirms no shift.

**Test #5 reaches a real `rest` status.** `BreathExerciseDTO(steps: [], restDuration: 3, …)` satisfies `isRestOnly` (`steps.isEmpty && restDuration > 0`), so the machine inits into rest and `resume()` emits `status == rest` → `running`. Constructor args match the DTO signature; `BreathExerciseDTO` and `BreathLifecycle` are both exported via the barrel.

## Verification performed

- `flutter test breath_lifecycle_islive_test.dart breath_activity_boundary_characterization_test.dart` → **All tests passed** (5 new + golden master).
- `flutter test breath_activity_harness_test.dart` → **passed**, including the pre-existing `expect(harness.isLive, isFalse)` at `:69` (its final state after `complete()` is `completed` → `isLive == false`, so the assertion holds under real semantics).

## Nits (non-blocking, optional)

- `test/BreathModule/Support/breath_activity_harness_test.dart:64-68` — the comment still calls `isLive` a "placeholder … wired in [[05-…]]". The wiring is now done; the assertion now passes on *real* semantics (final state is `completed`) rather than a hardcoded `false`. Consider refreshing the comment to avoid implying the value is still a stub. Cosmetic only — no behavior impact.

## Verdict

No bugs, security issues, or correctness problems. The change is purely additive, the derivation is correct and verified, the plan-review-1 compile blocker is properly resolved via defaulting, and nothing reads `lifecycle` yet (consumers migrate in later milestones). Approved.

REVIEW_PASS
