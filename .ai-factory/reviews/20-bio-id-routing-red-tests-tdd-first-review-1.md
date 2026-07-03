# Code Review — Bio id-routing red tests (TDD-first)

Reviewed `git diff HEAD` in full. Production change: 1 file (`BiometricStreamClient.dart`).
Test changes: 1 new file + 2 modified. Artifact files (plan `.md`/`.json`, plan-review) are
non-code and not reviewed.

## Scope & verification performed

- **Seam (`lib/Biometrics/BiometricStreamClient.dart`):** additive optional named param
  `Stream<String?>? rootIdChanges`, subscribed via a null-safe `rootIdChanges?.listen(_onRootIdChanged)`
  into a `_rootIdSub` field that is cancelled in `dispose()`. `_onRootIdChanged` is an intentional
  no-op. `_currentSessionId`/`_sessionConfirmed`/send path are untouched → current behavior is
  byte-identical. Because the param is optional and nullable, `App.dart` and all existing tests
  compile and pass unchanged. No analyzer concerns (unused method *parameter* is not linted; the
  field and method are both used). ✔ Correct and safe.
- **Proto types:** confirmed `StreamResponse.error` is typed `StateErrorEvent` (imported from
  `module_state.proto` as `$2`, reused per the generated comment). The test's
  `StreamResponse(error: StateErrorEvent(code:…, message:…))` and the added
  `import … module_state.pb.dart show StateErrorEvent` compile; `StateErrorEvent` has `code`/`message`
  string fields. No name ambiguity (generated `.pb`/`.pbgrpc` do not re-export their imports). ✔
- **Instruction-stream test helpers** (`_make`, `_connect`, `_makeReady`, `latestCall!.responseCtrl`,
  `sentSamples`, `disconnectCount`, `scheduleReconnectCount`, `mis`) all exist with matching shapes. ✔
- **Breath-channel test fixture** (`_Fixture` with `channel`/`instructionStream`/`stateCtrl`/`target`,
  `_make`, `_state`, `ModuleState(moduleSessionId, status)`, `ModuleStateStatus.active`) all exist; the
  `await Future<void>.delayed(Duration.zero)` flush matches the file's established pattern. ✔

## Correctness of the RED/GREEN intent

Traced each test against current code and against a correct note-17 impl:

- **`biometric_stream_id_routing_test.dart`**
  - *tag with root.id* — now sends `child-A` (asserts `root-1`) → RED; under note 17 id is root-sourced → GREEN. ✔
  - *no clear on child end* — now `ModuleSessionEnded` nulls the id → no send → RED; under note 17 not cleared → GREEN. ✔ Correctly drives the real SUT clear-condition (satisfies the note-23 “stateful, not pass-through” guard; a buggy note-17 that still clears on child end stays RED).
  - *global reset (rootIdChanges null)* — RED now (precondition send never happens), GREEN under note 17. ✔
  - *gate holds* — GREEN now and after note 17. ✔
- **`breath_module_state_channel_test.dart`** phase-decoupling guard — emits marker with `child-breath`, asserts `== child-breath` and `!= root-1`; GREEN now, unaffected by note 17 (bio retarget doesn’t touch `_moduleSessionId`). ✔
- **`module_instruction_stream_test.dart`** late `SESSION_NOT_FOUND` — an `error` *onData* frame hits the log-only branch (no `disconnect`/`scheduleReconnect`); subsequent `emit` still reaches the wire. GREEN now and after note 17. ✔

Production code has **no defects**. The findings below are non-blocking test-quality notes.

## Findings (non-blocking, advisory)

### 1. [LOW] Tests #2/#3 reach their RED state via a `StreamController`-empty crash, not a clean expectation
In `biometric_stream_id_routing_test.dart`, when the send path is (correctly) a no-op now, no
connection is opened, so `stub.latest` (`connections.last`) throws `StateError: No element` at the
`injectReady()` line *before* the meaningful `expect(...)` runs. The test is still RED (intended) and
still catches the exact “clears on child end” regression, but the failure surfaces as a bad-state
crash rather than “expected root-1, got no batch”, which weakens the diagnostic when someone runs the
suite in its red phase.
Optional hardening: guard on `stub.callCount`/`stub.connections.isNotEmpty` before `injectReady()`,
or assert the batch-absence directly, so the red failure reads as an intent mismatch.

### 2. [LOW] The “replay ring emptied” clause of note 23 is asserted only indirectly in test #3
Note 23 requires that global reset both clears `_currentSessionId` **and** empties the replay ring.
Test #3’s only post-reset assertion is `stub.callCount == callCountBeforeReset` (no new stream). It
never buffers a sample into the ring and then verifies the ring is drained/empty after reset, so a
future impl that clears the id but leaks the ring would pass. The dropped `sample(2)` cannot reach the
ring today (the gate returns before `_encodeAndAdd`), so this is a coverage gap versus the spec, not a
current failure. Consider buffering while not-ready, resetting, then reconnecting and asserting nothing
drains — if fuller coverage of that clause is wanted in this milestone.

## Note (not a finding)
This milestone intentionally commits failing (RED) tests per the TDD-first roadmap design; `flutter test`
will be red on this branch until note 17 lands. That is the stated deliverable, not a regression.
