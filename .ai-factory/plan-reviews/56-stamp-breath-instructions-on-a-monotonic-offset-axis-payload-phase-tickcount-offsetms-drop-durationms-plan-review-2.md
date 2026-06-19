# Plan Review 2: Stamp breath instructions on a monotonic offset axis (`{phase, tickCount, offsetMs}`, drop `durationMs`)

**Plan:** `.ai-factory/plans/56-stamp-breath-instructions-on-a-monotonic-offset-axis-payload-phase-tickcount-offsetms-drop-durationms.md`
**Prior review:** `...-plan-review-1.md` (Risk 🟡, one blocker)
**Files inspected:** `BreathModuleInstructionStream.dart`, `BreathModuleStateChannel.dart`, `InstructionSample.dart`, `BreathSessionStateMachine.dart`, `test/BreathModule/breath_module_state_channel_test.dart` (full, 1237 lines), grep of all `.dart` for `sendSample`/`durationMs`/`offsetMs`/`currentPhaseTotalDuration`
**Risk Level:** 🟢 Low — the review-1 blocker is resolved; the added Task 4 is accurate against the real test file.

---

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN-free / PASS. Change stays inside `lib/BreathModule/Core/` (domain-adjacent channel + thin instruction mapper). No module boundary crossed, no domain model leaked into a package, `InstructionSample.data` is `Map<String, dynamic>` so new keys are type-safe. Consistent with the layered design.
- **Rules (`RULES.md`):** PASS. `BreathModuleStateChannel` is not an `IXxxService`; it is already a stateful coordinator with subscriptions and `dispose()`. Adding a `Stopwatch`/`DateTime?` field violates none of the Module-Service / `App.dart`-purity / constructor-injection rules. No `App.dart` change.
- **Roadmap (`ROADMAP.md`):** PASS. Implements Phase 42; spec note 121 exists and the 5-arg divergence from it is documented in the plan's Notes. Good milestone linkage.

---

## Resolution of Review-1's Blocker

Review-1's sole blocker was: *changing `sendSample`'s arity breaks compilation of the existing 1237-line test suite, and no task fixed it.* **This is now resolved by the newly-added Task 4.** I verified Task 4 against the actual test file:

1. **Fake signature.** Current fake at line 51-60 declares the 4-param override and captures `(sessionId, phase, durationMs)` into `List<(String, String, int)>`. Task 4.1 correctly updates it to the 5-arg signature and keeps the `(String, String, int)` tuple capturing `tickCount` as the 3rd value — so every existing full-tuple assertion stays structurally valid. Correctly refuses to capture the non-deterministic `offsetMs`/`timestampMs` into the equality tuple.

2. **Affected assertions — all line references verified accurate** against the current file:
   - 751 `('sid','exhale',5000)` ✓ · 771 `('sid','inhale',5000)` ✓ · 885 `.last ('sid','exhale',6000)` ✓ · 950 `('sid','exhale',5000)` ✓ · 1016 `[('sid','inhale',6000)]` ✓ · 1047 `('sid','exhale',5000)` ✓ · 1145 `.last ('sid','exhale',5000)` ✓ · 1183 `.last ('sid','inhale',5000)` ✓.
   - The obsolete `currentIntervalMs == -1` test (name at ~891, assertion `('sid','exhale',-1)` at 907) is correctly identified and repurposed by Task 4.3.
   - The two partial assertions that only read `.$1` (1083 `'sid-B'`, 1209 `'sid-new'`) are correctly **not** listed — they don't pin the 3rd value and survive the change untouched.
   - The `hasLength`-only dispatch tests (805/811, 832, 857, 990, etc.) need no value change. Correctly out of Task 4's scope.

   This is the complete set of value-pinning assertions; nothing is missed.

3. **Determinism strategy.** Task 4.2 instructs setting distinct `currentPhaseTotalDuration` on the dispatched states and asserting those, rather than relying on the helper's default of `1`. Since the new 3rd arg is `state.currentPhaseTotalDuration` (a deterministic field), these assertions remain exact — only `offsetMs`/`timestamp` are relaxed. Note 51 documents the deliberate choice to accept relaxed assertions over widening the constructor with an injected clock. Reasonable and self-consistent.

---

## Correctness Spot-Checks (this pass)

- **`tickCount` semantics confirmed at source.** `BreathSessionStateMachine._computeEnrichedFields` (line 444) sets `currentPhaseTotalDuration` from `isRest ? restDuration : steps[...].duration` — both tick *counts*. So `tickCount = state.currentPhaseTotalDuration` is accurate, and dropping the `* currentIntervalMs` product correctly eliminates the `-1`-poisoned value at origin. ✓
- **Blast radius contained.** Grep confirms `sendSample` has exactly two call sites (`_handleInstruction`, `_flushPending`) plus the test fake; no other consumer reads `data['durationMs']`. The other `currentPhaseTotalDuration`/`offsetMs` grep hits are inside `packages/breath_module` and refer to the state field, not the wire payload. ✓
- **Origin/`_wireTimestamp` invariant holds.** `_handleInstruction` is reachable only when `_started`, which is set true exclusively in the start branch where the plan also resets+starts the stopwatch and sets `_originWallClock`. So `_originWallClock` is always non-null at send/park time; the `?? DateTime.now()` fallback (note 50) is dead-but-harmless. Parked samples stamp `origin + capturedOffset`, keeping the wire timestamp consistent with phase time. ✓
- **Lifecycle-before-instruction ordering.** `_onState` calls `_handleLifecycle` (resets the stopwatch in the start branch) before `_handleInstruction` (reads `_stopwatch.elapsedMilliseconds`) in the same pass, so the first phase's `offsetMs ≈ 0`. ✓
- **Pause behavior.** Stopwatch is intentionally not stopped on pause (note in Task 2). Matches the old `DateTime.now()` axis and the continuous-axis contract that follow-ups 123/124 depend on; flagged so the implementer does not "helpfully" add `_stopwatch.stop()`. ✓

---

## Minor Observations (non-blocking)

- **Task 4.2 leaves exact tick values to the implementer** ("set distinct `currentPhaseTotalDuration`"). This is acceptable plan-level guidance — the values are free to choose as long as the dispatched state and the assertion agree. No action needed.
- **`_pendingInstruction` record rename** (`{state, ts}` → `{state, offsetMs}`) touches both `_handleInstruction` and `_flushPending`; the plan calls out both. The `reset()` clear of `_pendingInstruction = null` already exists and needs no field-type change. ✓

---

## Positive Notes

- Root-cause fix: a single client-owned monotonic source eliminates both the cross-clock `DateTime.now()` axis and the negative-at-origin `durationMs`.
- Origin-wall-clock ownership kept in one place (the channel); `BreathModuleInstructionStream` stays a thin mapper, consistent with the earlier "collapse to thin mapper" work.
- Cross-repo `mind_web` impact explicitly scoped out with a documented no-regression rationale.
- The previously-blocking test gap is now fully and accurately specified.

---

## Verdict

The design was already sound; review-1's only blocker (the unupdated test suite) is now addressed by Task 4, which I verified line-for-line against the real test file — signatures, all nine value-pinning assertions, the obsolete `-1` test, and the determinism strategy all check out. No remaining blockers.

PLAN_REVIEW_PASS
