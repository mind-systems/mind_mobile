# Plan Review (round 2): BreathModuleStateChannel offset-axis and pause-marker gap tests

**Plan:** `100-breathmodulestatechannel-offset-axis-and-pause-marker-gap-tests.md`
**Scope reviewed:** plan vs. `lib/BreathModule/Core/BreathModuleStateChannel.dart` and `test/BreathModule/breath_module_state_channel_test.dart`
**Risk Level:** 🟢 Low — every critical issue from review-1 is resolved; only small clarity items remain.

## Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Test-only plan, no source changes (Pre-flight Note 1, re-confirmed against source — the constructor already exposes `stopwatchFactory`/`clock`). No boundary or dependency impact. — OK
- **Rules (`.ai-factory/RULES.md`):** The three project rules concern module Service statelessness, App.dart purity, and constructor injection. None are touched by a test-only change. Constructor-injection rule is actually reinforced (the plan injects fakes via the existing constructor seams rather than wiring from outside). — OK
- **Roadmap (`.ai-factory/ROADMAP.md`):** The `100-` prefix implies a roadmap test milestone; linkage is implicit and acceptable for a test-coverage task. — WARN (non-blocking)
- **skill-context:** `.ai-factory/skill-context/aif-review/SKILL.md` not present — no project-specific review overrides apply.

## Review-1 follow-up (all resolved)
1. **Task 5 buffering sequence** — review-1's critical issue (the start emission resets the stopwatch to 0, so `T1` cannot be captured on it). The plan now adds **Pre-flight Note 8** and rewrites Task 5 with the exact 6-step sequence (buffer offset 0 on the start emission, capture `T1` on a *second* non-start phase change via the line-77 short-circuit, then flush after advancing to `T2`). I traced this against `_handleLifecycle`→`_handleInstruction` ordering (lines 59–60), the start branch reset (line 89), the short-circuit (line 77), and the overwrite path (lines 129–131): the corrected sequence is sound and mirrors the existing Phase 10 overwrite test (lines 1007–1031). ✓
2. **Task 3 seed ModuleState** — now explicit ("Seed `ModuleState(moduleSessionId: 'sid', status: active)` first"), matching the `_emitMarker` null-guard at lines 67–71. ✓
3. **Task 1 `_Fixture` nullable fields** — now explicit that records have no defaulted fields and the new `stopwatch`/`clockCallCount` fields must be nullable and populated only on opt-in. ✓
4. **Task 4 single sendSample on resume** — now an explicit test case, with the correct rationale (line 99 sets `_previousPhase = state.phase` before `_handleInstruction`, so `phaseChanged` is false). ✓

## Verification of plan claims
Every line reference in the Pre-flight Notes and Tasks checks out against current source:
- `stopwatchFactory` (line 37), `clock` (line 38); `_stopwatch = stopwatchFactory()` called once (line 42). ✓
- `_originWallClock = _clock()` only in the `!_started` branch (line 90); `_wireTimestamp` falls back to `_clock()` only when origin is null (lines 144–145) — so "clock called exactly once per started lifecycle" (Task 6) holds. ✓
- Pause marker `_emitMarker('pause', 0, …)` (line 106); resume re-emit `_emitMarker(state.phase.name, state.currentPhaseTotalDuration, …)` (line 98); both read `_stopwatch.elapsedMilliseconds`. ✓
- Fake tuple `(String, String, int, int, int)` = `(sessionId, phase, tickCount, offsetMs, timestampMs)` (test lines 57, 63–64); `offsetMs == call.$4`, `timestampMs == call.$5`. ✓
- Start branch resets `_previousPhase`/`_previousExerciseIndex` to null (lines 93–94); status-unchanged short-circuit (line 77); instruction offset read at line 127; `_pendingInstruction` buffer at lines 129–131; `_flushPending` at lines 137–142. ✓
- `_FakeStopwatch implements Stopwatch` with `noSuchMethod` for unused members mirrors the existing `_FakeChannel`/`_FakeInstructionStream` pattern; source only touches `elapsedMilliseconds`/`reset`/`start`/`stop`, so the interface surface is small and safe. ✓
- Test command path and file paths are correct (`/usr/local/bin/flutter` matches the project's known Flutter location).

## Minor Issues (non-blocking — implementer can resolve)

### 1. Task 1 — reconcile "`_make` accepts a `Stopwatch Function()` factory" with "`_Fixture` exposes a `_FakeStopwatch? stopwatch`"
The constructor calls `stopwatchFactory()` exactly once (line 42), so if `_make` only receives an opaque `Stopwatch Function()?`, it has no handle to the concrete fake instance to place into `_Fixture.stopwatch`. Two clean resolutions, either is fine:
- Have `_make` accept the `_FakeStopwatch?` instance directly and build the factory internally (`stopwatchFactory: stopwatch != null ? () => stopwatch : Stopwatch.new`), then populate `_Fixture.stopwatch` from it; **or**
- Have the test create the fake and pass it both as the factory source and as a `stopwatch:` argument to `_make`.
Suggest stating which, so the fake instance the SUT uses is provably the same one the test mutates.

### 2. `_make` should default rather than conditionally forward
The constructor params are non-nullable (`Stopwatch Function()`, `DateTime Function()`), so `_make` cannot pass `null`. The simplest backward-compatible form is `stopwatchFactory: stopwatchFactory ?? Stopwatch.new` / `clock: clock ?? DateTime.now` — this preserves real-`Stopwatch`/`DateTime.now` behavior for all existing tests without branching the constructor call. Worth naming explicitly so the implementer doesn't attempt an awkward conditional-construction path.

### 3. Task 4 must seed its own `ModuleState`
Tasks 2–4 share a `group(...)`, but each `test(...)` runs with a fresh fixture — group membership does not share seeded state. The resume and pause markers both go through `_emitMarker`, which silently drops when `_moduleSessionId == null` (lines 67–71). Task 4 inherits the seeding requirement from Task 3 but does not restate it; add an explicit "seed `ModuleState(moduleSessionId: 'sid', active)`" step so the resume marker isn't silently dropped (which would leave the count/offset assertions testing nothing).

### 4. Absolute-timestamp assertions need the fixed clock injected
The `timestampMs == originWallClockMs + offsetMs` assertions in Task 3 (case 3), Task 5, and Task 6 require a known `originWallClockMs`. Task 1 sets up the fixed-DateTime clock spy, but Tasks 3 and 5 don't explicitly say "inject the clock spy." Make the opt-in explicit in those tasks so the expected timestamp is computable (e.g. fixed origin `1_000_000`).

## Positive Notes
- Pre-flight Note 8 is an excellent addition — it captures the reset-before-read microtask ordering precisely and ties it to the concrete consequences for Tasks 2, 5. This was the root cause of review-1's only critical issue and is now documented at the source-line level.
- The plan correctly distinguishes the start emission (offset 0, stopwatch just reset) from later emissions, and threads that distinction consistently through the offset-monotonicity, pending-flush, and wire-timestamp cases.
- Backward compatibility is handled correctly: nullable `_Fixture` fields, opt-in fakes, default real `Stopwatch`/`DateTime.now` — no existing lifecycle test is disturbed.
- Task 4's single-sendSample-on-resume guard and Task 6's clock-once + re-capture-after-reset invariants map exactly onto the `_originWallClock` lifecycle (set at line 90, cleared in `reset()` at line 156).

## Verdict
All critical and minor findings from review-1 are resolved. The remaining items are clarity refinements an implementer can settle locally without changing the test design or risking failing assertions. The plan is well-researched, line-accurate, and implementable as written.

PLAN_REVIEW_PASS
