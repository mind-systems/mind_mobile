# Plan: T3 · connect() partial classifier-build leak

## Context
Make `NeiryClassifierSet` construction failure-atomic: if a later native classifier throws mid-build, the already-constructed earlier classifiers are disposed before rethrowing, closing the native-resource leak window that `connect()`'s `_classifierSet?.dispose()` catch can't reach.

## Settings
- Testing: yes (failure-atomic build is explicitly test-covered per the spec)
- Logging: minimal
- Docs: no

## Background (from spec `.ai-factory/notes/167-bci-connect-partial-classifier-build-leak.md`)
- `NeiryClassifierSet(neiry.Device)` (`lib/Bci/Ports/NeiryClassifierSet.dart:23-27`) builds four classifiers in an **initializer list**: `NfbClassifier` → `CardioClassifier` → `EmotionsClassifier` → `MEMSClassifier`.
- If classifier *n* throws, the constructor never returns, `_classifierSet` is never assigned, and `connect()`'s catch (`NeiryBciProvider.dart:180`) calls `_classifierSet?.dispose()` on `null` → earlier native classifiers leak.
- Guards: behavior-preserving on the happy path (same four classifiers, same order); do **not** change the `ClassifierSet` interface or the factory shape (`NeiryClassifierFactory`); the public surface `NeiryClassifierSet(neiry.Device)` must stay the same; single-resource scope, no queue/constraint changes.
- Testability note: `NeiryClassifierSet` imports `neiry_kit`, which cannot run under unit tests, and tests in this area deliberately avoid importing `neiry_kit` (see the fakes in `test/Bci/neiry_bci_provider_classifier_port_test.dart`). The atomic build/dispose algorithm is therefore extracted into a pure-Dart helper so a forced mid-construction throw can be exercised with fake builders/disposers.

## Tasks

### Phase 1: Failure-atomic construction

- [x] **Task 1: Add pure-Dart `buildAllOrDispose` helper**
  Files: `lib/Bci/Ports/BuildAllOrDispose.dart` (new — PascalCase to match every existing file in `lib/Bci/Ports/`: `DevicePort.dart`, `NeiryClassifierSet.dart`, `ClassifierFactory.dart`, …)
  Add a small, neiry-free helper that runs an ordered list of build steps and disposes already-built resources if a later step throws. Suggested shape:
  ```dart
  import 'dart:async';

  /// Runs each step in [steps] in order. A step builds a resource and returns
  /// its async disposer. If a later step throws, the disposers returned by the
  /// already-completed steps are invoked in reverse order — each guarded against
  /// BOTH a synchronous throw and an async rejection so a dispose failure cannot
  /// mask the original build error — and then the original error is rethrown. On
  /// success, returns normally and the built resources are retained by the caller
  /// (via the side effects the step closures performed).
  void buildAllOrDispose(List<Future<void> Function() Function()> steps) {
    final disposers = <Future<void> Function()>[];
    try {
      for (final step in steps) {
        disposers.add(step());
      }
    } catch (_) {
      for (final dispose in disposers.reversed) {
        try {
          // catchError guards an async rejection; the try/catch guards a
          // *synchronous* throw from the dispose() call itself (a non-`async`
          // disposer, e.g. the real native dispose, throws before catchError is
          // ever attached). Both must be swallowed here so they cannot abort the
          // reverse-dispose loop or mask the original error below.
          unawaited(dispose().catchError((Object _) {}));
        } catch (_) {/* swallow synchronous dispose throw */}
      }
      rethrow;
    }
  }
  ```
  Each step closure builds one resource (assigning it to a captured `late final` local) and returns that resource's `dispose` tear-off. Keep this file pure Dart with no `neiry_kit` or Flutter imports so it is unit-testable.

  Note (intentional silence): unlike the existing `NeiryClassifierSet.dispose()` which logs each failure via `logPrint`, these failure-path disposers swallow errors silently to keep the helper pure-Dart/testable and per the "Logging: minimal" setting. This is a deliberate trade-off, not an oversight.

- [x] **Task 2: Convert `NeiryClassifierSet` to a failure-atomic factory** (depends on Task 1)
  Files: `lib/Bci/Ports/NeiryClassifierSet.dart`
  Replace the initializer-list constructor with a `factory NeiryClassifierSet(neiry.Device device)` that builds the four classifiers via `buildAllOrDispose`, capturing each into a `late final` local, then delegates to a new private `NeiryClassifierSet._(...)` constructor that assigns the four `final` fields. Keep build order identical (`NfbClassifier` → `CardioClassifier` → `EmotionsClassifier` → `MEMSClassifier`). Example:
  ```dart
  factory NeiryClassifierSet(neiry.Device device) {
    late final neiry.NfbClassifier nfb;
    late final neiry.CardioClassifier cardio;
    late final neiry.EmotionsClassifier emotions;
    late final neiry.MEMSClassifier mems;
    buildAllOrDispose([
      () { nfb = neiry.NfbClassifier(device); return nfb.dispose; },
      () { cardio = neiry.CardioClassifier(device); return cardio.dispose; },
      () { emotions = neiry.EmotionsClassifier(device); return emotions.dispose; },
      () { mems = neiry.MEMSClassifier(device); return mems.dispose; },
    ]);
    return NeiryClassifierSet._(nfb, cardio, emotions, mems);
  }

  NeiryClassifierSet._(this._nfb, this._cardio, this._emotions, this._mems);
  ```
  Leave the four `final` fields, all stream getters, and the existing `dispose()` method unchanged. Add the `import` for the Task 1 helper (`import 'BuildAllOrDispose.dart';`). The public surface (`NeiryClassifierSet(device)`) and the `ClassifierSet` interface stay identical, so `NeiryClassifierFactory` (`lib/Bci/Ports/NeiryClassifierFactory.dart`) needs no change.

  Teardown-ordering acknowledgement (by design): because the helper is synchronous (`void`) — the factory/constructor cannot be `async` — partial-build disposers run fire-and-forget; their completion is **not** awaited at the factory boundary. In `connect()`'s catch the device is subsequently disconnected/disposed (`NeiryBciProvider.dart:184-185`) potentially before those classifier disposals finish. This is accepted: it is the same set of native disposals the happy-path `dispose()` performs, just unordered relative to device teardown, and it is strictly better than today's leak (no disposal at all).

### Phase 2: Test coverage

- [x] **Task 3: Unit-test the failure-atomic build** (depends on Task 1)
  Files: `test/Bci/build_all_or_dispose_test.dart` (new — snake_case per Dart test convention)
  Add `flutter_test` coverage for `buildAllOrDispose` (no `neiry_kit` import). Use fake builders/disposers that record disposal:
  - **Happy path:** all steps build; no disposer is invoked; helper returns normally.
  - **Mid-construction throw:** force the *k*-th step's builder to throw (e.g. k = 3 of 4); assert the first *k-1* built resources are disposed exactly once each, in reverse order, and the original error is rethrown (`expect(() => ..., throwsA(...))`). Drain the microtask queue (`await Future<void>.delayed(Duration.zero)`) before asserting if the fake records disposal inside an async body (the dispose *calls* themselves happen synchronously in reverse order during the catch, so call ordering can also be asserted without draining).
  - **Dispose-failure isolation — both disposer flavours:** exercise the guard against regression with two variants:
    - an **async-rejecting** disposer (`() async { throw StateError(...); }`), and
    - a **synchronous-throwing** disposer (`() { throw StateError(...); return Future.value(); }` — i.e. throws on the `dispose()` call before any Future is returned).
    In each case assert that the remaining earlier disposers still run and that the **original build error** (not the dispose error) is the one that propagates. The synchronous-throwing variant is the critical case: without the `try/catch` added in Task 1 it would abort the reverse-dispose loop and mask the build error.
  Mirror the style of `test/Bci/neiry_bci_provider_classifier_port_test.dart` (call-counted fakes, broadcast-free where unnecessary).

## Verification
- `flutter test test/Bci/build_all_or_dispose_test.dart` passes (including both the sync-throwing and async-rejecting disposer cases).
- `flutter test test/Bci/neiry_bci_provider_classifier_port_test.dart` still green (happy-path connect, dispose path, and A2 regression unchanged — the public `NeiryClassifierSet`/`NeiryClassifierFactory` surface is untouched).
- Full suite (`flutter test`) green.
