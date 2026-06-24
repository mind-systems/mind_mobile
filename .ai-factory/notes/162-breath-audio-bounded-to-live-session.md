# Bound breath screen audio to a live module session (fix the background tick leak)

> **SUPERSEDED** by [[168-breath-audio-islive]]. Same bug and same fix, but the gate moves from this note's server-derived `BreathModuleStateChannel.isSessionLive` (`_started && !_ended`, bridged via an `attachModuleChannel` callback) to the **local/offline** `BreathSessionState.isLive` (see [[167-breath-derive-lifecycle-islive]]). Kept as historical context for the mechanism (`WidgetsBindingObserver` re-add, `suspend`/`resume` reuse).

**Date:** 2026-06-23
**Source:** conversation context

## Key Findings

- **The regression is in breath SCREEN AUDIO only.** Process keep-alive (Android FGS) and biometric streaming are *already* correctly bounded to the live module-session window (start → end/abandon, manual pause included). The only thing that escaped that window is the breath screen's tick audio.
- **Root cause.** Phase 51 commit `5924589` removed `BreathSessionScreen.didChangeAppLifecycleState` wholesale (to let a *running* session survive the lock). That handler used to call `_soundCoordinator.suspend()` on background. With it gone, nothing suspends the tick one-shot anymore.
- **Why it ticks when "not started".** `BreathSessionStateMachine` starts in `status = pause` (`packages/breath_module/lib/src/BreathSession/BreathSessionStateMachine.dart:118,142`), and `BreathSoundCoordinator._onTick` `allowTick` includes `pause` (`Audio/BreathSoundCoordinator.dart:200-204`). The clock (`ClockTickService..simulateTick()`) starts at module build (`lib/BreathModule/BreathModule.dart:32`), so it ticks from screen-open. Result: a not-started breath screen plays `tick_clock.ogg` every second — and now keeps doing so in the background.
- **The correct discriminator is the live module session, NOT the local `status`.** "Not started" and "manual pause" are *both* `status == pause`. Only the module session distinguishes them: not-started has no live session; manual pause is inside a live session (biometrics still flow, FGS still up).
- **The package cannot see the module session directly** — `breath_module` cannot import `lib/`. The live-session signal must be bridged from `BreathModuleStateChannel` (lib/) into `BreathViewModel` via the existing `attachModuleChannel` wiring.

## Details

### Current state (verified)

- **FGS** — `lib/Core/Background/KeepAliveCoordinator.dart`: start on `ModuleSessionStarted`, stop on `Ended`/`Abandoned`; `Paused`/`Unpaused` ignored → FGS stays up through a manual pause. ✅ already bounded to the live session.
- **Biometrics** — `lib/Biometrics/BiometricStreamClient.dart` `_onLifecycleEvent`: `sendBatch` gated on `_currentSessionId != null && _sessionConfirmed`; set on `Started`/`Resumed`, cleared on `Ended`/`Abandoned`, `Paused` → `break` (keeps flowing). ✅ already bounded to the live session, flows through pause.
- **Meditation** — no audio; status is only `idle`/`active` (no pause); keep-alive (FGS + iOS `SilentKeepAlivePlayer`) gated on `active`. ✅ already conforms; no change needed.
- **Breath audio** — ❌ runs from screen-open to screen-dispose, ignoring both the session window and app lifecycle.

### Live-session ownership — already a derivable invariant

`lib/BreathModule/Core/BreathModuleStateChannel.dart` already tracks the live window with two bools: `bool _started = false;` (`:16`) and `bool _ended = false;` (`:17`). **No new state is needed** — "session is live" ≡ `_started && !_ended`. The existing transitions make this exactly right at every point:

| State | `_started` | `_ended` | `_started && !_ended` | Set at |
|---|---|---|---|---|
| Not started | false | false | **false** | initial (`:16`–`:17`) |
| Active / manual pause | true | false | **true** | `_started = true` at `:87` (after `_channel.start`, `:86`) |
| Complete | true | true | **false** | `_ended = true` at `:107` (after `_channel.end`, `:106`) |
| Abandoned → `reset()` | false | false | **false** | `reset()` zeroes both, `:144`–`:145`; called from the `_eventsSub` `ModuleSessionAbandoned` listener, `:45`–`:47` |
| Restart (Replay tapped at `complete`) | false | false | **false** until next play | `BreathSessionViewModel.restartEngine()` (`BreathSessionViewModel.dart:282`–`:286`) calls `_onModuleReset` = `channel.reset()` (`:144`–`:145`), then `_setupEngine` re-seeds the state machine to the initial `pause`. The next play re-enters the start branch (`:86`–`:87`) → **true** |

Server-driven `ModuleSessionEnded` (`COMPLETED`/`INTERRUPTED`) is **not** separately subscribed — the breath channel drives its own end at `complete` (`:106`), so `_ended` already covers it; do not add an `events`-listener branch for `ModuleSessionEnded`.

### Target behaviour

| Situation | App backgrounded | Audio | Keep-alive (FGS/biometrics) |
|---|---|---|---|
| Not started (initial `pause`) | yes | **suspend** (silent) | off (already) |
| Active (`breath`/`rest`) | yes | keep running | on (already) |
| Manual pause (started→`pause`) | yes | **keep running** (confirmed) | on (already) |
| Complete / ended | yes | suspend (already silent; `allowTick` excludes `complete`) | off (already) |

Foreground behaviour is unchanged — the not-started screen still ticks in foreground exactly as today; only the **backgrounded + no-live-session** case is silenced. This matches the user's report ("звук останавливался при сворачивании").

### Mechanism (pinned to source)

Use a plain `bool Function()` callback bridge — identical in shape to the existing `onDispose`/`onReset` `void Function()` callbacks on `attachModuleChannel`. This keeps `BreathModuleStateChannel` pure-Dart (no `package:flutter/...` import) and adds no mutable state or notifier lifecycle.

**1. `lib/BreathModule/Core/BreathModuleStateChannel.dart` — expose the invariant.**
Add one getter: `bool get isSessionLive => _started && !_ended;` (fields `_started` `:16`, `_ended` `:17`; see the table above for why this is correct at every transition). No new field, no `import`, no `dispose` change.

**2. Bridge through `BreathViewModel`** (`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`).
Alongside `_onModuleDispose` (`:36`) / `_onModuleReset` (`:37`), add `bool Function()? _isSessionLive;`. Change `attachModuleChannel` (`:39`–`:45`) to take a third named param `required bool Function() isSessionLive` and store it (`_isSessionLive = isSessionLive;`). Expose `bool get isSessionLive => _isSessionLive?.call() ?? false;` (null-safe default `false` guards the pre-attach window; in practice `attachModuleChannel` runs synchronously at wiring before the screen builds). Do **not** put this on `BreathSessionState` — it is read imperatively, never rendered, so it must not trigger Riverpod rebuilds. No new imports (callback type is plain Dart).

**3. Wire + consume.**
- Wiring: `lib/BreathModule/BreathModule.dart:48` is currently `vm.attachModuleChannel(onDispose: channel.dispose, onReset: channel.reset);` → add `isSessionLive: () => channel.isSessionLive`.
- `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`:
  - `:34` mixin list `with TickerProviderStateMixin` → `with TickerProviderStateMixin, WidgetsBindingObserver`.
  - `initState` (`:48`): add `WidgetsBinding.instance.addObserver(this);` immediately after `super.initState();` (`:49`).
  - `dispose` (`:113`–`:122`): add `WidgetsBinding.instance.removeObserver(this);` before `super.dispose();` (`:121`). (Removal before the provider tears the channel down means no `didChangeAppLifecycleState` can fire after `_sessionLive.dispose()`.)
  - Add the override:
    ```dart
    @override
    void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.paused) {
        if (!ref.read(breathViewModelProvider.notifier).isSessionLive) {
          _soundCoordinator.suspend();
        }
      } else if (state == AppLifecycleState.resumed) {
        _soundCoordinator.resume();
      }
    }
    ```
    `AppLifecycleState` comes from `package:flutter/material.dart` (already imported `:1`). `_soundCoordinator` is the existing field (`:39`). `ref.read(breathViewModelProvider.notifier)` returns the `BreathViewModel` (same pattern already used at `:58`,`:158`).

`_soundCoordinator.suspend()` (`:136`) / `resume()` (`:141`) already exist in `Audio/BreathSoundCoordinator.dart` — dead code left by Phase 51; reuse unchanged. `suspend()` sets `_isSuspended = true`, read by the `_onTick` early-return (`:198`); `resume()` clears it.

### Guards

- **Do NOT re-add the auto-`pause()` of a running session** that Phase 51 removed — a running session must survive the lock. The lifecycle handler now only suspends *audio*, and only when no session is live.
- Active and manual-pause are both inside the live window → audio keeps running in background.
- Do not touch FGS, biometrics, the state machine, tick sources, or `BreathSoundCoordinator` internals beyond calling the existing `suspend`/`resume`.
- Meditation untouched.

### Verify

- Open a breath session, do not press play → background → tick stops; foreground → tick resumes.
- Press play (active) → background → guidance/ticks continue (FGS holds the process); foreground → unchanged.
- Pause mid-session → background → biometrics keep flowing, FGS stays up; audio continues (live session).
- Let a session complete → background → silent, FGS down.

## Resolved Decisions

The full lifecycle, confirmed by the user — `isSessionLive` (`_started && !_ended`) is the single gate and matches it exactly:

- **Screen opened, not started** → ticks in foreground (unchanged), but **not held alive**: backgrounded → `suspend()` (no live session).
- **Started** → held alive (foreground + background audio continues).
- **Manual pause** → still held alive, still sends data, **keeps playing the tick in the background** — a pause is inside the live session; the gate is `!isSessionLive` → suspend, nothing keys off the local `pause` status.
- **Completed** → **no longer held alive**, regardless of whether any (silent) audio still plays. `complete` sets `_ended = true` (`:107`) → `isSessionLive` false, and the FGS already stops on the server `ModuleSessionEnded` it drives at `_channel.end` (`:106`).
- **Restarted (Replay)** → state machine reset to the start; `channel.reset()` zeroes `_started`/`_ended` → not held alive again until the next play. Same as a fresh not-started screen.

- **No clock-halt follow-up (open question closed).** "Holding the app alive" *is* the Android FGS (`KeepAliveCoordinator`), which is already gated on the live session and off whenever `isSessionLive` is false (not-started / complete / restart / abandoned). A Dart `Timer` (`ClockTickService`) does **not** hold the process alive once it is backgrounded without an FGS — the OS suspends the isolate and the timer with it. So the residual clock tick is a non-issue and needs no separate task; this milestone's audio gate is the whole fix.
