# Plan Review: T3 · connect() partial classifier-build leak

**Plan:** `.ai-factory/plans/92-t3-connect-partial-classifier-build-leak.md`
**Files Reviewed:** 6 (plan + 5 source/test files)
**Risk Level:** 🟡 Medium

## Verdict

The plan is well-scoped, the leak premise is **verified against the actual code**, and the
overall approach (extract a pure-Dart `buildAllOrDispose` helper, convert the constructor to a
failure-atomic factory) is sound and respects every guard in the spec. There is **one substantive
correctness gap** in the example helper code that directly contradicts a guarantee the plan's own
test (Task 3) is written to verify. Fix that and the plan is ready.

## Premise verification (confirmed)

- `NeiryClassifierSet` (`lib/Bci/Ports/NeiryClassifierSet.dart:23-27`) does build the four
  classifiers in an initializer list, in the stated order. ✔
- `connect()` (`lib/Bci/NeiryBciProvider.dart:176`) assigns `_classifierSet` *after* the
  synchronous build, and the catch at `:179-181` calls `_classifierSet?.dispose()` — a no-op when
  the constructor threw mid-build. Leak window confirmed. ✔
- `NeiryClassifierFactory` (`:18-21`) calls `NeiryClassifierSet(raw)` synchronously; a factory
  constructor with the same public signature is a drop-in. No factory change needed. ✔
- `NeiryClassifierSet` is the only construction site (factory is the sole caller). ✔
- The classifier-port test file exists and matches the style the plan references
  (`test/Bci/neiry_bci_provider_classifier_port_test.dart`). ✔

## Critical Issues

### 1. Helper does not guard against a *synchronous* throw from a disposer — breaks Task 3's "dispose-failure isolation" guarantee

The Task 1 example helper guards only **async** dispose failures:

```dart
} catch (_) {
  for (final dispose in disposers.reversed) {
    unawaited(dispose().catchError((Object _) {}));   // guards a *failed Future* only
  }
  rethrow;
}
```

If a disposer throws **synchronously** (a non-`async` `Future<void> dispose() { throw ...; }`, which
is exactly what a hand-written fake disposer `() { throw StateError(...); }` does), the throw
happens on the `dispose()` *call* — before `.catchError` is ever attached. That exception is **not**
caught (we are already inside the `catch (_)` handler), so it:

1. aborts the `for` loop → the remaining earlier disposers never run, and
2. propagates out instead of the `rethrow` → the **dispose error masks the original build error**.

This is precisely the failure mode Task 3's third case asserts against ("assert the remaining earlier
disposers still run and the original build error … is the one that propagates"). Whether the test
passes becomes an accident of how the fake disposer is written (`() async { throw }` survives;
`() { throw }` fails). The prose for Task 1 even states the correct intent — "each guarded so a
dispose failure does not mask the original error" — but the snippet under-delivers on it.

**Fix:** wrap each dispose invocation in a synchronous try/catch as well:

```dart
} catch (_) {
  for (final dispose in disposers.reversed) {
    try {
      unawaited(dispose().catchError((Object _) {}));
    } catch (_) {/* swallow sync throw too */}
  }
  rethrow;
}
```

This also matters for production: the real neiry `dispose()` is not guaranteed to be `async`, so a
synchronous native throw during cleanup would otherwise escape the factory. Recommend the test
explicitly exercises **both** a sync-throwing and an async-rejecting disposer so the guard can't
regress unnoticed.

## Minor Issues / Notes

- **File-name inconsistency (WARN).** Task 1's `Files:` line names `buildAllOrDispose.dart`
  (lowerCamel), but every existing file in `lib/Bci/Ports/` is PascalCase
  (`DevicePort.dart`, `NeiryClassifierSet.dart`, `ClassifierFactory.dart`, …). The plan's own
  prose says "prefer `BuildAllOrDispose.dart` if neighbouring helpers are PascalCase" — and they
  uniformly are. The new file should be `BuildAllOrDispose.dart`, and Task 2's import should match.
  (The test file `test/Bci/build_all_or_dispose_test.dart` is correctly snake_case per Dart test
  convention — no change there.)

- **Fire-and-forget disposal vs. device teardown ordering (minor).** Because the helper is `void`
  (it must be — the factory/constructor is synchronous), partial-build disposers run
  fire-and-forget. In `connect()`'s catch, the device is then disconnected/disposed
  (`:184-185`) potentially *before* those classifier disposals finish. The classifiers hold native
  resources tied to the device. This is almost certainly fine (it's the same teardown the happy
  path's `dispose()` performs, just unordered), but worth a one-line acknowledgement in the plan
  that disposal completion is not awaited at the factory boundary by design.

- **Observability gap (minor, acceptable).** The existing `dispose()` logs each failure via
  `logPrint`; the new failure-path disposers swallow errors silently to stay pure-Dart/testable.
  Given "Logging: minimal" and the pure-Dart constraint, this is an acceptable trade-off — just note
  it so the silence is intentional rather than overlooked.

- **Test microtask drain (correct as written).** The plan's instruction to
  `await Future<void>.delayed(Duration.zero)` before asserting matches the fire-and-forget design.
  Note that the disposer *calls* happen synchronously in reverse order during the catch, so call
  ordering can be asserted without draining; the drain is only needed if the fake records disposal
  inside an async body. Both are fine.

## Context Gates

- **Architecture** (`CLAUDE.md` / module rules): WARN-free. The change stays inside
  `lib/Bci/Ports/`, keeps `neiry_kit` confined to the two permitted files, and the new helper is
  pure Dart (no Flutter/neiry imports) — consistent with the "fake can implement without
  `neiry_kit`" testability principle. ✔
- **Rules:** No `.ai-factory/RULES.md` enforced here beyond naming (see file-name WARN above). ✔
- **Roadmap:** Task traces to spec note `167-bci-connect-partial-classifier-build-leak.md`
  (Phase 56, Tier 2). Linkage present. ✔

## Positive Notes

- Correctly identifies that the public surface (`NeiryClassifierSet(device)`) is preserved by using
  a `factory` + private `._()` constructor, so `NeiryClassifierFactory` and all stream getters stay
  untouched — minimal blast radius.
- Build order is explicitly preserved (NFB → Cardio → Emotions → MEMS), satisfying the
  behavior-preserving guard.
- The testability analysis is accurate: extracting the algorithm into a neiry-free helper is the
  right call given `neiry_kit` cannot run under unit tests, and it mirrors the existing fake-based
  test strategy.
- Verification section is concrete and includes the right regression guard (existing classifier-port
  suite must stay green).

Address Critical Issue #1 (synchronous-throw guard) and apply the file-naming correction before
implementation.
