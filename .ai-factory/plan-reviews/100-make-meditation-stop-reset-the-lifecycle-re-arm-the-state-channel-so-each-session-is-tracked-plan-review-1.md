# Plan Review: Make meditation Stop reset the lifecycle (re-arm the state-channel)

**Plan:** `100-make-meditation-stop-reset-the-lifecycle-re-arm-the-state-channel-so-each-session-is-tracked.md`
**Files Reviewed:** 1 plan + 6 source files for context
**Risk Level:** 🟢 Low

## Verdict

The plan is correct, minimal, and faithful to both the codebase and the originating task spec (`.ai-factory/notes/46-task-meditation-stop-reset.md`). All file paths, line references, and API calls check out. The single-file change is the right fix for the stated bug.

## Verification of Plan Claims

- **File path** `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — exists, matches.
- **Current `active → idle` branch** (`:31-34`) is exactly `_channel.end(); _ended = true;` as the plan states.
- **Dedup guard** (`:26`, `status == _previousStatus`) and **start branch** (`:28-30`) are as described; leaving them untouched is correct.
- **Cross-reference target** `BreathModuleStateChannel.reset()` re-arms `_started`/`_ended` at `:112-113` (within the `:110-119` method). Line citation is accurate.
- **Enum** `MeditationSessionStatus { idle, active }` confirms there are exactly two states, so the `active → idle` transition is the only Stop path — no other branches need re-arming.

### Trace through the fix (2 cycles)
Initial: `_started=false, _ended=false, _previousStatus=null`. Note the VM's initial `idle` is returned from `build()` without going through the `set state` override, so it is **not** emitted to the stream — the channel's first observed event is the first `active`. Good.

- Cycle 1 Start → `active`, `!_started` → `_channel.start()`, `_started=true`.
- Cycle 1 Stop → `idle`, `_started && !_ended` → `_channel.end()`, re-arm `_started=false, _ended=false`.
- Cycle 2 Start → `active`, `!_started` (true again) → `_channel.start()` fires fresh. ✅
- Navigate away while active → `dispose()` sees `_started=true && !_ended` → `stop()` fires. ✅
- Navigate away after Stop → `_started=false` → `dispose()` fires nothing. ✅

Dispose invariant holds exactly as the plan asserts.

## Context Gates

- **Architecture** (`CLAUDE.md` / module boundary): WARN-none. The change stays in `lib/MeditationModule/Core/` (domain-side adapter), touches no package code, no DTOs, no proto. Consistent with the module-boundary rules.
- **Rules** (no `.ai-factory/RULES.md` present): N/A.
- **Roadmap**: Task traces to ROADMAP Phase 26 via the task note; linkage is present. WARN-none.

## Observations (non-blocking)

1. **`_ended` becomes vestigial.** After this change, `_ended` is set `false` in the idle branch and never set `true` anywhere, so it is permanently `false`; the `!_ended` guard in the idle branch and in `dispose()` reduces to always-true / `_started`. This is harmless and intentionally mirrors breath's field set (minimizing divergence), so keeping it is defensible. If a follow-up wants to simplify, `_ended` could be dropped — but that is out of scope here and the plan is right not to touch it.

2. **Latent rapid-retap race (pre-existing, shared with breath).** `ModuleStateChannel.end()` only *sends* the end command; the channel's `currentState` stays `active` until the server's `COMPLETED` round-trips back (`_processProtoEvent` → `ModuleState.initial()`). `start()` early-returns when `currentState.status == active`. So a Stop→Start fast enough to beat the server confirmation would have cycle 2's `_channel.start()` silently dropped while the adapter sets `_started=true` — reproducing the "untracked session" symptom in a narrow window. This is **not introduced by this plan** and is **not realistically reachable** through the UI: Stop and Start are two distinct taps on a single toggle button (`MeditationSessionScreen:42-44`), and human tap-to-tap latency comfortably exceeds the bidi-stream round-trip. `BreathModuleStateChannel` carries the identical exposure, so the fix stays consistent with the established pattern. Flagging only so the implementer is aware if the on-device Verify is ever automated/scripted with near-zero inter-tap delay.

## Positive Notes

- Scope is exactly one file and three tokens of behavior change — no over-engineering.
- Plan explicitly preserves the dedup and start branches and re-derives the dispose invariant rather than assuming it.
- Requiring an inline comment cross-referencing `BreathModuleStateChannel.reset()` keeps the inlined re-arm from reading as ad-hoc — good maintainability instinct.
- Settings (no tests, minimal logging, no docs) are appropriate for a three-token domain-adapter fix.

PLAN_REVIEW_PASS
