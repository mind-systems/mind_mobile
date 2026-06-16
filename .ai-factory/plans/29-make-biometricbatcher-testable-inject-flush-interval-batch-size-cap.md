# Plan: Make `BiometricBatcher` testable: inject flush interval + batch-size cap

## Context
Expose the hard-coded flush interval (250 ms) and max batch size (25) as optional constructor parameters so flush-on-size and flush-on-deadline behaviour can be tested without real timing or large sample counts. No behavior change — defaults preserve current values.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Parameterize batcher constants

- [x] **Task 1: Convert `_maxBatchSize` and `_flushInterval` into injectable instance fields**
  Files: `lib/Biometrics/BiometricBatcher.dart`
  Remove the two `static const` declarations (`_maxBatchSize = 25`, `_flushInterval = Duration(milliseconds: 250)`) and replace them with `final` instance fields. Add two optional named constructor parameters with the current values as defaults:
  ```dart
  BiometricBatcher({
    required BioStreamRouter router,
    required BiometricStreamClient client,
    Duration flushInterval = const Duration(milliseconds: 250),
    int maxBatchSize = 25,
  })  : _router = router,
        _client = client,
        _flushInterval = flushInterval,
        _maxBatchSize = maxBatchSize {
    _sub = _router.samples.listen(_onSample);
  }
  ```
  Declare the fields as `final int _maxBatchSize;` and `final Duration _flushInterval;`. The existing references inside `_onSample` (`_buffer.length >= _maxBatchSize`) and the timer creation (`Timer(_flushInterval, _flushNow)`) already use these names and require no further change. Keep field/parameter ordering and the existing initializer-list style consistent with the current file. Do not modify any flush logic, dispose logic, or the doc comment's stated defaults.

- [x] **Task 2: Confirm production call site needs no change** (depends on Task 1)
  Files: `lib/Core/App.dart`
  The only production construction is at `lib/Core/App.dart:210`: `BiometricBatcher(router: bioStreamRouter, client: biometricStreamClient)`. Since both new parameters have defaults matching the previous constants, this call site stays correct and must remain unchanged. Verify it still compiles with no override arguments and leave it as-is (no edit expected).
