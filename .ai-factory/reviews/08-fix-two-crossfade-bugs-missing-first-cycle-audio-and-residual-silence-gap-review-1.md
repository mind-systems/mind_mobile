# Code Review: Fix two crossfade bugs: missing first-cycle audio and residual silence gap

**Plan:** `.ai-factory/plans/08-fix-two-crossfade-bugs-missing-first-cycle-audio-and-residual-silence-gap.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk level:** 🟢 Low

## Scope verified

`git status` / `git diff HEAD` show only `BreathSoundCoordinator.dart` modified plus staged plan / plan-review docs and the `ROADMAP.md` entry. No proto, DB, l10n, or other Dart source touched. All five plan tasks marked done. I re-read the full coordinator (248 lines) and validated each change against the diff and the milestone description.

## Diff summary

1. **`initialize()`** — unchanged. Already used `Future.wait` over both players (introduced in commit `c0b2c28`). Task 1 is correctly a no-op verification.
2. **`_onStateChanged`** —
   - Step 3 / `BreathSessionStatus.breath` branch (lines 142–143): now computes `intervalMs` and passes `Duration(milliseconds: intervalMs)` into `_switchToPhase`.
   - Step 4 / phase-change branch (lines 158–159): same change.
   - Step 5 block deleted (was lines 165–170 of HEAD).
3. **`_switchToPhase`** — new signature `(BreathPhase, Duration fadeDuration)`; the old `const duration = Duration(seconds: 2)` removed; both `_fadePlayer(...)` calls now use `fadeDuration` (lines 209–210). All guards (`_loadFuture` await, `gen != _switchGen`, `_currentStatus != breath`) retained.

## Correctness trace

**Bug 1 — first-cycle silence.** Already fixed: `_loadFuture` (lines 58–61) wraps both `setAudioSources` calls via `Future.wait`. The `await _loadFuture` at line 196 in `_switchToPhase` thus guarantees both players' playlists are loaded before the very first `seek` on `_inactiveLoop` (player B). No remaining exposure. ✓

**Bug 2 — residual silence gap.**
- Old timeline: step-5 faded `_activeLoop` to 0 over `intervalMs` during the LAST tick of the current phase → at the phase boundary the active was already silent → `_switchToPhase` then fired `play()` on the inactive and started a 2 s fade-in → audible gap until the Android pipeline flush completed.
- New timeline: at the phase boundary, active is still at full volume; `_switchToPhase` issues `play()` on inactive (vol 0), commits the swap, then fires both fades concurrently over `fadeDuration` (≈ `intervalMs`, ~1 s). The outgoing audio (now `_inactiveLoop`) is still audible while the incoming ramps up — no overlap window of silence.

Verified the swap order (lines 205–206) is consistent with the fade targets on 209–210:
- `_activeLoop` (post-swap) = incoming player → fades 0 → 1 ✓
- `_inactiveLoop` (post-swap) = outgoing player → fades 1 → 0 ✓

**Pause-mid-switch.** Both guards before the fades (`gen != _switchGen` and `_currentStatus != breath`) are unchanged from the v2 review of milestone 07. The fixed behavior (swap commits BEFORE the second guard, so a pause that arrives in the post-`play()` window leaves `_activeLoop` pointing at the new player) is preserved. ✓

**First emit safety.** When `_currentPhase == null` and the first state arrives with `status = breath`, step 3's breath branch fires `_switchToPhase(state.phase, Duration(milliseconds: intervalMs))`. `BreathSessionState.dart:66` initializes `currentIntervalMs = -1`, so the `> 0 ? : 1000` fallback substitutes 1000 ms. The state machine subsequently emits real interval values (`BreathSessionStateMachine.dart:276/313/341/371`). ✓

**Rest/no-asset phases.** Step 4's `else` branch (line 161) and step 3's pause/complete/rest branches still fade `_activeLoop` to 0 directly. These do NOT call `_switchToPhase`, so the fadeDuration parameter is irrelevant there. Matches the milestone scope. ✓

**Tick interval semantics.** Confirmed via `BreathSessionStateMachine.dart:276/313/341/371` that `currentIntervalMs` is the per-tick interval (≈1000 ms for `TickSource.timer`, variable for `TickSource.heartbeat`). The crossfade is therefore one tick long. That matches the milestone's stated intent ("`fadeDuration` derived from `state.currentIntervalMs`") and the perceptual goal of bleeding the outgoing phase ~1 s into the new one.

**No external callers of `_switchToPhase`.** Method is private (`_`-prefixed, library-scoped). `grep` of the repo shows the only Dart references are inside `BreathSoundCoordinator.dart` (definition + the two call sites in `_onStateChanged`). No test doubles, no other usages. The signature change cannot break callers outside this file. ✓

## Findings

### Minor — Outgoing fade is now ~1 s shorter than the previous design's combined fade

Old behavior: step-5 faded the outgoing loop over `intervalMs` (~1 s) STARTING one tick before the boundary, then `_switchToPhase` faded the incoming over a const 2 s after the boundary. So a phase change had effectively a ~1 s outgoing decay + a 2 s incoming rise, partially serial.

New behavior: both fades run for `fadeDuration` (~1 s) STARTING at the boundary, in parallel. The incoming rise is now ~1 s instead of 2 s. This is what the milestone specifies, but worth noting: the new attack on the incoming loop is twice as fast as before. If a future tuning pass wants a softer onset, the parameter is well-localized — change the call-site duration calculation, not the coordinator internals.

This is a deliberate behavior change per the milestone, not a bug.

### Minor — Outgoing player never paused after fade-out completes

After fade-out, `_inactiveLoop` continues looping the old phase asset at volume 0 (no `pause()`/`stop()` call). On the next switch, `_cancelFadeFor(inactive)` + `setVolume(0)` + `seek(0, index)` + `play()` is sequenced; `play()` on an already-playing player is a documented no-op in just_audio. No correctness issue. Slight CPU/decoder waste, identical to behavior on the master branch and to milestone 07's accepted design. No action required.

### Minor — Step-numbering comment in `_onStateChanged` now jumps 1, 2, 3, 4 (no 5)

The block comment "5. End-of-phase fade-out trigger" was removed cleanly. Surviving comments are 1–4, which is internally consistent. The plan flagged this as "not required" and the implementation chose not to renumber. Acceptable.

## Positive notes

- Implementation faithfully matches the plan's task list, in the order described.
- Type signatures and call sites stay consistent — no leftover single-argument `_switchToPhase` references anywhere in the repo.
- Per-player fade timer accounting (`_fadeTimerA` / `_fadeTimerB` via `_cancelFadeFor`) is untouched, so the two concurrent fades on different players cannot stomp each other's timers. Concurrency of the fades is genuinely independent. ✓
- Plan review (`plan-review-1.md`) correctly anticipated Task 1's no-op nature and the intentional shortening of the crossfade duration. The implementer respected that guidance.
- Diff is minimal and surgical: 3 hunks, ~15 lines net change, all in one file.

## Recommendation

No code changes required. The implementation is correct, matches the milestone, and preserves all guards established in earlier milestones. Suitable for the implementer to mark the milestone `[x]` in `ROADMAP.md`.

REVIEW_PASS
