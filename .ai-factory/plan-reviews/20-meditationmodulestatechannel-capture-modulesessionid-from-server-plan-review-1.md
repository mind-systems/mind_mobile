# Plan Review: MeditationModuleStateChannel — capture moduleSessionId from server

**Plan:** `.ai-factory/plans/20-meditationmodulestatechannel-capture-modulesessionid-from-server.md`
**Files inspected (in full):** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`, `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `lib/Core/Grpc/ModuleState.dart`, `lib/Core/Grpc/ModuleStateChannel.dart`, spec note `71`, ROADMAP Phase 33 (lines 71–79).
**Risk Level:** 🔴 High — the change compiles and mirrors breath correctly, but as specified it will return `null` at the exact moment the future consumer reads it, silently defeating the milestone.

---

## Verification of plan claims (all accurate)

- **File path** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — correct.
- **Import** `package:mind/Core/Grpc/ModuleState.dart` — correct; `ModuleState` lives there and is pure Dart (no Flutter/Riverpod), so no boundary violation.
- **`channel.state`** is `Stream<ModuleState>` (`ModuleStateChannel.dart:23`) — correct.
- **`moduleState.moduleSessionId`** is `String?` (`ModuleState.dart:4`) — correct.
- **`_channel` vs `channel`** — the constructor stores the param into `_channel` in the initializer list before the body runs; subscribing to `channel.state` in the body is equivalent. Correct.
- **`dispose()` cancel** — `_channelSub` is `late final` and unconditionally assigned in the constructor, so `_channelSub.cancel()` is always safe. Correct.
- **Re-arm branch (lines 31–37)** — accurately identified; leaving `_onState` otherwise unchanged is right.

The mechanical instructions are sound. The problem is the *semantics* of the listener body.

---

## Critical Issues

### 1. The captured `moduleSessionId` is reset to `null` by the server's end-of-session response — before the consumer reads it

The plan copies breath's listener verbatim:

```dart
_channelSub = channel.state.listen((moduleState) {
  _moduleSessionId = moduleState.moduleSessionId;   // unconditional
});
```

Trace the meditation lifecycle against `ModuleStateChannel`:

1. Session goes `active` → `_onState` calls `_channel.start()` → server replies `ACTIVE` → `_processProtoEvent` emits `ModuleState(moduleSessionId: X, active)` (`ModuleStateChannel.dart:127`). Listener sets `_moduleSessionId = X`. ✅
2. Session goes `idle` → `_onState` calls `_channel.end()` (line 32) and re-arms.
3. Server processes the end → replies `COMPLETED`/`INTERRUPTED` → `_processProtoEvent` emits **`ModuleState.initial()`** (`ModuleStateChannel.dart:136`), whose `moduleSessionId` is **`null`**.
4. The listener fires again and sets **`_moduleSessionId = null`**. ❌

So the field is non-null only during the brief window between the local `idle` transition and the server's `COMPLETED` reply arriving over the wire.

Now look at who actually reads it. ROADMAP Phase 33 (line 79) defines the consumer:

> `pass getSessionId: () => stateChannel.moduleSessionId lazy closure from buildSession()`

and (line 73 + 77) the read happens inside `MeditationSessionCoordinator.onSessionStopped()`, which **`await`s `Navigator.push(MeditationNoteScreen)`** and only calls `getSessionId()` *after the user types a note and taps OK*. That is seconds after `active→idle` — far past the point where the server's `COMPLETED` reply has nulled the field.

**Result:** `getSessionId()` returns `null`, the gRPC note-sync guard `if (sessionId != null)` (line 79) is false, and the note never syncs to the server. This is exactly the "silently-failing domain logic" class this channel is listed under in `docs/core/testing.md` — no crash, no error, just lost data.

The plan's own justification — *"the field is naturally overwritten when the next session starts and the server returns a fresh ID"* — is true but irrelevant: the read happens *between* this session's end and the next session's start, which is precisely the window where the field is `null`.

**Fix — guard the assignment so the last non-null id is retained:**

```dart
_channelSub = channel.state.listen((moduleState) {
  if (moduleState.moduleSessionId != null) {
    _moduleSessionId = moduleState.moduleSessionId;
  }
});
```

This keeps the last server-issued id alive across the `active→idle→note-screen` window, and a new session's `ACTIVE` reply still overwrites it with a fresh id, so there is no cross-session staleness in the read window.

**Why breath gets away with the unconditional assignment:** `BreathModuleStateChannel` reads `_moduleSessionId` only *during* the active session (to stream phase instructions in `_handleInstruction`, lines 86–101). It never needs the id to survive past session end, so the null-on-end is harmless there. The plan mirrors breath's *code* without accounting for meditation's *different read timing*. This is the core wrong assumption.

### 2. The note 71 "Verify" step will pass while the real consumer fails — make it representative

Note `71`'s verification reads:

> "After `idle` is set, call `stateChannel.moduleSessionId` — it should be non-null."

If executed synchronously right after the local `idle` transition, this passes (the `COMPLETED` reply hasn't landed yet), giving false confidence. The verification must read the getter **after an awaited delay / after the note screen would have been dismissed** to reproduce the actual consumer timing. With the Issue 1 guard in place, both the immediate and delayed reads return the correct id.

---

## Minor Notes

- **No `reset()` needed.** Unlike breath, meditation has no separate reset path; the channel re-arms inside `_onState` and the subscription stays alive across the channel's lifetime. The plan correctly omits a `reset()`. (Just confirming this is intentional and fine — with the Issue 1 guard, no extra nulling logic is required.)
- **Single call site.** `MeditationModuleStateChannel` is constructed only in `MeditationModule.buildSession()` (`lib/MeditationModule/MeditationModule.dart:30`); the additive getter has no current callers, so there is genuinely no behavior change outside this file *today*. The risk is entirely about the downstream Phase 33 consumer — which is why fixing it now (rather than discovering null notes two milestones later) matters.

---

## Context Gates

- **Architecture (`ARCHITECTURE.md`)** — PASS. Change is confined to the domain layer (`lib/MeditationModule/Core/`), uses constructor-injected dependencies, no Flutter/Riverpod leakage. Aligns with the Notifier/channel pattern.
- **Rules (`RULES.md`)** — PASS. This is a domain channel, not a Module Service, so the "stateless service / no StreamSubscription" rule does not apply. Dependencies stay constructor-injected; the class manages its own subscription — consistent with the third rule.
- **Roadmap (`ROADMAP.md`)** — PASS (linkage). Maps 1:1 to the open Phase 33 item at line 71 and is the prerequisite for the note-sync item at line 79. Spec note `71` agrees with the plan.

---

## Positive Notes

- Correct, minimal, single-file additive scope; imports and API usage all verified against the actual sources.
- Plan explicitly reasoned about *not* nulling on re-arm — the right instinct; it just missed the *other* null source (the server's end reply via `_channelSub`).
- Good cross-references to the breath analogue and exact line numbers.

---

## Required Changes Before Implementation

1. Guard the `_channelSub` listener with a non-null check (Issue 1) so the captured id survives `active→idle` until the coordinator reads it. Update the plan text and spec note `71` accordingly.
2. Update the verification step (Issue 2) to read `moduleSessionId` after a delay representative of the note-screen flow, not synchronously at `idle`.

These are blocking: without change #1 the milestone's stated goal — "a future coordinator can read it after `active→idle`" — is not met.
