## Code Review

**Plan:** Fix `docs/home/suggestions-widget.md` line 27
**Scope:** 1 doc file changed, 2 new `.ai-factory/` files (plan + plan review)

### Changes reviewed

| File | Change |
|------|--------|
| `docs/home/suggestions-widget.md` | Line 27: replaced `LiveBreathSessionEnded` with `ModuleSessionEnded` из `moduleStateChannel` |
| `.ai-factory/plans/64-fix-…` | New plan file (task marked complete) |
| `.ai-factory/plan-reviews/64-fix-…` | New plan review file |

### Verification

- `HomeService.observeChanges()` (lines 56–58) filters `moduleStateChannel.events` for `ModuleSessionEnded` and maps to `StatsInvalidated` — the updated doc text matches this exactly.
- `LiveBreathSessionEnded` does not exist anywhere in the codebase — the old reference was stale.
- Doc language remains Russian, consistent with the rest of the file.

### Issues

None.

REVIEW_PASS
