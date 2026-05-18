# Plan: Fix two crossfade bugs: hung `play()` on first cycle and late crossfade start

## Context
Two interacting bugs in `BreathSoundCoordinator._switchToPhase` cause silent odd-numbered cycles and a late-starting crossfade: (1) `await inactive.play()` can hang for the entire phase when a newer `_switchToPhase` invocation issues `seek()` on the same player mid-`play()`, leaving `_activeLoop` stale and producing no sound; (2) both fades currently start only after `await seek()` returns (~150–270ms after the phase change), so the outgoing player stays at full volume during the seek latency and the crossfade audibly begins late into the new phase.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Stop awaiting `play()` so the active/inactive swap always completes (Bug 1)

- [x] **Task 1: Replace `await inactive.play()` with `unawaited(inactive.play())` in `_switchToPhase`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_switchToPhase` (around line 227) change:
  ```dart
  await inactive.play();
  ```
  to:
  ```dart
  unawaited(inactive.play());
  ```
  The preloaded ExoPlayer pipeline begins producing audio within milliseconds after `seek()` returns; there is no need to suspend the async method until `play()`'s Future resolves. This removes the window during which a second `_switchToPhase` invocation can clobber the same player via `seek()` while the first is still suspended inside `await play()` — that race is what hangs the first `play()` Future until dispose (~36s later, as confirmed by the `play() done gen=1 BAIL` log timing). After this change the active/inactive reference swap (`_activeLoop = inactive; _inactiveLoop = active;`) runs synchronously right after `seek()` completes, so by the time the next phase change fires, `_inactiveLoop` already points at the formerly-active player and the next `_switchToPhase` operates on a different player than the previous one.
  Keep the existing `if (kDebugMode) debugPrint(... 'play() done — swapping active↔inactive')` log line immediately after the `unawaited(inactive.play())` call; rename its message from `play() done` to `play() dispatched` so the log accurately reflects fire-and-forget semantics.
  Do NOT change the two `if (gen != _switchGen) ... BAIL` / `if (_currentStatus != BreathSessionStatus.breath) ... BAIL` guards that appear after the swap — they remain valid and useful.

### Phase 2: Start the outgoing fade before `seek()` so the crossfade straddles seek latency (Bug 2)

- [x] **Task 2: Move the outgoing-player fade-out to fire immediately on `_switchToPhase` entry** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Inside `_switchToPhase`, after the early-return guards (`_phaseAssets[phase] == null`, `active == null || inactive == null`, `index == -1`) and the local `active` / `inactive` captures, but BEFORE `await _loadFuture`, BEFORE `await inactive.setVolume(0.0)`, and BEFORE `await inactive.seek(...)`, start the outgoing fade synchronously on the captured `active` reference:
  ```dart
  _fadePlayer(active, 0.0, fadeDuration);
  ```
  Use the local `active` variable captured at the top of the method (not `_activeLoop`) so that even if a concurrent invocation swaps `_activeLoop` mid-await, this fade still targets the correct (outgoing) player. Add a debug log alongside it, e.g. `'_switchToPhase($phase) gen=$gen  fading old-active=${active == _loopPlayerA ? "A" : "B"} → 0.0 (early)  dur=${fadeDuration.inMilliseconds}ms'`.

- [x] **Task 3: Remove the old-active fade from the post-swap block, keep only the incoming fade-in** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  After the active/inactive swap and the two post-swap guards (`gen` mismatch, `_currentStatus != breath`), the current code calls:
  ```dart
  _fadePlayer(_activeLoop!, 1.0, fadeDuration);
  _fadePlayer(_inactiveLoop!, 0.0, fadeDuration);
  ```
  Delete the second line (`_fadePlayer(_inactiveLoop!, 0.0, fadeDuration);`) — the outgoing fade is now started at the top of the method in Task 2. Keep the first line (`_fadePlayer(_activeLoop!, 1.0, fadeDuration);`), which now starts the incoming fade-in right after `seek()` + `unawaited(play())` complete. Update the surrounding debug log accordingly (e.g. drop the `old-active→0.0` half) so the message reflects that only the incoming fade is fired here.

### Phase 3: Verify the new flow

- [x] **Task 4: Re-read `_switchToPhase` end-to-end and confirm the order of operations** (depends on Task 3)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Walk the method top-to-bottom and confirm the final order is:
  1. `++_switchGen`, capture `active` / `inactive` locals, early-return guards.
  2. `_fadePlayer(active, 0.0, fadeDuration)` — outgoing fade starts immediately (Task 2).
  3. `await _loadFuture` (cold-start guard) and `gen` / `status` BAIL checks.
  4. `_cancelFadeFor(inactive)`, `await inactive.setVolume(0.0)`, `await inactive.seek(...)`.
  5. `unawaited(inactive.play())` (Task 1) — no `await`.
  6. Swap: `_activeLoop = inactive; _inactiveLoop = active;`.
  7. Post-swap `gen` / `status` BAIL checks.
  8. `_fadePlayer(_activeLoop!, 1.0, fadeDuration)` — incoming fade-in only (Task 3).
  Also confirm:
  - `_cancelFadeFor(inactive)` still runs before `setVolume(0.0)` on the incoming player so any stale fade timer on it is cleared.
  - The early outgoing fade in step 2 does NOT get cancelled by `_cancelFadeFor(inactive)` in step 4, because `inactive` and `active` are different players and `_fadeTimerA` / `_fadeTimerB` are tracked separately per player.
  - No other call sites or tests reference the old behaviour (awaiting `play()`); if any test double or fake mirrored the awaited semantics, update it to match the fire-and-forget contract.
