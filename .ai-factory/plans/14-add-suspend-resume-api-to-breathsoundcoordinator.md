# Plan: Add `suspend()` / `resume()` API to `BreathSoundCoordinator`

## Context
Add a zero-behavior-change API surface on `BreathSoundCoordinator` so an upcoming background-handling task can mute tick playback while the app is not visible. This milestone only introduces the fields, methods, and the early-return guard in `_onTick()`; no callers are added.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: API surface

- [x] **Task 1: Add `_isSuspended` field and `suspend()` / `resume()` methods to `BreathSoundCoordinator`**
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  Inside the `BreathSoundCoordinator` class, alongside the existing `_fadeTimerA` / `_fadeTimerB` private fields (around lines 29–30), declare a new private field:
  ```dart
  bool _isSuspended = false;
  ```
  Then add two new public methods to the class (place them after `dispose()` and before `_onStateChanged()`, so the public lifecycle API stays grouped):
  - `void suspend()` — sets `_isSuspended = true` and immediately cuts any currently-playing tick by calling `unawaited(_tickPlayer?.stop())`. Must NOT cancel `_tickSub` (the stream subscription stays alive so `_onTick()` keeps being called) and must NOT touch `_loopPlayerA` / `_loopPlayerB` / `_activeLoop` / `_inactiveLoop` (loop audio is handled separately by the session-layer auto-pause introduced in the next milestone).
  - `void resume()` — sets `_isSuspended = false`. No other work: the next `viewModel.tickStream` event will reach `_onTick()` and behave normally.
  Both methods should be idempotent (calling `suspend()` twice is a no-op beyond re-issuing `_tickPlayer?.stop()`; calling `resume()` when not suspended is a no-op). Match the existing code style: no trailing commas on single-argument calls, use `unawaited(...)` for fire-and-forget `Future`s, follow the surrounding 2-space indentation.

- [x] **Task 2: Add suspended guard at top of `_onTick()`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
  In `_onTick()` (currently lines 215–225), insert `if (_isSuspended) return;` as the very first statement of the method body — before the `allowTick` computation and before the existing `kDebugMode` `debugPrint`. Do not modify any other line of `_onTick()`. The intent: when suspended, the method returns immediately without computing `allowTick`, without logging, and without touching `_tickPlayer`. Since `_isSuspended` defaults to `false` and no caller flips it yet, this is a zero-behavior-change addition.

## Commit Plan

Single commit at the end (only 2 tightly-coupled tasks).
