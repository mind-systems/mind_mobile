# Plan Review 2: T3 · connect() partial classifier-build leak

**Plan:** `.ai-factory/plans/92-t3-connect-partial-classifier-build-leak.md`
**Files Reviewed:** 7 (plan + review-1 + 5 source/test files)
**Risk Level:** 🟢 Low

## Verdict

This is the second revision. Every finding from review-1 has been folded into the plan, and an
independent re-check against the live code confirms the premise, the file paths, the API usage, and
the type contracts all hold. The plan is ready to implement.

## Review-1 follow-through (all addressed)

- **Critical Issue #1 — synchronous-throw guard.** The Task 1 snippet now wraps each disposer call in
  a synchronous `try { unawaited(dispose().catchError(...)); } catch (_) {…}` (lines 44-49), exactly
  the fix review-1 prescribed. Task 3 was upgraded to exercise **both** a sync-throwing
  (`() { throw StateError(...); return Future.value(); }`) and an async-rejecting
  (`() async { throw StateError(...); }`) disposer, and the verification section now names both cases
  explicitly (line 97). The regression can no longer slip through on an accident of how the fake is
  written. ✔
- **File-naming.** Task 1 now declares `lib/Bci/Ports/BuildAllOrDispose.dart` (PascalCase) with an
  inline justification, and Task 2's import matches (`import 'BuildAllOrDispose.dart';`). Consistent
  with every existing file in `lib/Bci/Ports/`. ✔
- **Fire-and-forget vs. device teardown ordering.** Task 2 now carries a "Teardown-ordering
  acknowledgement" paragraph (line 81) stating disposer completion is not awaited at the factory
  boundary by design. ✔
- **Observability gap.** Task 1's "Note (intentional silence)" (line 57) documents that the
  failure-path disposers swallow errors silently — a deliberate trade-off for the pure-Dart/testable
  constraint and the "Logging: minimal" setting. ✔
- **Test microtask drain.** Task 3 keeps the drain guidance and correctly notes the dispose *calls*
  are synchronous during the catch, so call-ordering can be asserted without draining. ✔

## Independent verification (this pass)

- **Premise still holds.** `NeiryClassifierSet` builds the four classifiers in an initializer list
  (`NeiryClassifierSet.dart:23-27`); `connect()` assigns `_classifierSet` after the synchronous build
  (`NeiryBciProvider.dart:176`) and the catch's `_classifierSet?.dispose()` (`:180`) is a no-op on a
  mid-build throw. Leak window confirmed. ✔
- **Single construction site.** `NeiryClassifierFactory.build()` (`NeiryClassifierFactory.dart:20`)
  is the *only* caller of `NeiryClassifierSet(...)`. A `factory` + private `._()` keeps the public
  signature identical, so the factory needs no change — as the plan states. ✔
- **Type contract verified against the SDK.** All four classifiers
  (`../neiry_kit/lib/src/api/classifiers/*.dart`) expose `Future<void> dispose() async`, so the
  `nfb.dispose` / `cardio.dispose` / … tear-offs are precisely `Future<void> Function()` and slot
  into the helper's `List<Future<void> Function() Function()>` parameter without a cast. The
  `await _x.dispose()` calls in the existing `dispose()` corroborate this. ✔
- **Idempotent native dispose de-risks the accepted ordering trade-off.** Each classifier's
  `dispose()` is guarded by `if (_disposed) return;`, so the unordered, un-awaited partial-build
  disposals racing the subsequent `device.disconnect()/dispose()` in `connect()`'s catch carry no
  double-free hazard. This strengthens the plan's "strictly better than today's leak" claim. ✔
- **`unawaited` import.** The helper depends on `unawaited`, which lives in `dart:async`; the Task 1
  snippet imports it. ✔
- **No lint trap.** Both swallow sites carry an explanatory comment, so `empty_catches` is satisfied;
  `catch (_) {}` with a body comment already has precedent in `connect()`. ✔
- **`late final` capture is sound.** Each step assigns its captured `late final` local exactly once;
  on the failure path `buildAllOrDispose` rethrows before the `return NeiryClassifierSet._(...)`, so
  an unassigned local is never read. ✔

## Context Gates

- **Architecture:** WARN-free. The change stays within `lib/Bci/Ports/`, keeps `neiry_kit` confined
  to the two permitted files (`NeiryClassifierSet`, `NeiryClassifierFactory`), and the new helper is
  pure Dart with no Flutter/neiry imports — consistent with the project's fake-without-`neiry_kit`
  testability principle. ✔
- **Rules:** No `.ai-factory/RULES.md` constraints beyond naming, which is now satisfied. Logging
  policy (route through `logPrint`) is not violated — the helper's intentional silence is documented
  and scoped to keep it pure Dart. ✔
- **Roadmap:** Traces to spec note `167-bci-connect-partial-classifier-build-leak.md` (Phase 56,
  Tier 2). Linkage present. ✔

## Minor Notes (non-blocking, no action required)

- The helper's parameter type `List<Future<void> Function() Function()>` is correct but dense; a
  one-line `typedef` (e.g. `typedef _Disposer = Future<void> Function();`) would read better. Purely
  cosmetic — the implementer may choose either.
- Task 3's sync-throwing fake `() { throw StateError(...); return Future.value(); }` has an
  unreachable `return` after the `throw`; the analyzer flags this as `dead_code`. Implementers should
  drop the trailing `return` (a closure body that only throws still satisfies the
  `Future<void> Function()` type) or annotate it — trivial to resolve during implementation.

## Positive Notes

- The revision is disciplined: every review-1 point was addressed in-place with rationale, not just
  silently patched, which makes the design intent auditable.
- The build order (NFB → Cardio → Emotions → MEMS) is preserved verbatim, satisfying the
  behavior-preserving guard, and the blast radius stays minimal via the `factory` + `._()` split.
- The testability call — extracting the algorithm into a neiry-free helper — is correct given
  `neiry_kit` cannot run under unit tests, and it mirrors the existing fake-based strategy in
  `test/Bci/neiry_bci_provider_classifier_port_test.dart`.

PLAN_REVIEW_PASS
