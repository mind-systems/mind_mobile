# Plan Review: Crossfade between breathing phases via ping-pong loop players

**Plan file:** `.ai-factory/plans/07-crossfade-between-breathing-phases-via-ping-pong-loop-players.md`
**Target file:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk level:** 🟡 Medium

## Context Gates

- **ARCHITECTURE.md**: Not directly relevant — change is localized to a single coordinator inside the `breath_module` package; no boundary crossing, no domain leakage, no new dependencies.
- **RULES.md**: PASS — `BreathSoundCoordinator` is internal to the package (not a Module Service); it owns `initialize`/`reset`/`dispose` lifecycle, which is fine. No App.dart wiring is touched.
- **ROADMAP.md**: Aligned — Phase 12 entry "Crossfade between breathing phases via ping-pong loop players" describes the same approach (`_loopPlayerA`/`_loopPlayerB`, swap references, `_fadePlayer`, step-5 active-only). The plan tracks the roadmap entry verbatim.

## Critical Issues

### 1. `_loadFuture` only awaits player A; first crossfade targets player B (ERROR)

The plan instructs (Task 2):

> Assign `_loadFuture = _loopPlayerA!.setAudioSources(sources, preload: true)` and fire `_loopPlayerB!.setAudioSources(sources, preload: true)` unawaited separately so both load in parallel.

But Task 4 has the very first `_switchToPhase` operate on `_inactiveLoop` (= `_loopPlayerB` initially):

```
await inactive.setVolume(0.0);
await inactive.seek(Duration.zero, index: index);
await inactive.play();
```

Then `await _loadFuture` only blocks until A finishes loading. If B's `setAudioSources` is still in flight when the first phase switch executes `seek(..., index: index)` on B, the call hits an unprepared player — exactly the cold-start failure mode the existing comment at line 171–176 explicitly defends against:

> guards against cold-start and resume paths on slow Android devices where setAudioSources may still be in progress.

In practice, the 15s inter-exercise rest hides this on warm devices, but the guarantee is gone for slow Android cold starts. The roadmap entry says "both load in parallel and are ready before the first phase switch" — that's an assertion, not a guarantee, because B's preload Future is never awaited.

**Fix:** widen `_loadFuture` to cover both, e.g.:

```dart
_loadFuture = Future.wait<void>([
  _loopPlayerA!.setAudioSources(sources, preload: true),
  _loopPlayerB!.setAudioSources(sources, preload: true),
]);
```

(or store two futures and await both inside `_switchToPhase`). The plan should explicitly call this out — otherwise Task 2 reproduces the bug class fixed in roadmap item 12.7.

### 2. Inactive player's prior fade timer can clobber the volume floor before the new fade-up starts (WARN)

After the swap, what was the active fading out becomes the next inactive. On the next phase switch:

1. `_switchToPhase` runs `await inactive.setVolume(0.0)` — but the inactive player's previous fade timer (set when it was the outgoing active in the prior swap) is **not** cancelled by Task 4.
2. During the awaits between `setVolume(0.0)` and the dispatch of `_fadePlayer(inactive, 1.0, 2s)`, the prior periodic timer can fire one or more 16 ms ticks and overwrite the volume back to its interpolated value.
3. `_fadePlayer` captures `startVolume = player.volume` **after** cancelling its own timer — so the new fade-up starts from whatever the leaked tick set, not from 0.

Audible result: the incoming phase may "pop in" at a non-zero baseline instead of fading cleanly from silence. Not catastrophic, but undermines the whole point of the change.

**Fix:** in Task 4, before `await inactive.setVolume(0.0)`, cancel the inactive player's fade timer explicitly:

```dart
// pseudo
if (_inactiveLoop == _loopPlayerA) { _fadeTimerA?.cancel(); _fadeTimerA = null; }
else { _fadeTimerB?.cancel(); _fadeTimerB = null; }
```

Or, more cleanly, have `_fadePlayer` expose / share a private "cancel fade for player X" helper and call it from `_switchToPhase` before touching `inactive.volume`.

## Minor Issues / Suggestions

### 3. Outgoing player is never `stop()`ped after fade-out (INFO)

After the 2s crossfade completes, the now-inactive player keeps looping at volume 0.0 forever (until the next switch uses it again). Harmless functionally, but wastes decoder CPU/battery on Android. Consider scheduling a one-shot `stop()` (or `pause()`) once the fade-to-0 completes, e.g. by passing an optional `onComplete` to `_fadePlayer` and calling `unawaited(player.pause())` for the outgoing branch. Not blocking, but worth mentioning in the plan.

### 4. `_loadFuture` type drift (INFO)

If you adopt the fix for Issue 1 via `Future.wait<void>([...])`, the field type changes from `Future<void>?` to `Future<List<void>>?`. Either widen the field to `Future<Object?>?` or chain `.then((_) {})` to keep `Future<void>?`. Tiny detail, but worth pinning in the plan to avoid a build-time surprise.

### 5. Plan does not say what to do with `_currentPhase` when the inactive becomes active (INFO)

`_currentPhase` is already updated in `_onStateChanged` before `_switchToPhase` is called, so semantically nothing changes. Worth noting in the plan that `_currentPhase` continues to track the **active** player (the one currently playing/fading in), so subsequent step-5 / status-change branches still target the right phase via `_activeLoop`. (Currently the plan is silent on this; reviewers might wonder whether the field tracks A or B.)

### 6. Reset during in-flight crossfade — interaction with both fade timers (INFO)

Task 6 cancels both `_fadeTimerA` and `_fadeTimerB` and stops/zeros both players. Good. One thing to verify in the implementation (not the plan per se): the in-flight `_switchToPhase` may be awaiting `_loadFuture` and then re-checking `_currentStatus != BreathSessionStatus.breath` — that early-return already covers the post-reset case because `reset()` sets `_currentStatus = null`. The plan keeps this guard, so this is fine; just flagging the chain holds together.

## Positive Notes

- Field decomposition is clean: keeping `_loopPlayerA` / `_loopPlayerB` as stable identities and exposing `_activeLoop` / `_inactiveLoop` as role pointers is the right model — identity-based dispatch in `_fadePlayer` works exactly because A/B don't move.
- Per-player timer slots (`_fadeTimerA` / `_fadeTimerB`) correctly enable simultaneous independent fades; the plan is explicit that `_fadePlayer` must cancel only its own timer (not the other), which prevents the obvious crossfade-cancel-itself bug.
- Task 4 keeps the existing generation guard (`++_switchGen`) and re-checks `_currentStatus == BreathSessionStatus.breath` after the awaits — preserves the rapid-switch and reset-during-switch safety established in roadmap item 12.7.
- Task 5 enumerates **every** existing `_fadeTo` call site and rewrites them to `_fadePlayer(_activeLoop!, ...)`, including the step-5 end-of-phase fade restricted to active only (correct — fading the inactive would mute the incoming phase).
- Commit plan is well-segmented (wiring → switch logic → lifecycle), each commit independently buildable.

## Verdict

Two changes are needed before this plan is ready to implement:

1. **Must fix** — Task 2 must await both players' `setAudioSources` (e.g. via `Future.wait`), not just A's, or the cold-start guard regresses for slow Android.
2. **Should fix** — Task 4 must cancel the inactive player's pending fade timer before setting its volume to 0, otherwise leaked timer ticks can set a non-zero baseline for the fade-in.

Issues 3–6 are non-blocking but worth pinning down.
