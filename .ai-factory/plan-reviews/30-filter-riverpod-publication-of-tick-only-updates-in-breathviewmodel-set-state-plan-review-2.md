# Plan Review v2: 30-filter-riverpod-publication-of-tick-only-updates

**Plan:** `.ai-factory/plans/30-filter-riverpod-publication-of-tick-only-updates-in-breathviewmodel-set-state.md`
**Files Reviewed:** plan + `BreathSessionViewModel.dart`, `BreathSessionState.dart`, `BreathSessionStateMachine.dart`, `BreathSessionScreen.dart`, `BreathTimelineWidget.dart`, `BreathAnimationCoordinator.dart`, `OrbAnimationCoordinator.dart`, `BreathSoundCoordinator.dart`, `BreathModuleStateChannel.dart`, `BreathModule.dart`, note 11, prior review 1.
**Risk Level:** 🟢 Low — the critical defect from review 1 is fixed, remaining suggestions are doc-level wording polish.

---

## Context Gates

- **ARCHITECTURE.md** — PASS. Edits stay within `packages/breath_module/` (the module boundary). `BreathSessionState` is a pure-Dart model; the new helper is pure Dart with no Flutter imports. `set state` override stays inside the ViewModel where the module-boundary contract sits.
- **RULES.md** — PASS. No App.dart initializer changes, no new subscription/stream lifecycles beyond the existing `_stateController` / `ref.onDispose` plumbing, no DTO/proto changes, no migrations.
- **ROADMAP.md** — n/a. This is a perf follow-up to tasks 26/27/28 (per note 11); no roadmap milestone linkage required.

---

## Resolution of Review 1 Findings

| Finding | Status |
|---|---|
| 1. Exclude `currentIntervalMs` from equality check (else filter is a no-op) | ✅ Fixed — Task 1 explicitly excludes both `remainingTicks` and `currentIntervalMs`, Context section restated. |
| 2. Rename helper to `equalsIgnoringTickFields` | ✅ Fixed — adopted everywhere (Task 1 method name, Task 2 reference). |
| 3. Note that `super.state` is safe to read inside setter | ✅ Fixed — Task 2 retains the exact maintainer note with the four invocation sites listed. |
| 4. Comment on `identical()` for `timelineSteps` to deter `listEquals` refactor | ✅ Fixed — Task 1 mandates the comment with the explicit warning about a silent-breakage refactor. |
| 5. Task 3 audit / no `ref.watch` consumer reads tick-cadence fields | ✅ Fixed — Task 3 instructs flagging any consumer that reads `remainingTicks` or `currentIntervalMs` via `ref.watch`. Verified independently: `BreathSessionScreen` reads `state.{status, canStar, isStarred, loadState, timelineSteps, activeStepId, phase}` and never `remainingTicks` / `currentIntervalMs`. The timeline countdown is wired to `remainingTicksNotifier` (tasks 26/27). |
| 6. Exit criteria — verify via devtools that build doesn't fire per tick | ✅ Fixed — Task 3 includes the `flutter run --flavor dev` verification step. |

---

## Critical Issues

None.

---

## Minor Issues / Suggestions

### 1. Task 3 wording — `BreathModuleStateChannel` *does* read `currentIntervalMs`

**File:** plan Task 3 (verification list)

The plan states: *"`BreathModuleStateChannel` … reads from `_stateController.stream`; it does not depend on `remainingTicks` or `currentIntervalMs`, so behavior is unchanged."*

That second clause is incorrect — `lib/BreathModule/Core/BreathModuleStateChannel.dart` lines 100 and 107 do read `state.currentIntervalMs` to forward via `_instructionStream.sendSample(...)`. The conclusion ("behavior is unchanged") is still correct because the channel subscribes via `vm.stream` (the raw `_stateController.stream`, wired in `lib/BreathModule/BreathModule.dart:42`), which the plan correctly keeps firing every tick. But the supporting reason should be corrected to: *"reads `currentIntervalMs` via the raw stream subscription, which still fires on every tick — behavior is unchanged."*

Pure doc fix; does not affect implementation.

### 2. `tickService.source` vs `state.tickSource` — confirm cadence remains structural

**File:** plan Task 1 (compare-by-`==` list)

`tickSource` is included in the structural compare. Today it is set only in `_setupEngine` (from `tickService.source`) and copied through unchanged in `_onEngineState`. So per-tick emissions carry the same value as the previous state and equality holds — no spurious publication. Correct. Worth keeping a one-line internal note in the helper's doc comment: *"`tickSource` is currently constant per session; if runtime switching is added (see `docs/breath/session/tick-sources.md`), the change emits a structural publication — which is what we want."* Optional polish, not required.

### 3. `toggleStar` path is correctly covered

`toggleStar` calls `set state = state.copyWith(isStarred: ...)` (lines 251, 255, 257). The helper includes `isStarred`, so optimistic / confirmed / rollback writes all flow through `super.state = value` and publish to Riverpod — the star icon will continue to redraw. ✓ No plan change needed; flagging for completeness.

### 4. First-publication invariant after `build()`

The very first `set state` call comes from `_setupEngine` (called inside `initState()` after `service.getSession(...)` resolves), at which point `super.state == BreathSessionState.initial()` (loading). The incoming state has `loadState: ready` — structural change, filter returns `false`, publication fires. ✓ Plan handles this implicitly via the "safe to read super.state" note.

### 5. Helper placement / style

"Place the method directly after `copyWith`" is fine and matches the file's existing top-down layout. No `==`/`hashCode` override is being added (intentional, since this is a per-pair, narrow-purpose comparison) — that decision is implicit in the plan; worth noting explicitly in the doc comment to pre-empt a "why isn't this just `==`?" follow-up: *"This is intentionally not the class `operator ==` — it deliberately ignores tick-cadence fields so it cannot be reused as a general-purpose equality."* Optional.

---

## Positive Notes

- **Critical defect from review 1 fully resolved.** The shift to `equalsIgnoringTickFields` with both tick fields excluded turns the filter from a no-op into a real per-tick rebuild suppressor.
- **Identity-check guardrail.** The mandated comment on `identical(timelineSteps, ...)` with the explicit warning against a `listEquals` refactor is a strong forward-defense; tasks 26/27/28 establish the by-replacement mutation invariant and this comment ties the optimization back to that invariant.
- **Dual-channel separation is preserved.** Raw `_stateController.add(value)` always fires; only `super.state = value` is gated. Animation/sound/state-channel cadence is untouched (independently verified against all four `viewModel.listen(...)` / `vm.stream` consumers).
- **Maintainer note about `super.state` read-safety inside the setter** is exactly the right paranoia: the four invocation sites (`_setupEngine`, `_onEngineState`, `toggleStar`, error branch in `initState`) are all post-`build()`.
- **Scope discipline.** Two files, no DTO/proto/migration surface, no test churn (per project settings), aligned with note 11.
- **Verification step is concrete and operator-actionable** — `flutter run --flavor dev` + devtools build-count is the right exit criterion.

---

## Verdict

The plan is ready to implement. All blocking review-1 issues are addressed; remaining notes are pure documentation wording (Task 3's `BreathModuleStateChannel` justification could be tightened) and optional helper-doc polish. Neither blocks execution.

PLAN_REVIEW_PASS
