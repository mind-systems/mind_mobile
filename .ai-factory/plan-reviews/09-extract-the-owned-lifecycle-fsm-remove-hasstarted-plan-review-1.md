## Plan Review: Extract the owned lifecycle FSM, remove `_hasStarted`

**Plan:** `09-extract-the-owned-lifecycle-fsm-remove-hasstarted.md`
**Files Reviewed:** 4 source files + 3 test files
**Risk Level:** 🟢 Low

### Verdict
The plan is accurate, well-scoped, and behavior-preserving. Every line-number reference, file path, API, and structural claim was checked against the live codebase and matches. The two notes below are minor robustness/clarity items, not blockers.

### Context Gates
- **Architecture (ARCHITECTURE.md present):** WARN — none. The change stays inside `packages/breath_module/lib/src/BreathSession/`, respects the "domain layer is pure Dart" rule (new `BreathLifecycleMachine` has no Flutter/Riverpod imports), and does not cross the module/DI boundary. No `App.shared` wiring touched.
- **Rules (RULES.md present):** WARN — none. New file introduces no logging (`Logging: minimal` honored); existing `logPrint` call sites untouched. No raw `print`/`debugPrint`.
- **Roadmap (ROADMAP.md present):** WARN — this is a refactor (`refactor`-shaped, not `feat`/`fix`/`perf`), so explicit roadmap milestone linkage is not required. The plan correctly forward-references the follow-up note `10-breath-retire-derived-status` for deferred `status` derivation.

### Verified Assumptions (all correct)
- `_hasStarted = false;` at `:89`; `resume()` at `:189`; `_hasStarted = true;` at `:211`; `pause()` at `:170`; `complete()` at `:214`; `_onTick` at `:241`; `_lifecycleFor` at `:494`; `_emit` at `:507` — **all line numbers match exactly.**
- `BreathLifecycle` enum is defined in `Models/BreathSessionState.dart:19`; relative import path `import 'Models/BreathSessionState.dart';` from the sibling new file is correct.
- Initial states (`_initialRestState`/`_initialBreathState`) are assigned to `_state` **directly, not through `_emit`**, so the constructor default `lifecycle: BreathLifecycle.notStarted` already governs the initial emission — consistent with a fresh `BreathLifecycleMachine` starting at `notStarted`. No initial-emit gap.
- `restartEngine()` (`:297`) → `_setupEngine()` (`:152`) → `new BreathSessionStateMachine(...)` (`:156`), which will construct a fresh `BreathLifecycleMachine` at `notStarted`. The "restart re-arms start reason" behavior (characterization test, `:179`) is preserved by rebuild, exactly as the plan states. ViewModel needs no edits.
- The tick-gate rewrite `if (!_lifecycle.isRunning) return;` is provably equivalent to the existing `status == pause || status == complete` early-return: the owned machine maintains the invariant `running ⇔ status ∈ {breath, rest}` (only `run()`/`pause()`/`complete()` mutate lifecycle, and each is paired with the matching status emit; tick-driven emits never touch lifecycle). The retained `switch (_state.status)` below the gate still correctly selects breath-vs-rest progression.
- Behavioral trace of pre-resume pause (`notStarted` no-op → stays `notStarted`), first resume (`start` + `run()` → `running`), manual pause (`running → paused`, `isLive` stays true), warm resume (`null` reason), and `complete()` (any → `completed`) all reproduce current `_lifecycleFor` outputs. Golden master and isLive suites should pass with no assertion edits.
- The three referenced test files all exist at the stated paths.

### Critical Issues
None.

### Minor Notes (non-blocking)

1. **Make the "mutate before `_emit`" ordering explicit for `resume()`/`run()`.**
   Because `_emit` now stamps `_lifecycle.current` (replacing `_lifecycleFor(newState.status)`), every lifecycle mutation MUST be invoked *before* the corresponding `_emit(...)` call, or the wrong value gets stamped. The plan states this explicitly for `pause()` ("before emitting") and `complete()` ("before emitting"), but for `resume()` it only says "compute reason ... then call `_lifecycle.run()`" without anchoring it relative to `_emit`. In the current code `_hasStarted = true;` sits *after* `_emit` (`:211`); a literal-minded implementer could leave `_lifecycle.run()` there and emit `running` as `notStarted`. Recommend the plan say: in `resume()`, call `_lifecycle.run()` **before** `_emit(...)` (and delete the trailing line, do not relocate it).

2. **Acceptance bullet "No remaining references to `_hasStarted`" collides with test-file comments/group names.**
   `_hasStarted` currently appears not only in production code but in comments and a group description string inside the two passing test files (`breath_activity_boundary_characterization_test.dart` group `'resume discriminator (\`_hasStarted\`)'` and inline comments; `breath_lifecycle_islive_test.dart` reason strings). A strict reading of "no remaining references in the codebase" would require editing those strings. That is compatible with "no assertion edits" (comment/description text is not an assertion), but the plan should make the scope unambiguous — either (a) narrow the acceptance to "no remaining references in production code," or (b) explicitly permit updating stale `_hasStarted` mentions in test comments/group names. As written the implementer faces a contradictory pair of acceptance criteria.

### Positive Notes
- Excellent precision: exact line anchors, an explicit "do NOT add `completed → notStarted`" guard rail, and a clear statement that `status` derivation is deferred to a named follow-up note — keeping this change single-concern.
- Correctly identifies that `complete()` should transition from any state (matching the old `_lifecycleFor(complete)` which ignored `_hasStarted`), avoiding an accidental behavior change.
- Correctly leaves `BreathLifecycleMachine` un-exported (internal `lib/src/` collaborator used only by the state machine), so no package barrel edit is needed.
- The model doc-comment updates (`BreathSessionState.dart:10`, `:51`) are included, so the "derived from `(status, _hasStarted)`" language won't go stale.

Address note 1 (one clarifying sentence) and note 2 (scope wording) if convenient; neither blocks implementation, and the plan as written will produce correct, behavior-preserving code if the implementer recognizes the `_emit` ordering requirement.

PLAN_REVIEW_PASS
