# MeditationModuleStateChannel — Capture moduleSessionId

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `MeditationModuleStateChannel` calls `channel.start()` but never subscribes to `channel.state`, so the `moduleSessionId` the server returns is silently discarded.
- The fix is a single `_channelSub` — mirrors `BreathModuleStateChannel` structurally, but the listener body **must be null-guarded** (unlike breath's unconditional assignment). See "Listener must be null-guarded" below.
- `_moduleSessionId` must NOT be nulled on session re-arm: it needs to survive until after `active→idle` fires, because the coordinator reads it when saving the post-session note.

## Details

### File changed

`lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — one file, additive only.

### Changes

```dart
import 'package:mind/Core/Grpc/ModuleState.dart';  // add

class MeditationModuleStateChannel {
  // existing fields ...
  String? _moduleSessionId;                                        // NEW
  late final StreamSubscription<ModuleState> _channelSub;          // NEW

  MeditationModuleStateChannel({...}) : ... {
    _stateSub = stateStream.listen(_onState);
    _channelSub = channel.state.listen((moduleState) {             // NEW — null-guarded
      if (moduleState.moduleSessionId != null) {
        _moduleSessionId = moduleState.moduleSessionId;
      }
    });
  }

  String? get moduleSessionId => _moduleSessionId;                 // NEW

  void _onState(MeditationSessionState state) {
    // existing logic unchanged
    // on re-arm (active→idle): do NOT touch _moduleSessionId
  }

  void dispose() {
    if (_started && !_ended) _channel.stop();
    _stateSub.cancel();
    _channelSub.cancel();                                          // NEW
  }
}
```

### Listener must be null-guarded (differs from breath)

The naive copy of breath's listener assigns `_moduleSessionId` unconditionally on every `ModuleState`. That breaks here because of the meditation lifecycle:

1. `active` → `_channel.start()` → server replies `ACTIVE` → channel emits `ModuleState(moduleSessionId: X, active)` → field = X. ✅
2. `idle` → `_channel.end()` and re-arm.
3. Server processes the end → replies `COMPLETED`/`INTERRUPTED` → `ModuleStateChannel._processProtoEvent` emits **`ModuleState.initial()`** (`lib/Core/Grpc/ModuleStateChannel.dart:135-136`), whose `moduleSessionId` is **`null`**.
4. An unconditional listener fires and sets **`_moduleSessionId = null`**. ❌

The consumer (ROADMAP Phase 33) reads the getter inside `MeditationSessionCoordinator.onSessionStopped()`, *after* the user dismisses the meditation note screen — seconds past step 3 — so it would read `null` and the note would silently fail to sync. The null-guard keeps the last server-issued id alive across the `active→idle→note-screen` window; a new session's `ACTIVE` reply overwrites it with a fresh id, so there is no cross-session staleness in the read window.

**Why breath gets away with the unconditional assignment:** `BreathModuleStateChannel` reads `_moduleSessionId` only *during* the active session (to stream phase instructions in `_handleInstruction`), never after session end, so the null-on-end is harmless there.

### Why not null on re-arm

The re-arm block (`_started = false; _ended = false`) fires when `active → idle`. The coordinator reads `moduleSessionId` after this transition — when the user dismisses the note screen. Nulling here would lose the ID before it can be used. The field is naturally overwritten when the next session starts and the server responds with a fresh ID.

### Verify

Start a meditation session, stop it. Read `stateChannel.moduleSessionId` **after a delay representative of the note-screen flow** (after the server's `COMPLETED` reply has landed and `ModuleState.initial()` has been emitted) — not synchronously at `idle`, which would pass even without the null-guard and give false confidence. It should be non-null and match the session ID seen in server logs. Nothing else reads this getter yet; no behavior change outside this file.
