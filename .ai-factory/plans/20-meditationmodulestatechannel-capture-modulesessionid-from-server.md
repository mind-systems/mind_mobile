# Plan: MeditationModuleStateChannel — capture moduleSessionId from server

## Context
`MeditationModuleStateChannel` calls `channel.start()` but never subscribes to `channel.state`, so the server-returned `moduleSessionId` is silently discarded. This milestone captures and exposes it so a future coordinator (ROADMAP Phase 33, note-sync) can read it after `active→idle`.

**Critical timing constraint (differs from breath):** the future consumer reads `moduleSessionId` inside `MeditationSessionCoordinator.onSessionStopped()`, *after* the user dismisses the meditation note screen — seconds past the `active→idle` transition. By then the server has replied `COMPLETED`/`INTERRUPTED`, and `ModuleStateChannel._processProtoEvent` emits `ModuleState.initial()` with `moduleSessionId: null` (`lib/Core/Grpc/ModuleStateChannel.dart:135-136`). So the listener **must not** assign unconditionally (the way `BreathModuleStateChannel` does) — that would null the field exactly when the consumer needs it. Breath gets away with the unconditional assignment because it only reads the id *during* the active session (`_handleInstruction`), never after end. The assignment must be guarded with a non-null check so the last server-issued id survives the `active→idle→note-screen` window. A fresh session's `ACTIVE` reply overwrites it with a new id, so there is no cross-session staleness in the read window.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Capture moduleSessionId

- [x] **Task 1: Subscribe to channel state and expose moduleSessionId (null-guarded)**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  Single additive change to one file. Mirror the relevant parts of `BreathModuleStateChannel` (lib/BreathModule/Core/BreathModuleStateChannel.dart:5, 20, 24, 35-42, 127) — but **not** breath's unconditional listener body (see the timing constraint above; breath nulls on end and that is harmless there, fatal here). Skip breath's instruction-stream / pending logic entirely.
  - Add import: `import 'package:mind/Core/Grpc/ModuleState.dart';`
  - Add field: `String? _moduleSessionId;`
  - Add field: `late final StreamSubscription<ModuleState> _channelSub;`
  - In the constructor body (after the existing `_stateSub = stateStream.listen(_onState);`), add a **null-guarded** listener so the last non-null id is retained across the `active→idle` window:
    ```dart
    _channelSub = channel.state.listen((moduleState) {
      if (moduleState.moduleSessionId != null) {
        _moduleSessionId = moduleState.moduleSessionId;
      }
    });
    ```
    The constructor stores the channel as `_channel`, but subscribe to the `channel` constructor parameter directly (as `BreathModuleStateChannel` does) — both refer to the same instance.
  - Add getter: `String? get moduleSessionId => _moduleSessionId;`
  - In `dispose()`, add `_channelSub.cancel();` after `_stateSub.cancel();` (`_channelSub` is `late final` and unconditionally assigned in the constructor, so the cancel is always safe).
  - **Do NOT** null `_moduleSessionId` in `_onState` on the `active→idle` re-arm branch (lines 31-37). Leave `_onState` lifecycle logic otherwise unchanged. No `reset()` is needed — meditation has no separate reset path; the channel re-arms inside `_onState` and the subscription stays alive across the channel's lifetime.
  - The getter has no callers yet — no behavior change outside this file today. The whole point of the null-guard is the downstream Phase 33 consumer.

## Verification
Note: this getter has no caller yet, so verification reproduces the *future* consumer's timing rather than relying on a synchronous read.
1. Start a meditation session, then stop it.
2. Read `stateChannel.moduleSessionId` **after a delay representative of the note-screen flow** (i.e. after the server's `COMPLETED` reply has landed and `ModuleState.initial()` has been emitted) — not synchronously at `idle`. A synchronous-at-idle read would pass even without the null-guard and give false confidence.
3. It must be non-null and match the session id seen in server logs. With the null-guard, both an immediate read and a delayed read return the correct id.
