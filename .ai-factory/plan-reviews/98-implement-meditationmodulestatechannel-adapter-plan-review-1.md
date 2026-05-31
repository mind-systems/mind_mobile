# Plan Review: Implement `MeditationModuleStateChannel` adapter

**Plan:** `.ai-factory/plans/98-implement-meditationmodulestatechannel-adapter.md`
**Risk Level:** 🟢 Low

## Scope

Single-file, lifecycle-only adapter (`lib/MeditationModule/Core/MeditationModuleStateChannel.dart`) bridging the meditation session state stream to the shared gRPC `ModuleStateChannel`. The plan correctly scopes itself to Task 7 only (roadmap line 223); the assembly point (Task 8) and routing (Task 9) are deliberately out of scope and tracked as downstream roadmap tasks.

## Verification of Prerequisites

All three stated prerequisites were checked against the live codebase and confirmed:

- **`ActivityType.meditation`** — present in `lib/Core/Grpc/ActivityType.dart` (`enum ActivityType { breath, meditation }`). ✓
- **`ModuleStateChannel` API** — `start({required ActivityType type, String? refId})`, `end()`, `stop()` all exist with the exact signatures the adapter uses (`lib/Core/Grpc/ModuleStateChannel.dart:151,174,179`). `_mapActivityType` already maps `ActivityType.meditation → proto.ActivityType.MEDITATION` (line 199). ✓
- **`meditation_module` package** — exists (`packages/meditation_module/`), declared in root `pubspec.yaml:45`. `MeditationSessionState` / `MeditationSessionStatus { idle, active }` exist exactly as specced (`MeditationSession/Models/MeditationSessionState.dart`) and are exported from the barrel `meditation_module.dart:7`. The VM exposes `Stream<MeditationSessionState> get stream` via a broadcast controller (`MeditationSessionViewModel.dart:13`). ✓

## Correctness of the Adapter Design

- **State-transition logic is sound.** `_previousStatus` starts `null`; the VM's `build()` returns the initial `idle` state *without* pushing it onto the broadcast stream (confirmed at `MeditationSessionViewModel.dart:16-19` — only `set state` adds to the controller). So the first event the adapter sees is the first real transition. First `active` event: `active != null` passes the dedup guard, `active && !_started` → `start(...)`. Correct.
- **`end()` / `stop()` guarding is correct.** `active → idle` fires `end()` once (`_ended` guard). `dispose()` fires `stop()` only when `_started && !_ended`, so a normal Stop-then-pop is a no-op on dispose, while a pop while still active interrupts the server session. This matches the lifecycle reasoning in spec §C.
- **Imports are correct and minimal.** `dart:async`, `ActivityType`, `ModuleStateChannel`, and the two session types from the package. The plan correctly *omits* `ModuleState.dart` — unlike breath, this adapter does not subscribe to `channel.state`, so that import is genuinely unneeded. Good catch in the spec.
- **The "deliberately absent" list is accurate.** Removing `BreathModuleInstructionStream`, `_channelSub`/`_moduleSessionId`/`_pendingInstruction`/`_flushPending`, `_handleInstruction`, pause/resume, phase/exercise tracking, and `reset()` is consistent with the meditation roadmap scope (no instruction samples, no pause/resume, no restart). All removed members trace back to breath features that have no meditation analogue.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN — none. The adapter lives in `lib/MeditationModule/Core/` (domain/bridge layer), references only `App.shared.moduleStateChannel` (via the assembly point in the downstream task, not this file) and package DTOs. It respects the module-boundary rule: the package exposes `Stream<MeditationSessionState>`; the adapter consumes the DTO stream, never reaching into package internals. No boundary violation.
- **Rules (`RULES.md`):** WARN — none observed for this change.
- **Roadmap (`ROADMAP.md`):** Aligned. Plan maps 1:1 to Phase 25, line 223 ("Implement `MeditationModuleStateChannel` adapter"). The roadmap entry's prerequisite ("`ActivityType.meditation` exists") is satisfied by the already-completed line 221 task.
- **Skill-context (`.ai-factory/skill-context/aif-review/`):** directory present but empty — no project-specific override rules to apply.

## Observations (non-blocking)

1. **No in-screen restart.** After one full cycle (`start → end`, `_ended = true`), pressing the button again flips the VM back to `active`, but the adapter's `active && !_started` branch will not re-fire because `_started` stays `true`, so no new server activity opens for a second session within the same screen instance. This is *by design* per spec §C ("no restart in meditation"), and in practice each navigation into the session creates a fresh `ProviderScope` → fresh VM → fresh adapter, so a normal user never hits this. Not a defect; noted only so the implementer doesn't "fix" it.
2. **Minimal logging.** Plan marks `dev.log` calls as optional/omittable. Consistent with the "Logging: minimal" setting in the plan header. Fine.

## Positive Notes

- The plan embeds the full target source (spec §C) verified line-by-line against the real breath template — no invented APIs.
- Prerequisites were genuinely pre-verified, not assumed; every one held up under inspection.
- Scope discipline is excellent: the adapter is isolated from the assembly/routing work, keeping this task independently implementable and reviewable.

The plan is accurate, well-scoped, and free of incorrect assumptions, missing steps, or wrong file paths/API usage.

PLAN_REVIEW_PASS
