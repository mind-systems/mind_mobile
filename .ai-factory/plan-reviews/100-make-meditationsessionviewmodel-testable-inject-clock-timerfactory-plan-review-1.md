# Plan Review: Make `MeditationSessionViewModel` testable: inject Clock + TimerFactory

**Plan:** `100-make-meditationsessionviewmodel-testable-inject-clock-timerfactory.md`
**Files Reviewed:** 1 plan + 4 codebase files (VM, `MeditationModule.dart`, `ActiveRrSource.dart`, note 181)
**Risk Level:** 🟢 Low

## Verification Against the Codebase

Every assumption in the plan was checked against the actual source:

- **Target file & current state** — `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart` exists and matches the plan's description exactly: constructor `MeditationSessionViewModel({required this.poseId})`, fields `_stateController`, `elapsedSeconds`, `_timer`, `_startedAt`, and a `start()` that already does the wall-clock delta (`_startedAt = DateTime.now()` + `elapsedSeconds.value = DateTime.now().difference(_startedAt!).inSeconds`). The two `DateTime.now()` calls and the inline `Timer.periodic(...)` the plan targets are present at lines 41/43/44. ✅
- **Reference pattern (`ActiveRrSource`)** — confirmed at `lib/Biometrics/ActiveRrSource.dart:28-34`: `DateTime Function() clock = DateTime.now` and a timer factory default, both stored via the initializer list into private final fields. The plan mirrors this faithfully. ✅
- **Constructor tear-off defaults compile** — `DateTime.now` / `Timer.periodic` as default parameter values are constant constructor tear-offs. `ActiveRrSource` already ships this exact construct (`clock = DateTime.now`, `timerFactory = Timer.new`) and compiles, so the pattern is proven in this repo. ✅
- **`Timer.periodic` signature** — the plan's `Timer Function(Duration, void Function(Timer))` is the correct tear-off type for `Timer.periodic` (callback receives the `Timer`), distinct from `Timer.new`'s `void Function()`. Correct. ✅
- **Sole instantiation site** — `lib/MeditationModule/MeditationModule.dart:36` constructs `MeditationSessionViewModel(poseId: poseId)` inside the `meditationSessionViewModelProvider.overrideWith(...)` factory. It passes only `poseId`, so the new optional params with defaults make this a true non-breaking change. No other production call site exists (the other grep hits are docs/notes/old reviews). Task 3's "verify wiring unaffected" is accurate. ✅
- **Consumer alignment (test plan note 181)** — note 181 §"Refactor Required" specifies the exact same signature the plan adopts (`clock = DateTime.now`, `timerFactory = Timer.periodic`). The plan is actually *more* correct than note 181's stray example (which shows a non-existent `IMeditationSessionService service` positional); the plan correctly keeps `required this.poseId`. ✅

## Context Gates

- **Rules (`RULES.md`)** — **PASS.** Rule "All dependencies must be injected via constructor" is directly satisfied: clock and timer factory move from hard-coded calls to constructor parameters. No rule conflicts.
- **Architecture** — **PASS.** Change is confined to the presentation package's ViewModel; no module-boundary, DTO, or domain-leak concerns. Consistent with the established "make X testable: inject clock + Timer factory" seam pattern already applied to `ActiveRrSource`, `BiometricBatcher`, and `GrpcConnectionManager` (ROADMAP lines 107/109/111).
- **Roadmap** — **WARN (non-blocking).** This task is not visible as an explicit `[ ]` entry in `ROADMAP.md`, though it clearly belongs to the existing test-infrastructure theme and its consumer test plan (note 181) is on record. Consider linking it to a roadmap/ROADMAP_TESTS entry for traceability, mirroring how the `ActiveRrSource` seam (ROADMAP:107) and its tests (ROADMAP_TESTS:19) were tracked as paired items.

## Observations (non-blocking)

1. **"Testing: no" on a "make testable" task** — intentional and consistent with the repo's pattern: seam injection ships as its own step, the actual `FakeAsync`/`FakeTimerFactory` tests (note 181, including the key regression guard "advance clock 30 s, fire 5 ticks → expect 30") land as a separate follow-up. Worth confirming that follow-up is queued so the seam doesn't sit unused.
2. **`flutter analyze` path** — Task 3 calls for `flutter analyze` on the package. Per project memory, the binary is at `/usr/local/bin/flutter`; the implementing agent should use the full path.
3. **Behavior preservation** — the plan correctly stresses keeping the wall-clock delta semantics (not an accumulator) and leaving `stop()`/`build()`/state-setter/disposal untouched. This matches the current code and avoids regressing the note-141 wall-clock fix.

## Positive Notes

- Pins the exact reference implementations (`ActiveRrSource`, `GrpcConnectionManager`) so the implementer copies a proven, compiling pattern rather than improvising.
- Tasks are correctly ordered with explicit dependencies (1 → 2 → 3) and scoped to a single file plus a verification sweep.
- Provides concrete before/after code that matches the real current source, minimizing guesswork.
- Correctly identifies the change as non-breaking and justifies it via the defaults + single call site.

The plan is accurate, well-scoped, and grounded in verified codebase facts. The only item is an optional roadmap-linkage WARN, which does not block implementation.

PLAN_REVIEW_PASS
