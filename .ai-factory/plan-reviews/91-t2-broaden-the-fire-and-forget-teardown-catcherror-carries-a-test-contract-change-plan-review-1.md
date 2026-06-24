# Plan Review: T2 · Broaden the fire-and-forget teardown `.catchError`

**Plan:** `91-t2-broaden-the-fire-and-forget-teardown-catcherror-carries-a-test-contract-change.md`
**Risk Level:** 🟢 Low

## Verification of plan claims against the codebase

All line references and API claims in the plan were checked against the current source:

- ✅ `lib/Bci/NeiryBciProvider.dart:462-472` — the fire-and-forget `.catchError(...)` with `test: (Object e) => e is QueueClosedException` exists exactly as described.
- ✅ Unguarded cancel chain at `:434-443` (connectionSub..memsSub `.cancel()` without per-call try/catch) confirmed — this is the real escape path the broadened handler must cover.
- ✅ `_resetLocatorSession()` runs in the `finally` (`:460`); a non-`QueueClosed` throw from it (or from `_locatorFactory` recreate) would currently escape. The plan correctly names this as in-scope.
- ✅ `logPrint` already used at `:449` and `:457` — no new import needed.
- ✅ `QueueClosedException` is in scope at the `.catchError` site (referenced at `:471`); keeping a branch that tests `e is QueueClosedException` inside the broadened callback compiles without new imports.
- ✅ Test `'...StateError surfaces as unhandled async error'` at `test/Bci/neiry_bci_provider_full_teardown_test.dart:618-690`, with the `isNotEmpty` / `is StateError` assertions at `:673-679`, confirmed verbatim.
- ✅ Grep confirms this is the **only** test asserting `asyncErrors isNotEmpty` / `StateError` for the teardown path — no other test depends on the old "surfaces" contract, so the contract flip is correctly isolated to one assertion.
- ✅ The neighboring `throwOnDispose` test (`:600-616`) does not inspect `asyncErrors` (it relies on the existing `logPrint` catch at `:456`), so it is unaffected by the change — consistent with the plan leaving it alone.
- ✅ Verification commands and file paths are correct; `/usr/local/bin/flutter` matches the project's required full path.

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** WARN — none. Change is confined to the domain provider in `lib/Bci/`; no layer/boundary crossing.
- **Rules (`RULES.md`):** PASS — rules govern Module Services (statelessness, constructor DI). `NeiryBciProvider` is a domain provider, not a module Service; no rule applies.
- **Roadmap (`ROADMAP.md`):** Not checked into review scope beyond milestone linkage; the plan is self-described as a milestone task (B2 contract change). No missing linkage to flag for this hardening task.
- **skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** not present — no project-specific overrides to apply.

## Critical Issues

None. The plan is correct, scoped, and the production fix + test flip are logically consistent (the broadened handler removes the very escape the inverted assertion stops expecting).

## Minor Suggestions (non-blocking)

1. **Stale comment after the change.** The existing comment block ends (`:469`) with: *"Swallow only the drop; a real teardown-body error still surfaces (test: below)."* After Task 1 this sentence becomes **false** — a real teardown-body error is now logged and swallowed, not surfaced. The plan says to "preserve the existing explanatory comment block," which would leave this misleading line in place. Recommend explicitly updating that trailing sentence to describe the new log-and-swallow safety net while keeping the `QueueClosedException` dispose-races-drop rationale intact.

2. **Confirm zone-error timing in the flipped test.** The test currently spins several `await Future.delayed(Duration.zero)` cycles (`:658-660`) specifically to let the microtask future reject and reach the zone handler. After the fix there is no rejection, so the new `expect(asyncErrors, isEmpty)` is robust — but keep those trailing pumps (or they're harmless) so the assertion runs after the teardown microtask fully settles. The plan's instruction to keep the L1 invariants and cleanup unchanged already covers this; just verify the `isEmpty` check is placed after the existing delays, not before.

## Positive Notes

- Tight, single-file production change with an explicit, intentional test-contract flip — the plan correctly frames it as a green→changed update and asks for it to be called out in the commit message so it is not mistaken for a B2 regression.
- The plan preserves the `QueueClosedException` dispose-races-drop semantics by folding the test into a branch rather than dropping it — avoids silently changing the accepted-leak behavior.
- Verification covers both the single updated file and the full `test/Bci/` directory to catch any unexpected dependency on the old contract.

PLAN_REVIEW_PASS
