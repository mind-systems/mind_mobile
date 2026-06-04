# Plan Review: Enable starring own breath sessions (flip `canStar` guard)

**Plan:** `13-enable-starring-own-breath-sessions-flip-canstar-guard.md`
**Risk Level:** 🟢 Low
**Verdict:** Solid — every checkable claim verified against the codebase.

## Verification Summary

| Claim in plan | Verified | Notes |
|---|---|---|
| File `lib/BreathModule/BreathSessionDTOMapper.dart` exists | ✅ | Correct path. |
| Line 13 is `canStar: session.userId != currentUserId,` | ✅ | Exact match. |
| Screen guard `if (canStar)` controls the star icon | ✅ | `BreathSessionScreen.dart:348` — confirmed. The field is still consumed, so keeping it is correct. |
| `map` is called from 3 sites in `BreathSessionService.dart` (lines 21, 31, 55) | ✅ | All three pass `currentUserId: _currentUserId`. |
| Write-path is ownership-agnostic | ✅ | `toggleStar` → `service.starSession` → `notifier.starSession` (no userId) → `repository.starSession` → `api.starSession(StarSessionRequest(id, starred))`. No owner guard at any layer below the DTO mapper. |
| Drift schema already has `isStarred` | ✅ | `BreathSession.isStarred` exists; no migration needed. |
| Note-83 star color logic untouched | ✅ | `isStarred ? AppColors.warmAccentDark : AppColors.accent` at line 353 — out of scope, correctly. |
| `currentUserId` becomes unused but Dart won't warn | ✅ | Dart analyzer does not flag unused function parameters; keeping the signature avoids touching 3 call sites. Reasonable minimal-diff choice. |

## Context Gates

- **Architecture (`ARCHITECTURE.md` / `RULES.md`):** No boundary or convention violations. The change stays entirely inside the domain→module DTO mapper; it does not add state to `App.dart`, does not break the stateless-Service rule, and does not alter constructor injection. ✅
- **Roadmap (`ROADMAP.md`):** Strong linkage. The plan is the first task of **Phase 34 — Starred own sessions + cursor pagination with sections** (line 47), spec `notes/99`. Description, file path, line number, and "flip to `canStar: true`" all match the roadmap entry verbatim. The roadmap also confirms the backend has no owner guard, corroborating the "1 line is sufficient" claim. ✅

## Findings

### Critical Issues
None.

### Minor / Non-blocking (WARN)

1. **Semantically stale test name (no failure).** `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart:143` is named `'initState sets canStar=false for own sessions'` and feeds a hand-built DTO with `canStar: false`. These tests use a `_FakeSessionService` and bypass the real `BreathSessionDTOMapper` entirely, so **none will break** — they assert ViewModel propagation, not mapper logic. After this change the test name no longer reflects reality (own sessions now map to `canStar: true`). Plan settings say `Testing: no`, so no update is required, but the stale name is worth a one-line note for whoever migrates these tests later. Not a blocker.

2. **No mapper-level test exists for the flipped behavior.** There is no direct unit test on `BreathSessionDTOMapper.map` asserting the userId→`canStar` relationship, so the flip is unguarded by tests. Consistent with `Testing: no`; flagged only for completeness.

### Positive Notes

- Scope discipline is excellent: the "Out of scope (do NOT touch)" list explicitly fences off list cells (note 100's concern), the write-path, the Drift schema, and the note-83 color logic — each verified as genuinely separate from this change.
- The decision to keep `canStar` as a field (rather than ripping out the guard) is correct: the field is still read by `BreathSessionScreen.dart:348` and `BreathSessionViewModel` lines 150/187, and documents intent.
- The decision to retain the now-unused `currentUserId` parameter avoids churn across 3 call sites with no analyzer cost — a sound minimal-diff trade-off.
- Correctly identifies that no migration is needed and that the backend imposes no owner guard, matching the roadmap's contract notes.

## Conclusion

The plan targets the exact right line, the surrounding architecture supports a one-line change, the write-path is genuinely ownership-agnostic, no migration is needed, and there are no security concerns (the relaxed guard is an intentional product decision backed by the backend, per the roadmap). The only observations are cosmetic test-naming staleness that does not cause failures.

PLAN_REVIEW_PASS
