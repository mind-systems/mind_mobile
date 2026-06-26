# Plan Review: Feed `BreathModuleStateChannel` an explicit lifecycle instead of parsing status

**Plan:** `.ai-factory/plans/08-feed-breathmodulestatechannel-an-explicit-lifecycle-instead-of-parsing-status.md`
**Files Reviewed:** 4 (channel, state model, state machine, test suite) + wiring + roadmap/rules
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN-none. The change stays entirely inside the domain-layer adapter (`lib/BreathModule/Core/BreathModuleStateChannel.dart`), which already depends on `package:breath_module`. No new cross-boundary dependency is introduced — `BreathLifecycle` is already part of the package's public surface the channel consumes. Aligned.
- **Rules (`.ai-factory/RULES.md`):** PASS. The three rules concern Module Services being stateless, App.dart purity, and constructor injection. `BreathModuleStateChannel` is not a Module Service (it is a server adapter, legitimately stateful, constructor-injected with its stream). None of the rules are touched.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS — strong linkage. This is the open Phase 58 task verbatim ("Feed `BreathModuleStateChannel` an explicit lifecycle instead of parsing status"). The roadmap's prescribed mapping (`notStarted→running ⇒ start/unpause`, `running→paused ⇒ pause`, `→completed ⇒ end`, keep `_started/_ended`/stopwatch/markers/`reset()`/`dispose()→stop` byte-identical) matches the plan exactly. Note: the roadmap references a spec note `.ai-factory/notes/08-breath-channel-explicit-lifecycle.md`; the plan does not cite it but reproduces the same intent — not blocking.

## Critical Issues

None.

## Verification of the byte-equivalence claim (the load-bearing assertion)

The plan's correctness hinges on `status`-based and `lifecycle`-based discrimination producing identical channel calls. I confirmed the mapping against the actual source:

- `_lifecycleFor` (`BreathSessionStateMachine.dart:494-504`) maps `complete→completed`, `breath|rest→running`, `pause & _hasStarted→paused`, `pause & !_hasStarted→notStarted` — exactly as the plan states.
- `isActive (status ∈ {breath,rest}) ≡ lifecycle == running` — confirmed (breath/rest always map to running, and only those do).
- `wasPaused (prev ∈ {pause, null}) ≡ wasInactive (prev lifecycle ∈ {notStarted, paused, null})` — confirmed: `pause` maps to either `notStarted` or `paused`, both in the inactive set; `null` maps to `null`.
- `completed → running` stays a no-op: `wasInactive` excludes `completed`, matching the old `wasPaused=false` short-circuit. Confirmed against the `complete → pause → complete` test (`:515`), which still yields `endCount==1` under the new branching.

**Short-circuit granularity difference (the subtle part):** the old code short-circuits on `status` equality, the new on `lifecycle` equality. The only divergence cases are (a) `breath↔rest` (same lifecycle `running`, different status) and (b) a hypothetical `notStarted↔paused` with status staying `pause`. Case (a) produces no channel command under either implementation (it falls through all branches in the old code, short-circuits in the new). Case (b) cannot occur on consecutive emissions because `_hasStarted` only flips during a `running` transition — and even if it did, all branches evaluate to no-op. Net behavior is identical. The plan's "byte-identical" claim is accurate.

## Verification of the test-helper change

- The `_state(...)` helper (`:103-120`) currently omits `lifecycle`, defaulting to `notStarted`. After the channel branches on `lifecycle`, stamping `breath|rest→running`, `complete→completed`, `pause→paused` is both necessary and sufficient. I traced the non-obvious suites: first-emission `pause` (`:404`), `pause→pause` (`:417`), `breath→pause` (`:371`), `complete→pause→complete` (`:515`), both loadState-filter resume cases (`:590`, `:612`), and all four `reset()` cases (`:721`) — every one produces the identical channel/`sendSample` sequence under the helper change.
- `pause→paused` (rather than `notStarted`) is the correct default: the `breath→pause` pause-branch requires `lifecycle == paused` to fire. Mapping pause to `notStarted` would silently drop the pause command. The plan picks `paused` and justifies it correctly.
- `BreathLifecycle` is reachable via `package:breath_module/breath_module.dart` — the barrel exports `BreathSessionState.dart` (`breath_module.dart:23`), which is where the enum is declared. Both the channel import and the test `show` import will resolve. Confirmed.

## Production wiring sanity

The channel subscribes to `vm.stream` (`lib/BreathModule/BreathModule.dart:50`). Both `BreathSessionViewModel` emission sites (`:183` initial, `:221` `_onEngineState`) carry `lifecycle: engineState.lifecycle`, so production states reaching the channel are properly stamped by the state machine. Switching the discriminator does not regress the live path.

## Minor notes (non-blocking)

1. **Transient compile state — sequence Task 1 and Task 2 atomically.** Task 1 instructs dropping `BreathSessionStatus` from the import on `:9`, but `_handleInstruction` (`:119-120`) still references it until Task 2 lands. Both edits are in the same file; do them in one pass (or drop the import only after the Task 2 edit) to avoid an intermediate non-compiling file. The plan already notes "it is no longer referenced after Task 2," so this is just an implementation-ordering reminder.

2. **Stale test names/comments referencing `_previousStatus`.** After the rename, the field is `_previousLifecycle`, but test names and comments at `:591`, `:596`, `:602`, `:618`, `:624`, and `:1679` still say `_previousStatus`/`previousStatus`. The plan deliberately leaves test bodies untouched (a reasonable scope decision that keeps the golden master pristine), but these strings become mildly misleading. Optional cleanup — not required for correctness.

## Positive Notes

- The Background section is an unusually rigorous pre-verification: every branch and the full golden master were checked case-by-case, and the plan correctly identifies the one true constraint (a pause following an active state must map to `paused`).
- Accurate line references throughout (`:19`, `:61`, `:75-115`, `:119-121`, `:151`, helper `:103-120`, import `:11-12`) — all confirmed against the current files.
- The plan correctly scopes the change as a pure input substitution and resists re-architecting the adapter, matching the roadmap's explicit "NOT a re-architecture" constraint.
- Task 4 (run the golden master) is the right verification gate, and the "no behavioral suites" stance is appropriate for a behavior-preserving refactor.

PLAN_REVIEW_PASS
