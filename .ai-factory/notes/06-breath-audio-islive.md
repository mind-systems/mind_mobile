# Re-tether breath screen audio to isLive (supersedes Phase 56 / note 162) (T4)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- Phase 56 / [[162-breath-audio-bounded-to-live-session]] fixes the same bug (a **not-started** breath screen keeps playing `tick_clock.ogg` in the background) but keys off `BreathModuleStateChannel.isSessionLive` (`_started && !_ended`) bridged into the package via a `bool Function()` on `attachModuleChannel`. Once [[167-breath-derive-lifecycle-islive]] lands, the canonical local signal is `BreathSessionState.isLive` — re-point the gate to it instead of threading a server-adapter getter through the module boundary.
- Note 162's `_started && !_ended` is **server-session-derived** (flips on `_channel.start`/`_channel.end`); `isLive` from [[167]] is **local/offline** (derived from `status`+`_hasStarted`) — strictly better for the offline-locked-device case.

## Details

Re-add `WidgetsBindingObserver` to `BreathSessionScreen` (mechanism per note 162), but the discriminator becomes `ref.read(breathViewModelProvider).isLive` — read off state, no callback bridge:
- on `AppLifecycleState.paused`: `if (!isLive) _soundCoordinator.suspend();`
- on `AppLifecycleState.resumed`: `_soundCoordinator.resume();`

`suspend()` / `resume()` already exist (`Audio/BreathSoundCoordinator.dart:136/141`, dead code left by Phase 51); `suspend()` sets `_isSuspended`, read by the `_onTick` early-return (`:198`). Remove the observer in `dispose` before `super.dispose()`.

## Guards

- Do **NOT** re-add Phase 51's running-session auto-`pause()` — a running session must survive the lock.
- Active **and** manual-pause stay alive in background (both `isLive`); only not-started / completed background → suspend.
- Don't touch FGS / biometrics / state machine / tick sources / `BreathSoundCoordinator` internals beyond calling `suspend`/`resume`. Meditation untouched.
- **Supersedes** [[162-breath-audio-bounded-to-live-session]] / Phase 56: if 162 ships first, this re-points its gate from the channel getter to `isLive`; if this ships first, drop Phase 56. Prune Phase 56 from the roadmap once this is chosen.

## Verify

- Not-started screen → background → tick stops; foreground → resumes.
- Active / manual-pause → background → audio continues; complete → background → silent. (Same table as note 162's verify.)
