# Plan Review 2 — MeditationModuleStateChannel: capture moduleSessionId from server

**Plan:** `20-meditationmodulestatechannel-capture-modulesessionid-from-server.md`
**Files Reviewed:** 1 plan + 4 codebase files
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present — no boundary violation. `MeditationModuleStateChannel` is a domain-layer channel adapter (`lib/MeditationModule/Core/`), not a Module Service, and it manages its own subscription in its own constructor. ✅ WARN: none.
- **Rules (`.ai-factory/RULES.md`):** present, 3 rules. None violated:
  - Rule "Module Services must be stateless" — N/A, this class is not a Service.
  - Rule "constructor-injected dependencies, class manages its own subscription" — the plan adds `_channelSub` inside the constructor, subscribing to the already-injected `channel`. ✅ Compliant.
- **Roadmap:** plan correctly anchors to ROADMAP Phase 33 (note-sync) as the future consumer. ✅

## Correctness Verification

I checked every claim in the plan against the actual code:

1. **"`MeditationModuleStateChannel` calls `channel.start()` but never subscribes to `channel.state`"** — Confirmed. `MeditationModuleStateChannel.dart:24-39` only subscribes to `stateStream` (the ViewModel stream), never to `channel.state`.

2. **The fatal-unconditional-assignment claim** — Confirmed against `ModuleStateChannel.dart:135-136`: on `COMPLETED`/`INTERRUPTED` the channel emits `ModuleState.initial()`, whose `moduleSessionId` is `null` (`ModuleState.dart:10-11`). An unconditional listener (as in `BreathModuleStateChannel.dart:36`) would therefore overwrite `_moduleSessionId` with `null` the moment the server confirms session end — i.e. exactly before the Phase-33 consumer reads it after the note screen. The null-guard is genuinely required, and the contrast with breath (which only reads the id *during* the active session in `_handleInstruction`, `BreathModuleStateChannel.dart:86-101`) is accurate.

3. **File paths and line references** — All accurate: `BreathModuleStateChannel.dart` imports/fields/listener/getter at the cited lines; the meditation `_onState` re-arm branch at lines 31-37; the constructor stores `_channel` but the listener can subscribe to the `channel` parameter (same instance).

4. **API usage** — `channel.state` is `Stream<ModuleState>` (`ModuleStateChannel.dart:23`); `moduleState.moduleSessionId` is `String?` (`ModuleState.dart:4`). The proposed import `package:mind/Core/Grpc/ModuleState.dart` is needed for the `StreamSubscription<ModuleState>` annotation and is not currently imported. `dart:async` (for `StreamSubscription`) is already imported at line 1. ✅

5. **dispose safety** — `_channelSub` is `late final`, unconditionally assigned in the constructor, so `_channelSub.cancel()` in `dispose()` is always safe. ✅

6. **No `reset()` needed** — Confirmed. Unlike breath, `MeditationModuleStateChannel` is recreated per `buildSession` call (`MeditationModule.dart:24-34`), so `_moduleSessionId` starts `null` each session instance. The in-instance re-arm path (`_onState`, idle branch) intentionally does not null the id, which the plan correctly preserves.

## Critical Issues

None.

## Minor Considerations (non-blocking)

- **Synchronous seeded emission at subscription.** `channel.state` is a `BehaviorSubject` stream (`ModuleStateChannel.dart:20`), so the new listener fires synchronously at subscription time with the *current* value. Because `App.shared.moduleStateChannel` is a **shared singleton** across breath and meditation, the guard will capture whatever id the subject currently holds. In normal flow this is `null` (resting state after any prior session ends → `ModuleState.initial()`), so there is no issue. The only way a stale non-null id could be seeded is if a prior session were still active/non-null at meditation-screen construction — not a real flow. The plan's "a fresh session's `ACTIVE` reply overwrites it" reasoning covers the read window. No action required, but worth keeping in mind if the consumer ever reads *before* the new session's `ACTIVE` reply lands.

- **Logging setting = minimal.** The plan adds no log line to the listener. This is consistent with "minimal" and with the silent-capture nature of the change. Acceptable.

## Positive Notes

- The timing constraint is the crux of this milestone, and the plan identifies it precisely and correctly — this is a non-trivial bug that a naive "copy breath" implementation would have introduced. The explicit "do NOT mirror breath's unconditional body" warning is exactly right.
- Scope is minimal and additive: one file, no behavior change for current callers, no migration, no proto change.
- Verification step correctly insists on a *delayed* read (post-`COMPLETED`) rather than a synchronous-at-idle read, explicitly noting that a synchronous read would pass even without the guard and give false confidence. This is the right way to test the actual fix.

PLAN_REVIEW_PASS
