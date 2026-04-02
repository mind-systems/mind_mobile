## Plan Review Summary

**Plan:** Fix `docs/home/suggestions-widget.md` line 27
**Files Affected:** 1 (docs only)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — `WARN` No architectural concerns for a docs-only change.
- **RULES.md** — `WARN` No rule violations.
- **ROADMAP.md** — Aligns with roadmap item **11.2** ("Fix suggestions-widget.md event source"), currently marked `[ ]`.

### Verification

**Code matches the plan's claims:**

- `HomeService.observeChanges()` (lines 56–58) derives `StatsInvalidated` from `moduleStateChannel.events.where((e) => e is ModuleSessionEnded)` — confirmed.
- `ModuleSessionEnded` is defined in `lib/Core/Grpc/ModuleStateEvent.dart` (line 12) as part of the `sealed class ModuleStateEvent` hierarchy — confirmed.
- `LiveBreathSessionEnded` no longer exists anywhere in the codebase (deleted during Phase 7.2) — the current doc reference is stale.
- Line 27 of `docs/home/suggestions-widget.md` contains the exact text the plan targets — confirmed.
- The replacement text is in Russian, matching the language of the existing document (per the user's global rule: "Match the language of existing docs").

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- Correctly scoped: single-line docs fix, no code changes, no tests needed.
- The replacement text accurately reflects the current implementation with specific class and channel names.
- Roadmap linkage is clear (11.2).

PLAN_REVIEW_PASS
