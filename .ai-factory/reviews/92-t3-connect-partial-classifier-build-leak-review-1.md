# Code Review: T3 · connect() partial classifier-build leak

**Branch:** phase-55-serialize-bci-lifecycle
**Scope reviewed:** `lib/Bci/Ports/BuildAllOrDispose.dart` (new), `lib/Bci/Ports/NeiryClassifierSet.dart` (modified), `test/Bci/build_all_or_dispose_test.dart` (new)
**Risk Level:** 🟢 Low

## Summary

The change implements the plan faithfully. The `NeiryClassifierSet` initializer-list constructor is converted to a `factory` + private `._()` constructor that builds the four classifiers through a new pure-Dart `buildAllOrDispose` helper, closing the partial-construction native-resource leak. Public surface (`NeiryClassifierSet(neiry.Device)`), the `ClassifierSet` interface, all stream getters, and `NeiryClassifierFactory` are untouched — minimal blast radius.

I verified behaviour by running both suites: **all 10 tests pass** (4 new helper tests + the 6 existing classifier-port/A2-regression tests). `flutter analyze` on the three touched files reports no warnings/errors (one info-level lint — see Minor #1).

## Correctness verification

- **Leak window closed.** On a mid-build throw, `buildAllOrDispose` invokes the disposers of already-built classifiers in reverse order before `rethrow`. Previously these leaked because `connect()`'s `_classifierSet?.dispose()` was a no-op (set never assigned). ✔
- **No `LateInitializationError` on the failure path.** The four `late final` locals are read only at `NeiryClassifierSet._(nfb, cardio, emotions, mems)`, which is reached only after `buildAllOrDispose` returns normally (all steps succeeded). When a step throws, `buildAllOrDispose` rethrows and the `._()` line is never executed, so unassigned locals are never read. ✔
- **Failed-constructor classifier is not disposed.** Each step closure assigns the local *then* returns the `dispose` tear-off; if `neiry.XClassifier(device)` itself throws, the closure throws before adding a disposer, so only successfully-built classifiers are disposed. Correct — no dispose call on a half-constructed object. ✔
- **No double-dispose.** On failure the factory rethrows without assigning `_classifierSet` in `connect()`; the catch's `_classifierSet?.dispose()` stays a no-op, so each built classifier is disposed exactly once (by the helper). ✔
- **Sync-throw guard present and exercised.** The reverse-dispose loop wraps each `dispose()` call in `try { unawaited(dispose().catchError(...)); } catch (_) {}`, guarding both an async rejection and a *synchronous* throw from a non-`async` disposer (the real native dispose). The plan-review's critical issue from round 1 is correctly addressed, and the test suite exercises both flavours. ✔
- **Build order preserved** (NFB → Cardio → Emotions → MEMS), so the happy path is behaviour-preserving. ✔
- **Purity constraint honoured.** `BuildAllOrDispose.dart` imports only `dart:async` — no `neiry_kit`, no Flutter — keeping it unit-testable and keeping `neiry_kit` confined to the two permitted files. ✔
- **`late final` assignment from closures** compiles cleanly (analyzer raises nothing); this is a valid Dart pattern for write-once locals captured by builder closures. ✔

## Minor Issues / Nits

1. **(Nit, non-blocking) Unnecessary `dart:async` import in the test.** `flutter analyze` flags `test/Bci/build_all_or_dispose_test.dart:1` — `unnecessary_import`: `dart:async` is already re-exported via `package:flutter_test/flutter_test.dart`. The test uses `Future`/`Duration` only. Dropping the `import 'dart:async';` line clears the lint. This is the only analyzer finding and does not affect behaviour. (Note: the production `BuildAllOrDispose.dart` *does* need its `dart:async` import for `unawaited`/`Future` and is correctly kept.)

## Notes (not action items)

- **Reverse-order cleanup vs. forward-order `dispose()`.** Partial-build cleanup runs in reverse (LIFO: mems→…→nfb), whereas the steady-state `dispose()` method disposes forward (nfb→…→mems). This asymmetry is intentional and harmless — each classifier is independent — and LIFO is the conventional cleanup order. No change needed.
- **Fire-and-forget disposal vs. device teardown.** As the plan acknowledges, the synchronous factory cannot await the partial-build disposals, so in `connect()`'s catch the device may be disconnected/disposed before they finish. This is strictly better than the prior leak and matches the same native disposals the happy path performs; accepted by design.
- **Intentional silent error-swallowing** in the helper (no `logPrint`) is a deliberate trade-off to keep the file pure-Dart/testable per "Logging: minimal". Documented in the plan.

## Verdict

No correctness, security, or runtime-safety issues. The single finding is a trivial unnecessary-import lint in test code. Implementation matches the plan and the spec's done-when (failure-atomic construction, forced-throw self-dispose covered by tests, suites green).
