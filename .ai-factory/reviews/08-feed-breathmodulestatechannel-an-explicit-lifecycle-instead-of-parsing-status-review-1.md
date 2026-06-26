# Code Review: Feed `BreathModuleStateChannel` an explicit lifecycle instead of parsing status

**Plan:** `.ai-factory/plans/08-feed-breathmodulestatechannel-an-explicit-lifecycle-instead-of-parsing-status.md`
**Scope of code changes reviewed:** `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `test/BreathModule/breath_module_state_channel_test.dart`
**Risk level:** 🟢 Low — pure input substitution, behavior-preserving

## Summary

The change swaps the channel's input discriminator from `BreathSessionStatus` to `BreathLifecycle`:
- `_previousStatus` → `_previousLifecycle` (field, `_onState`, `reset()`).
- `_handleLifecycle` now branches on `state.lifecycle` (`wasInactive && isRunning` → start/unpause, `wasRunning && paused` → pause, `completed` → end).
- `_handleInstruction` gates on `lifecycle == running` instead of `status ∈ {breath, rest}`.
- The test helper `_state` stamps a status-derived `lifecycle` (`breath|rest→running`, `complete→completed`, `pause→paused`).

The implementation matches the plan exactly. `_started`/`_ended`, the stopwatch + `_originWallClock`, `logPrint` lines, `_emitMarker`, `_handleInstruction` body, `_flushPending`, `reset()`, and `dispose()→stop` are unchanged.

## Correctness verification

**Byte-equivalence of the discriminator swap — confirmed.** I traced the status→lifecycle mapping against `_lifecycleFor` (`BreathSessionStateMachine.dart:494-504`):
- `isActive (breath|rest)` ≡ `lifecycle == running` (only breath/rest map to running).
- `wasPaused (prev ∈ {pause, null})` ≡ `wasInactive (prev ∈ {notStarted, paused, null})` — `pause` maps to `notStarted` or `paused`, both in the inactive set; `null` maps to `null`.
- `status == pause` (pause branch) ≡ `lifecycle == paused`, and `status == complete` ≡ `lifecycle == completed`.
- `completed → running` correctly stays a no-op (`wasInactive` excludes `completed`), matching the old `wasPaused=false` fall-through.

**Short-circuit granularity difference — benign.** The old guard short-circuits on `status` equality, the new on `lifecycle` equality. The only divergence is `breath↔rest` (same lifecycle `running`, different status): the old code falls through all branches to a no-op, the new code short-circuits — both emit no channel command. `_handleInstruction` runs as a separate call in `_onState` regardless, so instruction dispatch on a breath↔rest phase change is preserved (verified by the now-passing `status=rest and phase changes` test). The `notStarted↔paused` case cannot occur on consecutive emissions because `_hasStarted` only flips during a `running` transition.

**Production path is sound.** Both `BreathSessionViewModel` emission sites stamp `lifecycle: ...lifecycle` (`:183` initial, `:221` `_onEngineState`), and the state machine stamps every emit via `_emit`→`_lifecycleFor` (`:507-510`). The channel filters non-`ready` states, so only properly stamped states reach `_handleLifecycle`. No path delivers a default `notStarted` to a live session.

**Test helper default (`pause→paused`) is correct.** A single faked `pause` cannot distinguish `notStarted` from `paused`, but the channel treats both identically in the "was inactive" check; the only hard constraint (a pause following an active state must be `paused`, else the pause branch never fires) is satisfied. The added doc comment explains this accurately.

## Verification performed

- `flutter test test/BreathModule/breath_module_state_channel_test.dart` → **70/70 passed.** All `start/unpause/pause/end/stop` and `sendSample` sequences identical to the golden master.
- `flutter analyze` on both files → no new issues. The one `info` (`prefer_function_declarations_over_variables` at test `:163`) is pre-existing code in `_make`, outside this diff — not a regression.

## Findings

No bugs, security issues, or correctness problems.

### Minor / non-blocking (optional cleanup)

1. **Stale `_previousStatus` references in test names/comments.** The field was renamed to `_previousLifecycle`, but test descriptions and comments still say `_previousStatus`/`previousStatus` — e.g. `:591`, `:596`, `:602`, `:618`, `:624`, and the comment at `:1693`. The plan deliberately left test bodies untouched to keep the golden master pristine, which is reasonable; these strings are now mildly misleading but have zero functional impact. Optional follow-up.

REVIEW_PASS
