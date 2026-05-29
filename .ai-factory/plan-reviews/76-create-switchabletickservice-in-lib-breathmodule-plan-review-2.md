## Code Review Summary

**Files Reviewed:** 1 plan + reference spec (`notes/29-heart-rate-tick-source.md`) + 4 source files (`ITickService.dart`, `ClockTickService.dart`, `HeartRateTickService.dart`, `ActiveRrSource.dart`) + 5 in-tree test fakes + prior review 1.
**Risk Level:** 🟢 Low

This revision addresses every concrete issue raised in plan-review-1. The five in-tree test fakes that implement `ITickService` are now covered by an explicit **Task 3b**, listed file-by-file with the class names, and rolled into Commit 1's scope so the build stays green at the interface-extension commit. The Notes section is corrected ("exactly nine files"). The constructor-ordering invariant, the `_healthSub` initial-fire safety, the `_activeSub?.cancel()` future-drop, and the "first-tick lag only true after M5" qualifier are now baked into the Task-4–7 bodies.

### Context Gates
- **ARCHITECTURE.md:** No violations. `SwitchableTickService` is added as a sibling of `ClockTickService` / `HeartRateTickService` in `lib/BreathModule/`, mirrors their import style (`package:breath_module/breath_module.dart' show ...` + relative imports), and keeps the package free of any domain leak. Ownership boundary respected (heart child does not dispose upstream `ActiveRrSource` owned by `App.shared`).
- **RULES.md:** No violations. Constructor injection only (`required ClockTickService clock`, `required HeartRateTickService heart`); no `App.dart` mutation; no class wires itself externally. Service interface lives in the package, concrete in `lib/` — facade is in `lib/`, not the package, so no public export update required.
- **ROADMAP.md:** Aligned with Phase 22 Milestone 4. Plan explicitly defers `BreathModule.buildSession()` wiring to M5 and VM/UI to M6/M7. No scope creep.
- **skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present — `WARN` (advisory; no project-specific overrides apply).

### Critical Issues

None. The prior critical blocker (five compiled-into-the-build test fakes left unhandled) is fully resolved in Task 3b with the exact class names and file paths verified against the tree.

### Verified Against the Codebase

- **Interface surface** (`packages/breath_module/lib/src/ITickService.dart`) currently exposes `tickStream`, `source`, `dispose`. Task 1 additions (`sourceChanges`, `trySwitchTo`) match the spec at `notes/29-heart-rate-tick-source.md` lines 268–344 byte-for-byte (modulo whitespace).
- **`ClockTickService`** and **`HeartRateTickService`** both import `breath_module` with a `show` clause that already includes `TickSource` — Tasks 2/3 correctly note "no new imports required".
- **`HeartRateTickService.hasActiveSource` / `hasActiveSourceStream`** exist as documented proxies (lines 25, 29) — exactly what Task 4's constructor and `trySwitchTo` rely on.
- **`ActiveRrSource.hasActiveSourceStream`** is a `BehaviorSubject<bool>.seeded(false).stream` (line 43, 62) — Task 4's note about the listener firing immediately with `false`, guarded by `_activeSource == TickSource.heartbeat`, is accurate.
- **All five test fakes** listed in Task 3b exist with the stated class names:
  - `breath_session_state_machine_test.dart` → `class FakeTickService implements ITickService` (line 10)
  - `breath_session_enriched_state_test.dart` → `class FakeTickService implements ITickService` (line 19)
  - `breath_session_star_toggle_test.dart` → `class _FakeTickService implements ITickService` (line 11)
  - `breath_animation_coordinator_restart_test.dart` → `class _FakeTickService implements ITickService` (line 21)
  - `orb_animation_coordinator_resume_test.dart` → `class _ManualTickService implements ITickService` (line 11)
  All five already import `breath_module` with a `show` clause that includes `TickSource`, so Task 3b's "extend the existing show clause if needed" caveat is a safe precaution but in practice no show-clause edits are required.

### Non-blocking Observations

- **`StreamController<TickSource>.broadcast()` with no seed.** Task 5 explicitly chooses not to seed — late subscribers query `source` for a snapshot. That matches the spec and matches what M6's VM subscription will do, so this is correct.
- **`_switchInternal` is sync but reuses the `cancel()` future.** As Task 6 notes, the un-awaited cancel future is safe because the previous child's already-queued tick callbacks close over the previous `add` site, not a stale `_tickController.add`. The `_tickController` itself is the same instance across switches, so no race on the controller identity exists.
- **`dispose()` ordering** (Task 7): cancel `_activeSub`, cancel `_healthSub`, close own controllers, then propagate `dispose()` down. Avoids a `done` event from the child landing on a still-live forwarding subscription. Plan correctly states this.
- **Commit 1's atomicity matters** — interface + concretes + test fakes ship together. Plan respects this. (If anyone splits the commit later, the test build breaks; the plan's commit prose makes this explicit.)

### Positive Notes

- Each task body now carries the invariant it depends on (constructor ordering, default-source-is-timer, sync-`dispose`, `_activeSub` future drop). Implementer cannot easily reorder or short-cut.
- Task 3b is precisely scoped to "compile fix only — no assertion or behaviour changes" and pre-empts the policy concern that touching tests violates `Testing: no`. The reasoning is correct: existing tests must continue to compile when the interface they consume changes.
- Commit plan now correctly enumerates all nine files. Notes section's "exactly nine files" matches the actual scope.
- Single-source-of-truth model is preserved: `_activeSource` mutated only inside `_switchInternal`; both `source` and `sourceChanges` read from it.
- Auto-fallback is centralised in the facade (not duplicated in the VM), giving M6's VM one subscription point for both manual toggles and silence-driven fallbacks.

PLAN_REVIEW_PASS
