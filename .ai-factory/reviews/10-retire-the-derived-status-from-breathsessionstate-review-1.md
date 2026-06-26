# Code Review: Retire the derived `status` from `BreathSessionState`

**Scope:** 8 production files + 7 test files in `packages/breath_module` and `test/BreathModule`.
**Verification:** `flutter test test/BreathModule/` → **all 292 tests pass**; `flutter analyze packages/breath_module lib/BreathModule` → no new issues (1 pre-existing unrelated `unused_field` warning).

## What was changed

`enum BreathSessionStatus { pause, breath, rest, complete }` and the `status` field on both
`BreathSessionState` and `BreathSessionStateMachineState` were deleted. Every consumer now reads
`lifecycle` (`BreathLifecycle`) + `phase` (`BreathPhase`). This is a representation-only refactor —
`status` was a Cartesian smear of (lifecycle × phase-kind).

## Correctness verification

I traced each migration against the equivalence map and confirmed semantic equivalence:

| Old `status` | New expression | Verified |
|---|---|---|
| `pause` | `lifecycle == notStarted \|\| paused` | ✓ |
| `breath` | `lifecycle == running && phase != rest` | ✓ |
| `rest` | `lifecycle == running && phase == rest` | ✓ |
| `complete` | `lifecycle == completed` | ✓ |

**Key load-bearing fact verified:** the new `_onTick` dispatch in `BreathSessionStateMachine`
switched from `switch (_state.status)` to `if (_state.phase == BreathPhase.rest)`. This is only
correct if a *breath* exercise step can never carry `phase == rest`. Confirmed end-to-end:
`StepType` (domain, `lib/BreathModule/Models/StepType.dart`) is `{inhale, hold, exhale}` only, and
`BreathSessionDTOMapper._mapStepType` maps those exhaustively to `BreathPhase.inhale/hold/exhale`.
`BreathPhase.rest` is produced *only* by the state machine's rest paths (`_initialRestState`,
`_onRestTick`, `_startRest`). So when `lifecycle == running`, `phase == rest ⟺ old status == rest`.
The dispatch is exactly equivalent. ✓

**State-machine guards:**
- `pause()` `_lifecycle.current == completed` early-return ≡ old `status == complete`. ✓
- `resume()` `if (_lifecycle.isRunning || _lifecycle.current == completed) return;` ≡ old
  `status != pause` (proceeds only from `notStarted`/`paused`). The now-removed `wasResting` local
  was only used to pick `status`; `phase` is carried verbatim, so dropping it is safe. ✓

**Audio coordinator (`BreathSoundCoordinator`)** — the subtle part. Block 3 moved from status-keyed
to lifecycle-keyed; the breath↔rest transition (no longer a lifecycle change) is absorbed by the
existing phase-keyed block 4. I traced start / resume / pause / complete / breath-phase-shift /
breath→rest→newCycle and every looper call (`crossfadeTo` / `fadeIn(200)` / `fadeOut(200)` /
`fadeOut(500)`) and its duration matches the old behavior. The `allowTick` rewrite
(`notStarted || paused || (running && phase == rest)`) matches the old
`pause || rest || (breath && phase == rest)`. ✓

**Screen / timeline:** `isPaused = lifecycle != running` (after the `completed` early-return) ≡ old
`status == pause`. `BreathTimelineWidget.lifecycle` is nullable and `isPausedOrComplete` enumerates
`paused || notStarted || completed`, preserving the original null→false default. ✓

## Test migration

The golden-master (`breath_activity_boundary_characterization_test.dart`) per-site `pause` values
are correct: `notStarted` for the initial emission (L73), the post-`restartEngine` fresh state
(L172), and the never-resumed case (L211); `paused` only for the real post-`resume()` pause (L106).
The state-channel helper (`breath_module_state_channel_test.dart`) was rewritten to take `lifecycle`
+ `phase` directly, and every call site carries its `phase:` verbatim — the deliberate "rest status
carrying `phase: exhale`" case (now `lifecycle: running, phase: exhale`) still asserts `'exhale'`.
Equality-test full-constructor sites correctly use `lifecycle: a.lifecycle` against a `running` base.

## Notes (non-blocking, no action required)

- **Audio: unmute-during-rest is marginally *more* correct now.** In the old code, on the single
  rest-entry emission `_currentPhase` still held the prior breath phase (e.g. `exhale`), so an unmute
  landing in that one-tick window would resume the exhale loop during a (silent) rest. The new block-4
  path sets `_currentPhase = rest` on that same transition, so unmute correctly stays silent. This is
  an edge-case improvement, not a regression — behavior is otherwise identical.

## Conclusion

No bugs, security issues, or correctness problems found. The change is behavior-preserving and
representation-only as intended; all enumerated emit sites, consumers, and tests were migrated with
no remaining reference to `BreathSessionStatus` or `.status` anywhere in `packages/` or `lib/`.

REVIEW_PASS
