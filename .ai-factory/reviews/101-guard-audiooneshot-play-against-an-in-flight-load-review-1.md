# Review: Guard `AudioOneShot.play()` against an in-flight `load()`

**Scope:** `packages/mind_audio/lib/src/audio_one_shot.dart` (1 file changed)

## Change summary
- Added `bool _loading = false;` field.
- `load()` sets `_loading = true` before `await _player.setAudioSource(source)` and resets it in a `finally`.
- `play()` returns early when `_loading` is `true`.

## Correctness analysis

**The guard closes the race correctly.** Dart runs on a single-threaded event loop. `load()` sets `_loading = true` synchronously *before* its only suspension point (`await setAudioSource`), and `play()` reads `_loading` synchronously before its own first await. There is no interleaving window where `play()` can observe `_loading == false` while `setAudioSource` is mid-flight. This is exactly the window exploited by the caller: in `BreathSoundCoordinator._onStateChanged` (line 167-174) a tick-source change fires `_oneShot.load(src)` inside an unawaited future, while `_onTick` (line 234) calls `_oneShot.play()` concurrently. ✓

**`finally` placement is correct.** The flag clears even if `setAudioSource` throws, so a failed load cannot permanently wedge `play()` into a no-op state. ✓

**No public API change, no caller change.** Signatures of `load`/`play`/`stop`/`dispose` are unchanged; the four call sites in `BreathSoundCoordinator` (lines 106, 117, 127, 153, 172, 234) need no modification. Matches the spec's guard constraints. ✓

**Behavior trade-off is as specified.** A tick that fires during the brief buffer swap is silently dropped. The spec explicitly accepts this ("dropping a single tick during the brief buffer swap is acceptable"), and `_onTick` already drops ticks via the `allowTick` gate, so a dropped tick is a benign, already-tolerated outcome. ✓

## Non-blocking observation (informational, out of scope)

If two `load()` calls overlap (e.g. two rapid tick-source toggles), the first call's `finally` sets `_loading = false` while the second `setAudioSource` may still be in flight, briefly re-opening the guard. This is a narrow, pre-existing concern: the caller comment notes the tick source is "stable within a session," so back-to-back loads are not expected in practice, and the spec deliberately scopes the fix to a single boolean. No action required for this milestone.

REVIEW_PASS
