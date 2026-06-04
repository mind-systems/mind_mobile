# Code Review: MeditationModuleStateChannel — capture moduleSessionId from server

**Plan:** `.ai-factory/plans/20-meditationmodulestatechannel-capture-modulesessionid-from-server.md`
**Files changed (code):** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` (additive only)
**Files read in full:** the changed file, `lib/Core/Grpc/ModuleStateChannel.dart`, `lib/Core/Grpc/ModuleState.dart`, `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `lib/MeditationModule/MeditationModule.dart` (construction site).

## Summary

The diff implements the plan exactly: an import, a `String? _moduleSessionId` field, a `late final StreamSubscription<ModuleState> _channelSub`, a **null-guarded** listener on `channel.state`, a `moduleSessionId` getter, and `_channelSub.cancel()` in `dispose()`. No other files change. The getter has no callers yet, so there is no runtime behavior change today.

## Correctness verification

- **Null-guard is correct and necessary.** `channel.state` is a `BehaviorSubject<ModuleState>.seeded(ModuleState.initial())` (`ModuleStateChannel.dart:20`), and the channel re-emits `ModuleState.initial()` (null id) on `COMPLETED`/`INTERRUPTED`/`ABANDONED` (`ModuleStateChannel.dart:136,139,143`). The `if (moduleState.moduleSessionId != null)` guard correctly retains the last server-issued id across the `active→idle→note-screen` window, which is the whole point of the milestone. An unconditional assignment (breath's pattern) would have nulled it before the Phase 33 consumer reads it.
- **Seeded-value delivery is handled.** A new listener on the BehaviorSubject receives the current value (`ModuleState.initial()` at construction time, since the singleton is idle between sessions). The guard skips it — no stale/null leakage at construction.
- **`late final _channelSub` is always assigned** unconditionally in the constructor body, so `_channelSub.cancel()` in `dispose()` can never throw a `LateInitializationError`. `dispose()` is wired via `MeditationSessionScreen(onDispose:)` in `MeditationModule.buildSession()`, so the subscription is cancelled on screen teardown.
- **Shared singleton channel.** `channel` is `App.shared.moduleStateChannel`, a long-lived singleton shared across module sessions. Cancelling `_channelSub` on dispose detaches this per-session listener cleanly; the singleton's BehaviorSubject is not closed (correct — it outlives the session).
- **No collision** between `ModuleState` (from `mind/Core/Grpc/ModuleState.dart`) and the `meditation_module` import, which only shows `MeditationSessionState`/`MeditationSessionStatus`.
- **No domain/boundary violation.** `ModuleState` is pure Dart; the change stays in the domain channel layer. Consistent with `RULES.md` (this is a channel, not a Module Service — the stateless-service rule does not apply) and `ARCHITECTURE.md`.
- **`_onState` unchanged**, so `_moduleSessionId` is not nulled on the `active→idle` re-arm — as required.

## Notes (non-blocking)

- **Cross-session read window:** if a new session goes locally `active` but its `ACTIVE` reply hasn't yet landed, `_moduleSessionId` still holds the *previous* session's id. This is harmless for the intended consumer, which reads only after a session *stops* (by which point the server has replied ACTIVE for that session). This is the same accepted tradeoff as the breath analogue and is documented in the plan. No action needed.
- The getter is currently dead code by design (Phase 33 prerequisite). Worth confirming the Phase 33 consumer lands before this is considered "done" end-to-end, but that is out of scope for this milestone.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
