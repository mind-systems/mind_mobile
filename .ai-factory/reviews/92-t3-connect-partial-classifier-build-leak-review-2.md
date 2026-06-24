# Code Review (round 2): T3 · connect() partial classifier-build leak

**Branch:** phase-55-serialize-bci-lifecycle
**Scope reviewed:** `lib/Bci/Ports/BuildAllOrDispose.dart` (new), `lib/Bci/Ports/NeiryClassifierSet.dart` (modified), `test/Bci/build_all_or_dispose_test.dart` (new)
**Risk Level:** 🟢 Low

## Summary

Re-review after round 1. The single round-1 finding — an unnecessary `dart:async` import in the test — has been resolved: the test now imports only `package:flutter_test/flutter_test.dart` and `package:mind/Bci/Ports/BuildAllOrDispose.dart`. The removal is correct because the symbols still used (`Future`, `Duration`, `StateError`) come from `dart:core`, not `dart:async`.

Re-verified the full picture this round:
- **`flutter analyze`** on all three touched files: **No issues found.** (clean — the round-1 lint is gone)
- **Both test suites pass:** all 10 tests green (4 new `buildAllOrDispose` tests + 6 existing classifier-port / A2-regression tests, confirming the public surface is untouched).

## Correctness verification (re-confirmed)

- **Leak window closed.** Mid-build throw → `buildAllOrDispose` disposes already-built classifiers in reverse order before `rethrow`. ✔
- **No `LateInitializationError`.** The four `late final` locals are read only at `NeiryClassifierSet._(...)`, reached only when every build step succeeded; a thrown step rethrows before that line. ✔
- **Failed-constructor classifier not disposed.** Each step assigns its local then returns the `dispose` tear-off; a throwing constructor never registers a disposer. ✔
- **No double-dispose.** Factory rethrows without assigning `_classifierSet`; `connect()`'s catch `_classifierSet?.dispose()` stays a no-op, so each built classifier disposes exactly once. ✔
- **Sync-throw + async-reject guard** present (`try { unawaited(dispose().catchError(...)); } catch (_) {}`) and both flavours exercised by tests. ✔
- **Behaviour-preserving happy path** — build order NFB → Cardio → Emotions → MEMS unchanged; `ClassifierSet` interface, stream getters, `dispose()`, and `NeiryClassifierFactory` untouched. ✔
- **Purity constraint honoured** — `BuildAllOrDispose.dart` imports only `dart:async`; no `neiry_kit`/Flutter, keeping `neiry_kit` confined to the two permitted files. ✔

## Notes (not action items)

- Reverse-order partial-build cleanup (LIFO) vs. forward-order steady-state `dispose()` is intentional and harmless — classifiers are independent.
- Fire-and-forget disposal at the synchronous factory boundary (device may be torn down before disposals settle) is accepted by design and strictly better than the prior leak.
- Silent error-swallowing in the helper is the documented trade-off for purity + "Logging: minimal".

## Verdict

No correctness, security, or runtime-safety issues. The round-1 nit is resolved, analyzer is clean, and all tests pass. Implementation matches the plan and the spec's done-when.

REVIEW_PASS
