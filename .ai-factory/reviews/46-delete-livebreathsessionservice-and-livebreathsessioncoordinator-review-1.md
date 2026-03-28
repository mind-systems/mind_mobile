## Code Review Summary

**Files Reviewed:** 3 (+ plan, orchestrator-state, prior review — skipped)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** WARN — `BreathModuleStateChannel` and `BreathModuleInstructionStream` now live in `lib/BreathModule/Core/` but are not mentioned in CLAUDE.md's domain-layer bullet list. The architecture doc itself is fine; the gap is in CLAUDE.md's BreathModule internals section (see Suggestions).
- **RULES.md:** No violations.
- **ROADMAP.md:** WARN — Milestones 7.1-7.6 all have every task checked `[x]` but are not yet in the Completed table. Only 7.7 was added. This is consistent with the plan (Task 3 only asked to mark 7.7), but the entire Epic 7 appears done.

### Critical Issues

None.

### Suggestions

1. **Stale doc reference in `docs/home/suggestions-widget.md:27`** — still says `StatsInvalidated` is triggered by `LiveBreathSessionEnded`, but the actual source is now `ModuleSessionEnded` via `moduleStateChannel.events` (see `lib/HomeModule/HomeService.dart:56-58`). Worth updating since the plan's stated goal was cleaning up stale references.

2. **CLAUDE.md domain-layer list is incomplete** — the BreathModule domain layer section (line 82-85) lists `BreathSessionNotifier`, `BreathModule.dart`, and three services, but omits `BreathModuleStateChannel` and `BreathModuleInstructionStream` which are now key domain components in `lib/BreathModule/Core/`. Consider adding them for future readers.

### Positive Notes

- All three planned tasks were executed correctly and minimally — no over-editing.
- The CLAUDE.md component count was properly decremented from 5 to 4, and the `LiveSessionCoordinator` bullet was cleanly removed.
- The `.mmd` diagram sources are already clean (no stale references) — the SVG artifacts will self-correct on next CI run.
- ROADMAP structure is consistent: task checked off, row added to Completed table with date.

REVIEW_PASS
