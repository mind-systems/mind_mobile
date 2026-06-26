# Plan: Re-tether breath screen audio to `isLive`

## Context
Stop a not-started or completed breath session from playing `tick_clock.ogg` in the background by re-adding a `WidgetsBindingObserver` to `BreathSessionScreen` that suspends/resumes the sound coordinator, gated on the local `BreathSessionState.isLive` signal (note 05). Active and manually-paused sessions stay audible in the background; running sessions are never auto-paused.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Lifecycle gating

- [x] **Task 1: Add `WidgetsBindingObserver` to the breath session screen state**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Add `WidgetsBindingObserver` to the `with` clause of `_BreathSessionScreenState` (it already mixes in `TickerProviderStateMixin`). Register the observer in `initState` via `WidgetsBinding.instance.addObserver(this)` and remove it in `dispose` via `WidgetsBinding.instance.removeObserver(this)` **before** the existing coordinator/controller disposals and `super.dispose()`. Follow the exact idiom already used in `packages/breath_module/lib/src/BreathSessionConstructor/BreathSessionConstructorScreen.dart` (`addObserver(this)` in `initState`, `removeObserver(this)` first in `dispose`).

- [x] **Task 2: Implement `didChangeAppLifecycleState` gated on `isLive`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Override `didChangeAppLifecycleState(AppLifecycleState state)`. Behavior:
  - `AppLifecycleState.paused`: read `ref.read(breathViewModelProvider).isLive`; if `!isLive`, call `_soundCoordinator.suspend()`. Do nothing when `isLive` (active or manual-pause sessions stay audible in the background).
  - `AppLifecycleState.resumed`: call `_soundCoordinator.resume()` unconditionally (a no-op resume on a never-suspended coordinator just clears `_isSuspended`, which is already `false`).
  - Ignore other lifecycle values (`inactive`, `detached`, `hidden`).
  `suspend()` / `resume()` already exist on `BreathSoundCoordinator` (`Audio/BreathSoundCoordinator.dart:136/141`); `suspend()` sets `_isSuspended`, read by the `_onTick` early-return at `:198`. Do not modify `BreathSoundCoordinator`.

## Constraints (do not violate)
- Do **NOT** re-add Phase 51's running-session auto-`pause()` — a running session must survive the device lock and keep playing.
- Only the not-started and completed cases (`!isLive`) suspend audio; active and manually-paused sessions (both `isLive`) keep playing in the background.
- Do **NOT** touch the foreground service, biometrics, state machine, tick sources, or `BreathSoundCoordinator` internals beyond calling the existing `suspend()` / `resume()`.
- Meditation tracking is untouched.
- Single commit: "Re-tether breath screen audio to isLive lifecycle gate".
