# Plan: Crossfade between breathing phases via ping-pong loop players

## Context
Eliminate the silence gap at every breathing phase transition by replacing the single `_loopPlayer` (fade-out → fade-in on the same player) with two ping-pong players (`_loopPlayerA` / `_loopPlayerB`) so the outgoing phase can fade down while the incoming phase fades up simultaneously.

`_currentPhase` continues to track the **active** player (the one currently playing or fading in). It is updated in `_onStateChanged` before `_switchToPhase` runs, so subsequent status-change and step-5 branches still target the correct phase via `_activeLoop`. The plan does not change that contract.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Player wiring

- [x] **Task 1: Replace single loop player with A/B pair and active/inactive references**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Remove the `AudioPlayer? _loopPlayer` field and add `AudioPlayer? _loopPlayerA`, `AudioPlayer? _loopPlayerB`, `AudioPlayer? _activeLoop`, `AudioPlayer? _inactiveLoop`. Keep `_tickPlayer`, `_tickSub`, `_currentTickSource`, `_stateListener`, `_currentPhase`, `_currentStatus`, `_switchGen`, `_loadFuture` unchanged. The `_fadeTimer` field is no longer per-coordinator — replace with two timers `Timer? _fadeTimerA` and `Timer? _fadeTimerB` so each player can fade independently. Phase assets, phase order, tick assets stay as-is.

- [x] **Task 2: Initialize both players in `initialize()` and await both preloads via `_loadFuture`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `initialize()`, guard with `if (_loopPlayerA != null) return;`. Construct both `AudioPlayer` instances, call `setLoopMode(LoopMode.one)` and `setVolume(0.0)` on each (unawaited). Build the source list once (`_phaseOrder.map((p) => AudioSource.asset(_phaseAssets[p]!)).toList()`).
  Fire `setAudioSources(sources, preload: true)` on **both** players in parallel and assign `_loadFuture` so it covers **both** preloads, not just A's:
  ```dart
  _loadFuture = Future.wait<void>([
    _loopPlayerA!.setAudioSources(sources, preload: true),
    _loopPlayerB!.setAudioSources(sources, preload: true),
  ]).then((_) {});
  unawaited(_loadFuture!);
  ```
  The trailing `.then((_) {})` preserves the existing `Future<void>? _loadFuture` field type — do **not** widen the field to `Future<List<void>>?`. This is the must-fix from review issue #1: the very first `_switchToPhase` targets `_inactiveLoop` (= `_loopPlayerB` initially), so the cold-start guard inside `_switchToPhase` (which awaits `_loadFuture`) must block until B has finished `setAudioSources` too, or the slow-Android cold-start protection from roadmap item 12.7 regresses.
  Set `_activeLoop = _loopPlayerA` and `_inactiveLoop = _loopPlayerB`. Tick player initialization and listener wiring are unchanged.

### Phase 2: Fade and switch logic

- [x] **Task 3: Replace `_fadeTo` with player-aware `_fadePlayer` and add a `_cancelFadeFor(player)` helper**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Remove `_fadeTo(double target, Duration duration)`. Add:
  - `void _cancelFadeFor(AudioPlayer player)` — if `player == _loopPlayerA`, cancel `_fadeTimerA` and set it to null; otherwise cancel `_fadeTimerB` and set it to null. Used by both `_fadePlayer` and `_switchToPhase` (Task 4) so the inactive player's prior fade timer can be killed before its volume is reset.
  - `void _fadePlayer(AudioPlayer player, double target, Duration duration)` — calls `_cancelFadeFor(player)` first (so it cancels only its own slot, never the other player's), then captures `startVolume = player.volume`, computes `steps = max(1, duration.inMilliseconds ~/ 16)`, and starts a 16ms `Timer.periodic` that writes `startVolume + (target - startVolume) * t`. Store the timer in the matching `_fadeTimerA` / `_fadeTimerB` slot by identity. Inside the periodic, on the final tick set the slot back to null. Do not touch the other player's timer — simultaneous independent fades are the whole point.

- [x] **Task 4: Rewrite `_switchToPhase` to crossfade between active and inactive players** (depends on Tasks 1–3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Keep the generation guard (`final gen = ++_switchGen;`) and the early-return checks (`_phaseAssets[phase] == null`, `_loadFuture` await, `gen != _switchGen`, `_currentStatus != BreathSessionStatus.breath`). Capture `_activeLoop` / `_inactiveLoop` into local `active` / `inactive` vars and bail if either is null. Look up `final index = _phaseOrder.indexOf(phase);` and bail on `-1`.
  **Before** `setVolume(0.0)` on the inactive player, call `_cancelFadeFor(inactive)` to kill any pending fade timer the inactive player carries from when it was previously the outgoing active (must-address from review issue #2 — without this, a leaked 16ms tick can overwrite volume back above 0 between `setVolume(0.0)` and the start of the fade-up, so the new phase pops in at a non-zero baseline).
  Then: `await inactive.setVolume(0.0); await inactive.seek(Duration.zero, index: index); await inactive.play();`. Re-check gen and status after each await chain.
  Fire both fades concurrently with `const Duration(seconds: 2)` (1–2s window — pick 2s to match the previous step-5 spec) via `_fadePlayer(active, 0.0, duration)` and `_fadePlayer(inactive, 1.0, duration)`. Immediately after dispatching both fades (fire-and-forget, do **not** await the timers), swap references: `_activeLoop = inactive; _inactiveLoop = active;` so the next phase switch acts on the now-fading-out player as the next inactive target.

- [x] **Task 5: Update `_onStateChanged` callers to use new fade entry points** (depends on Task 4)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Replace every `_fadeTo(...)` call site with the player-aware variant on `_activeLoop` (each call site must null-check `_activeLoop` first — skip the fade if null, mirroring how the old code skipped when `_loopPlayer == null`):
  - Status `pause` branch → `_fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 200))`.
  - Status `breath` else branch (same phase resume) → `_fadePlayer(_activeLoop!, 1.0, const Duration(milliseconds: 200))`.
  - Status `complete` / `rest` branches → `_fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 500))`.
  - Phase-changed branch with no asset (rest) → `_fadePlayer(_activeLoop!, 0.0, const Duration(milliseconds: 500))`.
  - Step-5 end-of-phase fade-out → `_fadePlayer(_activeLoop!, 0.0, Duration(milliseconds: intervalMs))` — only the active player, never the inactive one (fading the inactive would mute the incoming phase).

### Phase 3: Lifecycle

- [x] **Task 6: Update `reset()` to stop and zero both players and restore A/B roles** (depends on Tasks 1–5)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Cancel both `_fadeTimerA` and `_fadeTimerB`, set them to null. For each of `_loopPlayerA` and `_loopPlayerB` (if non-null): unawaited `stop()` and unawaited `setVolume(0.0)`. Reset `_activeLoop = _loopPlayerA` and `_inactiveLoop = _loopPlayerB` to the initial pairing. Tick player stop and `_currentPhase`/`_currentStatus` null-out remain unchanged.
  Note: an in-flight `_switchToPhase` may still be awaiting `_loadFuture` or sitting between awaits when `reset()` runs; the existing `_currentStatus != BreathSessionStatus.breath` re-check inside `_switchToPhase` continues to cover that case because `reset()` nulls `_currentStatus`. No new guards needed.

- [x] **Task 7: Update `dispose()` to dispose both players** (depends on Tasks 1–6)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Cancel `_tickSub` and both fade timers. Call the stored `_stateListener`. Null out `_loopPlayerA`, `_loopPlayerB`, `_activeLoop`, `_inactiveLoop` before dispatching unawaited `dispose()` on each captured non-null player reference (mirroring the existing pattern that captures the reference, nulls the field, then disposes). Tick player disposal stays unchanged.

## Out of scope (review issues #3, #4, #6 — non-blocking)
- **Pausing the outgoing player after a completed fade-to-0** (review issue #3 — decoder CPU waste on Android). Could be wired by passing an optional `onComplete` callback to `_fadePlayer` and calling `unawaited(player.pause())` for the outgoing branch. Left out of this milestone — strictly an optimization; functionally the silenced player is harmless. Track separately if profiling justifies it.
- **`_loadFuture` type drift** (review issue #4) is resolved inline in Task 2 by the `.then((_) {})` chain.
- **Reset-during-crossfade safety** (review issue #6) is covered by the existing `_currentStatus` re-check inside `_switchToPhase`, as noted in Task 6.

## Commit Plan
- **Commit 1** (after tasks 1–3): "Add ping-pong loop players and per-player fade driver in BreathSoundCoordinator"
- **Commit 2** (after tasks 4–5): "Crossfade between breathing phases on phase switch"
- **Commit 3** (after tasks 6–7): "Reset and dispose both loop players in BreathSoundCoordinator lifecycle"
