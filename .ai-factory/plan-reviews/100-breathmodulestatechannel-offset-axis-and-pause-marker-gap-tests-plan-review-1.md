# Plan Review: BreathModuleStateChannel offset-axis and pause-marker gap tests

**Plan:** `100-breathmodulestatechannel-offset-axis-and-pause-marker-gap-tests.md`
**Scope reviewed:** plan vs. `lib/BreathModule/Core/BreathModuleStateChannel.dart` and `test/BreathModule/breath_module_state_channel_test.dart`
**Risk Level:** 🟡 Medium — one task has a wrong assumption that will make its tests fail as literally described; the rest is accurate.

## Context Gates
- **Architecture:** Test-only plan, no source changes (Pre-flight Note 1 — confirmed correct). No boundary/dependency impact. No `.ai-factory/skill-context/aif-review/SKILL.md` present, so no project-specific review overrides apply.
- **Rules / Roadmap:** Not blocking. The `100-` prefix implies a roadmap milestone; linkage is implicit and acceptable for a test-coverage task.

## Verification of plan claims (all accurate)
Every line reference in the Pre-flight Notes checks out against current source:
- Constructor injection points: `stopwatchFactory` (line 37), `clock` (line 38). ✓
- `_originWallClock = _clock()` only inside the `!_started` start branch (line 90); `_wireTimestamp` falls back to `_clock()` only when origin is null (lines 144–145). ✓ — so "clock called exactly once per started lifecycle" (Task 6) is correct.
- Pause marker `_emitMarker('pause', 0, …)` (line 106); resume re-emit `_emitMarker(state.phase.name, state.currentPhaseTotalDuration, …)` (line 98). ✓
- Fake tuple `(String, String, int, int, int)` = `(sessionId, phase, tickCount, offsetMs, timestampMs)` (test lines 57, 63–64); `offsetMs == call.$4`, `timestampMs == call.$5`. ✓
- Start branch resets `_previousPhase`/`_previousExerciseIndex` to null (lines 93–94); status-unchanged short-circuit (line 77). ✓

The plan author clearly read the code closely. Most tasks are directly implementable.

## Critical Issues

### 1. Task 5 (pending flush) cannot capture offset `T1` on the start emission — the start branch resets the stopwatch to 0 first

Task 5 instructs: *"Do not seed ModuleState initially … Prime, then emit a phase change at `_FakeStopwatch.elapsedMs == T1` (buffers with offset T1)."*

The problem: for an instruction to be buffered, `_handleInstruction` requires `_started == true` (line 121). The only way to set `_started` is the start branch, which runs on the first `wasPaused && isActive` transition. But that same start branch executes `_stopwatch..reset()..start()` (line 89), and the fake's `reset()` is specified (Task 1) to zero `elapsedMs`. Within a single `_onState` call the order is `_handleLifecycle` (resets to 0) → `_handleInstruction` (reads `elapsedMilliseconds`). A test cannot intervene between the reset and the read — they are in the same microtask.

So the literal sequence "prime with pause → set `elapsedMs = T1` → emit breath" produces:
- breath emission = the **start** emission → stopwatch reset to 0 → `_handleInstruction` reads offset **0**, not `T1`.
- The buffered instruction therefore holds offset 0, and the Task 5 assertion `flush offset == T1` **fails** (actual 0).

This is the same reset interaction the plan itself acknowledges for Task 2 case 3 ("first post-start instruction offset reflects the post-reset stopwatch value") — but Task 5 contradicts it.

**Fix:** the buffering phase-change must be a *non-start* emission. Spell out the full sequence:
1. Prime (pause, inhale) — no ModuleState seeded.
2. Emit breath/inhale → **starts** the session, resets stopwatch to 0, buffers offset 0 (sessionId still null).
3. Advance `elapsedMs = T1`.
4. Emit a **second** genuine phase change (e.g. breath/exhale) while still no ModuleState → lifecycle short-circuits (`breath == breath`, line 77), `_handleInstruction` overwrites `_pendingInstruction` with offset `T1` (the overwrite path already covered by the Phase 10 test at test lines 1007–1031).
5. Advance `elapsedMs = T2`.
6. Push `ModuleState(moduleSessionId: 'sid', …)` → `_flushPending` dispatches with the captured `T1`, not `T2`.

With this corrected sequence, `_originWallClock` is non-null (set at step 2), so `_wireTimestamp(T1)` uses `originWallClockMs + T1` and Task 5's second assertion holds.

## Minor Issues

### 2. Task 3 (pause marker) should explicitly seed a `ModuleState`
`_emitMarker` drops the marker and returns early when `_moduleSessionId == null` (lines 67–71). Task 3 says "Start a session … then transition active → pause" but never states that a `ModuleState` with a non-null `moduleSessionId` must be seeded first. Without it, no `sendSample` for the pause marker is recorded and the tests find nothing to assert on. Add an explicit "seed `ModuleState(moduleSessionId: 'sid', active)` before starting" step (it belongs to the same group as Task 2, which does seed it — but make it explicit so the marker tests don't silently dispatch zero samples).

### 3. Task 1 — `_Fixture` is a record typedef; new fields must be nullable and always populated
Records have no optional/defaulted fields, so extending `_Fixture` with the fake stopwatch and clock counter means every `_make()` call must populate them. For tests that don't opt in (default real `Stopwatch`/`DateTime.now`), expose these as nullable (`_FakeStopwatch? stopwatch`, counter `null`). This stays backward-compatible since no existing test reads the new fields — but the plan's phrasing "expose … through the `_Fixture` record (or return them alongside)" glosses over the nullable requirement. Recommend stating it.

### 4. Task 4 — confirm no duplicate instruction is dispatched on resume
Worth an explicit assertion (or a note) that the resume emission yields exactly **one** `sendSample` (the marker). The resume branch sets `_previousPhase = state.phase` (line 99) *before* `_handleInstruction` runs, so `phaseChanged` is false and no second instruction fires. The plan's "filter by phase name" works, but asserting the count guards against a regression where the marker and an instruction both dispatch.

## Positive Notes
- Pre-flight Notes are precise and override stale milestone wording correctly — especially Note 2 (fake tuple already captures the 5-tuple; do not rewrite it) and Note 4 (clock-once-per-lifecycle), both confirmed against source.
- `_FakeStopwatch implements Stopwatch` with `noSuchMethod` for unused members mirrors the existing fake pattern; source only touches `elapsedMilliseconds`/`reset`/`start`/`stop`, so the surface is small and safe.
- Forwarding `stopwatchFactory`/`clock` only when provided keeps all existing default-`Stopwatch`/`DateTime.now` tests unchanged — the right backward-compatibility call.
- Task 6's clock-once and re-capture-after-reset invariants map exactly onto the source's `_originWallClock` lifecycle (set at line 90, cleared in `reset()` at line 156).

## Verdict
The plan is well-researched and mostly implementable as written, but **Task 5's buffering sequence rests on a wrong assumption** (the start emission resets the stopwatch to 0, so `T1` cannot be captured on that emission). That task's tests will fail unless the sequence is corrected to buffer `T1` on a second, non-start phase change. Address issue 1 (and ideally 2–4) before implementation.

Not a PLAN_REVIEW_PASS.
