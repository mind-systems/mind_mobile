# Plan Review — 40-define-module-boundary-types-in-packages-bci-module (round 3)

## Summary

**Plan:** Define DTOs, state model, and Service/Coordinator interfaces for the `bci_module` package boundary (Phase 17, milestone 11).
**Scope:** 8 tasks, all new files inside `packages/bci_module/lib/src/BciPairing/` plus barrel exports.
**Risk Level:** 🟢 Low — interface-only work, no runtime behaviour, no migrations.

Round 2's BLOCKING finding (the `scan` arity bug in Task 6's implementer-guidance snippet) and its cosmetic notes have all been folded in:

- Task 6 snippet now calls `.scan<BciPairingState>((acc, event, _) => _applyEvent(acc, event), BciPairingState.initial())` with two arguments — matches RxDart 0.28's `ScanStreamTransformer` signature. ✅
- "Does not emit the seed on subscribe" nuance is now documented inline, with `.startWith(...)` cited as the escape hatch if an immediate emission is required. ✅
- Round-2 nit #3 (redundant `(depends on Task 1)` annotations on Tasks 2/3/4) — fixed: tasks 2, 3, 4 now say `(no dependencies)`, with the Phase-1 commit boundary called out at the top of the phase. ✅
- Round-2 nit #4 (document `calibration == null` semantics) — fixed: Task 5 now has a dedicated doc sentence on the `calibration` field. ✅
- Round-2 note #2 (`initial()` style) — plan now explicitly justifies keeping the `static` method shape over `factory` / `static const`, citing the milestone spec. ✅

No new issues surfaced on this round.

## Context Gates

- **ARCHITECTURE.md:** ✅ Module Boundary respected — package-local DTOs / enums, no `package:mind/Bci/…` imports, domain models stop at the concrete-service boundary (to be implemented in the next milestone). Aligned with the dependency rules.
- **RULES.md:**
  - Rule #1 (stateless module Services) — ✅ Task 6 explicitly tells the next-milestone implementer to use `bciNotifier.stream.scan(...).map(...)`, no `StreamController` / `StreamSubscription` / `dispose()`.
  - Rule #2 (no module state in App.dart) — N/A for this plan; this is package-side type declarations only.
  - Rule #3 (constructor injection) — N/A for this plan; no concrete classes introduced.
- **ROADMAP.md:** ✅ Plan matches the Phase 17 milestone bullet at `ROADMAP.md:91` (DTO fields, file paths, enum variants). The plan deliberately renames the roadmap's `events` getter to `observeChanges()` method for sibling-interface consistency (`IBreathSessionListService.observeChanges()`, `IBreathSessionService.observeSession(id)`); the rationale is documented in Task 6. Acceptable revision — the roadmap entry is a sketch, the plan is the spec.

## Critical Issues

_None._

## Architectural notes

_None._

## Smaller findings

### 1. `stagesCompleted` semantics could be slightly tighter

Task 4 documents `stagesCompleted` as "0–4 (one entry per stage emitted by domain `BciCalibrationStageFinished`)". The domain's `BciCalibrationStageFinished` carries a `stage` integer field — so the DTO field name `stagesCompleted` (a count) is a deliberate translation from the domain's stage-index event. Worth one sentence in Task 4 making explicit whether the reducer increments by 1 on each `BciCalibrationStageFinished` (count semantics, ignoring the stage payload), or whether it derives `stagesCompleted = max(prev, event.stage + 1)` (idempotent, recoverable across reorderings). Either is fine — but the next-milestone implementer will have to pick one.

Not blocking. The current invariant doc plus the "isComplete is authoritative" note already cover the consumer side; this gap is on the reducer side, where the next milestone already owns the choice.

### 2. Single-variant sealed event class — still ceremonial

`BciPairingServiceEvent` has one variant today (`BciPairingStateUpdated`). Rounds 1 and 2 already accepted this as forward-compat headroom matching `BciNotifierEvent`. Keeping for the record only; not a new finding.

## Positive Notes

- The Task 6 snippet is now compilable as written — copy-paste-ready for the next milestone.
- The "RxDart 0.28's `scan` … does not emit the seed on subscribe" caveat is exactly the kind of cross-cutting detail that bites implementers without explicit documentation; calling out `.startWith(...)` as the remedy is the right level of detail.
- Phase 1's commit-boundary note (Tasks 1–4 have no inter-dependencies, grouped by the commit) accurately reflects task parallelism without forcing serial ordering.
- File paths align with the existing `BciPairing/Models/` scaffold (`.gitkeep` already present from milestone 10).
- Field ordering in `BciPairingState`, DTO style (`const` ctor, `required` named params, no equality overrides), and barrel-export grouping all mirror `breath_module` conventions exactly.
- No `package:mind/Bci/…` imports anywhere — boundary stays clean.
- Verification step in Task 8 uses the absolute Flutter path (`/usr/local/bin/flutter`) per `MEMORY.md`.
- Commit plan is atomic (Phase 1 = data shapes, Phase 2 = behaviour contracts).

## Recommendation

Plan is ready for implementation. The single round-3 nit (Task 4 reducer semantics) is small enough that the next-milestone implementer can resolve it in-flight without re-review.

PLAN_REVIEW_PASS
