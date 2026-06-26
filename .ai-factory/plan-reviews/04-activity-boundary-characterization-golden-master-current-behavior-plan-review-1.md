# Plan Review: Activity-boundary characterization golden master (current behavior)

**Plan:** `.ai-factory/plans/04-activity-boundary-characterization-golden-master-current-behavior.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid. Test-only, no production change, all code-recon claims verified against the actual source.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present. No boundary/dependency concerns — the plan adds a single test file under `test/BreathModule/Support/`, reuses the existing `BreathActivityHarness` and fakes, and crosses no module boundary. Asserting only on `BreathSessionState` (the package's exported boundary type) is exactly the right altitude. ✅
- **Rules (`.ai-factory/RULES.md`):** present. The three rules (stateless module services, no module state in App.dart, constructor-DI) are about production wiring and do not apply to a test-only addition. No violations. ✅
- **Roadmap (`.ai-factory/ROADMAP.md`):** **strong linkage.** This plan is the verbatim milestone at ROADMAP line 17 ("Activity-boundary characterization golden master (current behavior)") under Phase 58. The spec note `.ai-factory/notes/04-breath-activity-characterization-golden-master.md` exists. All ROADMAP-cited line refs (`BreathSessionStateMachine.dart:189`/`:205`, `restartEngine:282`→`_setupEngine:139`, `_onTick:237`) match the plan and the code. ✅ — WARN: the plan body itself does not cite its spec note; harmless but worth adding for traceability.

## Verification Against Code

Every "Key fact" in the plan was checked against the real source:

| Plan claim | Verified |
|---|---|
| Harness exposes `init/tick/resume/pause/complete/restartEngine` + `states/channel/instructionStream` | ✅ `BreathActivityHarness.dart:130,136,146-158` |
| `vm.stream` is NOT deduped; only `super.state` is | ✅ `BreathSessionViewModel.dart:108-115` — `_stateController.add` fires unconditionally; `super.state` gated by `equalsIgnoringTickFields` |
| An ignored tick produces no emission (`states.length` reliable probe) | ✅ `_onTick` returns early before any `_emit` (`BreathSessionStateMachine.dart:235-240`) |
| Default DTO → inhale=2/exhale=2, `cycleDuration=4`, `repeatCount=1` | ✅ `makeExercise` (`BreathActivityFakes.dart:191`), `cycleDuration` = sum of step durations (`BreathExerciseDTO.dart:19`) |
| Initial emission: `pause/inhale/idx=0/remaining=2/resetReason=null` | ✅ `_initialBreathState` (`:138`) + `_setupEngine` full-constructor (`BreathSessionViewModel.dart:152-170`) |
| `_hasStarted`: first resume → `ResetReason.start`, later → null; pause clears to null | ✅ `resume()` (`:189`/`:205`), `pause()` full-constructor `resetReason:null` (`:167-180`) |
| `restartEngine()` rebuilds a fresh state machine, counters zeroed, `_hasStarted=false` | ✅ `restartEngine` → `_onModuleReset` + `_setupEngine` (`:282-286`); new `BreathSessionStateMachine` with `_exerciseIndex=0`, `_hasStarted=false` (`:80-83`) |
| `complete()` emits `remainingTicks:0` and cancels the tick sub | ✅ `:216-231` |
| `ResetReason`/`BreathSessionStatus`/`BreathPhase`/`BreathSessionState` exported from barrel | ✅ `breath_module.dart:23`; enums declared in `BreathSessionState.dart` |

### Tick-progression math for Task 3 (two-exercise session) — traced and correct

With `[makeExercise(), makeExercise()]` (each `cycleDuration=4`, `repeatCount=1`):
- `resume()` → `breath/inhale/idx=0`.
- Ticks 1–4: tick 4 hits `_cycleTick>=4` → `_repeatCounter` exhausts repeatCount → `_advanceExercise` → `idx=1`, `_startNewCycle(isExerciseChange)` → `breath/inhale/idx=1`. ✅ "advances to ex1"
- Ticks 5–8: tick 8 → `_advanceExercise` → `idx=2 >= length(2)` → clamps to 1, calls `complete()` → `complete/idx=1/remaining=0`. ✅
- `restartEngine()` → fresh `_setupEngine` → `pause/inhale/idx=0/remaining=2/resetReason=null`. ✅
- `resume()` after restart → `_hasStarted=false` again → `ResetReason.start`. ✅

All four tasks' expected input→output tuples are consistent with the actual state machine.

## Findings

### Non-blocking note (optional robustness)

**`setUp` performs `await harness.init()` with no `pumpEventQueue()` before the first baseline read in Task 4 Case A and the Task 1 smoke anchor.**

Task 4 Case A records `states.length` and reads `states.last` *before* firing any tick (i.e. before its first pump); the Task 1 smoke anchor likewise asserts on the initial emission. This relies on the `_setupEngine` emission already being delivered to the `states.add` listener by the time `await harness.init()` returns.

Analysis: it is delivered. `_stateController.add` is called inside `initState`'s post-`getSession` continuation and schedules the listener microtask *before* `initState`'s future completes; by FIFO microtask ordering that delivery runs before `setUp`'s `await` resumes. So `states` reliably contains exactly one element after init. **No correctness bug** — `states.last` will not throw.

Recommendation (consistency, not correctness): the plan's own Key-facts rule is "pump after each input," and every existing test pumps before reading `states`. Adding `await pumpEventQueue();` at the end of `setUp` (right after `await harness.init()`) makes the baseline reads bulletproof against any future change to the harness's delivery timing and keeps the new suite consistent with `breath_activity_harness_test.dart`. Cheap; worth doing.

## Positive Notes

- Correctly scoped to the **current** schema fields and explicitly forbids asserting on `lifecycle`/`isLive` (which don't exist yet — added by note 05). Confirmed: `BreathSessionState` currently has no such fields, so the guard is accurate and prevents premature coupling.
- Correctly forbids touching `breath_session_state_machine_test.dart` / `breath_module_state_channel_test.dart` (the preserved inner contract).
- The `_hasStarted` discriminator — flagged in the ROADMAP as the *sole untested* "not-started vs paused" signal — is the centerpiece of Task 2, expressed as observable first-vs-second-resume `resetReason` output. This is exactly the gap the milestone exists to close.
- Task dependencies are sane (Task 1 scaffolds; 2/3 depend on 1; 4 depends on 2/3) and Task 4 ends with the explicit green-run gate using the full Flutter path per project memory.
- File placement (`test/BreathModule/Support/`), imports, and the `expectState` partial-assertion helper pattern all match the existing harness conventions.

PLAN_REVIEW_PASS
