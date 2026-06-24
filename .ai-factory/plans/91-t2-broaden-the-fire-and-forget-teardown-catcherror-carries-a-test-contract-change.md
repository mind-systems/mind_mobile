# Plan: T2 · Broaden the fire-and-forget teardown `.catchError`

## Context
Harden `_teardownAfterUnexpectedDrop`'s fire-and-forget command in `NeiryBciProvider` so that any non-`QueueClosedException` throw (e.g. a thrown `sub.cancel()` or a thrown `_locatorFactory()` recreate) is logged and swallowed instead of escaping as an unhandled zone error — and update the B2 characterization test that deliberately pins the old "surfaces as unhandled async error" behavior.

## Settings
- Testing: yes (existing suite — update one assertion, no new test files)
- Logging: minimal (`logPrint` only, project facade)
- Docs: no

## Tasks

### Phase 1: Production fix

- [x] **Task 1: Broaden the teardown `.catchError` to log-and-swallow non-`QueueClosed` errors**
  Files: `lib/Bci/NeiryBciProvider.dart`
  At the fire-and-forget teardown command's `.catchError(...)` (currently `:462-472`), remove the `test: (Object e) => e is QueueClosedException` restriction so the handler catches **all** errors, then branch inside the callback:
  - If the error **is** a `QueueClosedException` → swallow silently (keep the existing dispose-races-drop semantics). Preserve the existing explanatory comment block describing why this is a knowingly-accepted leak.
  - Otherwise → `logPrint('NeiryBciProvider: unexpected drop teardown error: $e')` and swallow (top-level safety net for the unguarded cancel chain at `:434-443` and the recreate at `_resetLocatorSession` / `_locatorFactory`).

  Use `logPrint` (already imported and used elsewhere in this file, e.g. `:449`, `:457`). Do **not** alter the queue CONSTRAINTs or any `QueueClosedException` dispose-races-drop handling beyond folding it into the broadened handler. Net effect: the teardown command emits no unhandled async error for any in-step throw.

### Phase 2: Test-contract update

- [x] **Task 2: Update the B2 assertion to expect logged-and-swallowed (depends on Task 1)**
  Files: `test/Bci/neiry_bci_provider_full_teardown_test.dart`
  In the test `'throwing connection-sub cancel: propagates to finally; recreate still reached; StateError surfaces as unhandled async error'` (`:618-690`), the `runZonedGuarded` body injects a throwing connection-sub cancel and currently asserts (`:672-679`) that the `StateError` **surfaces** as an unhandled async error (`expect(asyncErrors, isNotEmpty, ...)` and `expect(asyncErrors.any((e) => e is StateError), isTrue, ...)`).

  This is the **deliberate** contract change called out in the milestone — invert the assertion to expect the error is now caught and swallowed:
  - Assert `asyncErrors` is **empty** (`expect(asyncErrors, isEmpty, reason: 'throwing cancel is now logged and swallowed, not surfaced as an unhandled async error')`), removing the `isNotEmpty` / `is StateError` expectations.
  - Update the test name and the doc comment near `:618-624` / `:644-660` so they describe the new "logged-and-swallowed; no unhandled async error" behavior instead of "surfaces as unhandled async error".
  - Keep the existing L1-invariant assertions (`createdCount == 2`, `l0.disposeCount == 1`, `liveCount == 1`, `assertNoOrphan()`) and the post-test controller cleanup (`closeControllers()` on device + classifier set) unchanged — recreate must still be reached.

  This is an intentional green→changed update, not a green→green regression — note it in the commit message so the assertion flip is not mistaken for a B2 break.

## Verification
- `/usr/local/bin/flutter test test/Bci/neiry_bci_provider_full_teardown_test.dart` — the updated suite passes (no unhandled async error for the throwing-cancel case).
- Run the full `test/Bci/` directory to confirm the rest of B1/B2 stays green.

## Commit
Single commit (2 tasks): "Broaden NeiryBciProvider drop-teardown catchError to log and swallow non-QueueClosed errors; update B2 unhandled-error assertion to expect logged-and-swallowed"
