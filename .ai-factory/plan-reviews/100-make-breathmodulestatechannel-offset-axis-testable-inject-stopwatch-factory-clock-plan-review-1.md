## Plan Review: Make `BreathModuleStateChannel` offset axis testable

**Plan:** `100-make-breathmodulestatechannel-offset-axis-testable-inject-stopwatch-factory-clock.md`
**Files Reviewed:** 4 (target source, instruction stream, test file, roadmap/notes)
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): No boundary violation. This is a pure DI-seam refactor inside the domain layer (`lib/BreathModule/Core/`) plus a test-only fake change. No new cross-package dependency; the constructor stays a named-parameter constructor in the domain layer. ✅ aligned.
- **Rules** (`.ai-factory/RULES.md` present): No convention conflict. Logging stays via `logPrint` (unchanged); no new logs added (`Logging: minimal`). ✅ aligned.
- **Roadmap** (`.ai-factory/ROADMAP.md` present): Direct linkage confirmed — ROADMAP line 330 describes this exact milestone, including the identical default tear-offs `Stopwatch.new` / `DateTime.now` and the 5-tuple fake extension. ✅ aligned.

### Critical Issues
None.

### Correctness / Codebase-Accuracy Checks (all verified against source)

- **Line references are accurate.** `final Stopwatch _stopwatch = Stopwatch();` is at line 24; `_originWallClock = DateTime.now();` at line 85; the `DateTime.now()` fallback in `_wireTimestamp` at line 140. All three replacement targets exist as described.
- **Default tear-offs compile.** `DateTime Function() clock = DateTime.now` is already an established, compiling pattern in this codebase (`BiometricStreamClient.dart:65`, `ModuleInstructionStream.dart:54`). `Stopwatch.new` is a constructor tear-off and a valid constant expression (SDK `^3.11.0`, well past the 2.15 tear-off feature), so it is a legal named-parameter default. Confirmed.
- **No call sites break.** The only production instantiation is `lib/BreathModule/BreathModule.dart`; the only test instantiation is `_make()` in the test file. Both new params are optional with defaults, so neither needs editing. Confirmed.
- **`sendSample` signature is unchanged**, as the plan states — `BreathModuleInstructionStream.sendSample(sessionId, phase, tickCount, offsetMs, timestampMs)` already takes the 5-tuple, so no interface change.
- **Tuple-equality test sites are correctly enumerated.** I cross-checked every `sendSampleCalls` reference: the only sites comparing against 3-tuple literals are lines 756, 776, 839, 840, 893, 915, 958, 1024, 1055, 1153, 1191 — exactly the set the plan lists. The remaining sites are `hasLength`/`isEmpty` checks or single-field `.$1` reads (1091, 1217), which the plan correctly says need no change (`.$1` = sessionId in both 3- and 5-tuples).
- **`phaseTickCalls` projection is sound.** The getter projects `(c.$1, c.$2, c.$3)` and decouples existing assertions from the nondeterministic `offsetMs`/`timestampMs` that the default real `Stopwatch`/`DateTime.now` would produce — this is the right call, since Phase 1's defaults make those two fields nondeterministic and a naive 5-tuple equality would flake.
- **Single-instance Stopwatch semantics preserved.** Moving `_stopwatch` to an initializer-list assignment from `stopwatchFactory()` keeps one instance reused across `reset()`/`start()` (`..reset()..start()` / `..stop()..reset()`), matching current behavior. `_clock`/`_stopwatch` are assigned in the initializer list before the body, and the body does not touch them — ordering is safe.
- **Stale-note awareness is correct.** The plan explicitly flags that note 182 shows positional params (stale) and that the real constructor uses named params — and follows the actual code. Good defensive read.

### Minor Observations (non-blocking)
- When replacing the field declaration at line 24, retain a `final Stopwatch _stopwatch;` declaration (uninitialized) and assign it in the initializer list — the plan says this, just calling it out so the implementer does not accidentally leave a duplicate initializer.
- Scope discipline is good: the plan correctly defers the actual offset/monotonicity/pause-marker assertions (Gaps 1–6) to a follow-up milestone and only lays the seams here. The "existing suite stays fully green" acceptance check (`flutter test test/BreathModule/breath_module_state_channel_test.dart`) is the right gate for an enablement-only change.

### Positive Notes
- Consistent with the codebase's established "make X testable: inject clock/factory" pattern (ActiveRrSource, BiometricStreamClient, ModuleInstructionStream, GrpcConnectionManager) — same default-tear-off convention.
- Every line number and API claim in the plan checks out against the current source; no fantasy holes for the implementer to guess.
- Behavior-preserving by construction: defaults reproduce `Stopwatch()` and `DateTime.now()` exactly, including the `_wireTimestamp` fallback path now routed through `_clock()`.

PLAN_REVIEW_PASS
