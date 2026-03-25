## Code Review Summary

**Plan Reviewed:** `10-remove-lib-core-api-authinterceptor-dart.md`
**Risk Level:** Plan-only (no code changes — staged file is the plan itself)

---

### Critical Issues

None. The previous review's critical blocker (plan assumed Dio APIs were already replaced) has been addressed. The plan now has a clear **BLOCKED** prerequisite section that gates execution on milestones 2.5–2.11.

---

### Suggestions

#### 1. `docs/core/testing.md` is in English, not Russian

Task 5 says: *"These docs are written in Russian — preserve the language when editing."*

This applies to 3 of the 4 listed files (`jwt-authentication.md`, `global-listeners.md`, `login-flow.md`), but `testing.md` is written in English. The blanket statement could mislead the implementer into writing Russian text in an English doc.

**Fix:** Change to: *"Three of these docs are written in Russian (`jwt-authentication.md`, `global-listeners.md`, `login-flow.md`) — preserve the language when editing. `testing.md` is in English."*

#### 2. Parent `CLAUDE.md` not covered

The parent repo's `/Users/max/projects/mind/CLAUDE.md` (line 91, cross-project coordination section) also references `AuthInterceptor`:

```
Auth token handling lives in `mind_api/src/auth/` and `mind_mobile/lib/Core/Api/AuthInterceptor.dart` + `lib/User/`
```

This is a separate git repository, so it's reasonable to exclude from this plan's scope. However, the plan should note it as a **follow-up action** so the reference doesn't go stale. A one-line note under Task 4 would suffice.

#### 3. Phase 4.3 redundancy could be stated more precisely

Task 4 says to update ROADMAP Phase 4.3 "to note the file is already deleted." Phase 4.3 currently reads:

```
delete `lib/Core/Api/HttpClient.dart` and `lib/Core/Api/AuthInterceptor.dart`
```

The plan should specify to **remove the `AuthInterceptor.dart` mention** from that line entirely (not just add a note), since keeping a "already deleted" annotation in a roadmap checkbox is noise. The line should become:

```
delete `lib/Core/Api/HttpClient.dart`
```

---

### Positive Notes

- The BLOCKED prerequisite section with concrete verification steps (grep, file existence, ROADMAP checkmarks) directly addresses the previous review's critical finding.
- The `saveToken`/`clearToken` removal in Task 1 includes a grep safety check: "if callers exist, leave these methods in place." This correctly handles the edge case where milestone ordering might leave residual callers.
- Content/pattern-based references replace the brittle line-number references from v1.
- ROADMAP.md and DESCRIPTION.md NFR section are now included in Task 4, closing the gaps from the previous review.

REVIEW_PASS
