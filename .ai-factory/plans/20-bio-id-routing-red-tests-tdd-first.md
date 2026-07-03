# Plan: Bio id-routing red tests (TDD-first)

## Context
Lay the TDD-first RED tests that pin the root/child bio id-routing contract before its
implementation (note 17): bio samples must carry `root.id`, a child's end must NOT clear
the bio session id, a global reset (root gone) must clear it, and phase markers must stay
on the CHILD id (decoupled sources). These tests are RED against the current
current-activity-sourced id and go GREEN under note 17.

## Settings
- Testing: yes (this milestone IS the tests)
- Logging: minimal
- Docs: no

## Context notes for the implementer

- **Spec:** `.ai-factory/notes/23-rootchild-bio-idrouting-tests.md` (this milestone). The impl
  it turns green is `.ai-factory/notes/17-rootchild-bio-to-root.md` — read both.
- **Two decoupled id sources (do not conflate):**
  - Bio id lives in `BiometricStreamClient._currentSessionId` (`lib/Biometrics/BiometricStreamClient.dart`),
    today sourced from `_onLifecycleEvent` (`:86-106`), injected at wire-encode (`:215-222`),
    gated at `:111`. Under note 17 it will be sourced from the **root id**.
  - Phase/instruction id lives in `BreathModuleStateChannel._moduleSessionId`
    (`lib/BreathModule/Core/BreathModuleStateChannel.dart`), set from `channel.state` (`:47-51`),
    sent via `BreathModuleInstructionStream.sendSample(...)` (`:76`, `:141`, `:148`). This stays
    on the **child** id and note 17 must not touch it — the phase-path tests are the regression guard.
- **Why a seam (Task 1) is required:** for these tests to compile now AND go green under note 17,
  bio must be driven by a root-id stream (note 17: "subscribe bio to the root-id stream"). This
  milestone adds that injection point as an additive, unwired no-op, mirroring the registry
  red-test milestone (note 22, "lay signatures + RED tests, the impl greens it"). No behavior
  change here — `_currentSessionId` stays lifecycle-sourced, so the core tests are RED.
- **`AllSessionsReset` (note 20) is NOT needed here.** Note 17 clears bio "when the root is gone"
  — testable via the root-id stream emitting `null`. Do not introduce the note-20 event type.
- **Stateful driving, not a pass-through:** drive the real `BiometricStreamClient` and assert on
  its actual clear-condition state transitions. A pass-through double in place of the SUT's
  id-source logic would mask a "clears on child end" regression (note 23 guard, m36).
- **Existing harnesses to mirror/reuse:**
  - `test/Biometrics/biometric_stream_client_test.dart` — `_FakeStub` / `_FakeConnection` /
    `_FakeResponseStream`, `fakeAsync` + `injectReady()` pattern. Golden master — **do not edit it.**
  - `test/BreathModule/breath_module_state_channel_test.dart` — `_FakeChannel` (with
    `stateController` emitting `ModuleState`, `childOfType`), `_FakeInstructionStream`
    (`sendSampleCalls` captures `sessionId`), `_FakeStopwatch`, `_state(...)` helper.
  - `test/Core/Grpc/module_instruction_stream_test.dart` — instruction-stream fakes + error injection.

## Tasks

### Phase 1: Note-17 seam (additive, no behavior change)

- [x] **Task 1: Add optional `rootIdChanges` injection seam to `BiometricStreamClient`**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add an optional, nullable constructor parameter `Stream<String?>? rootIdChanges` (matches
  `ModuleStateChannel.rootIdChanges`, a `Stream<String?>`). When non-null, subscribe it to a
  private no-op handler (store the subscription in a `_rootIdSub` field and cancel it in
  `dispose()` alongside the other subs). Do **not** wire it into `_currentSessionId`,
  `_sessionConfirmed`, or the send path — current behavior must be byte-identical
  (`_currentSessionId` stays sourced from `_onLifecycleEvent`). Because the param is optional,
  `App.dart` and every existing test compile and pass unchanged. This is purely the injection
  point note 17 will implement against. Add a short `// note 17:` comment marking where the
  root-id routing will land.

### Phase 2: Bio id-routing RED tests

- [x] **Task 2: New bio id-routing test file with the four routing scenarios** (depends on Task 1)
  Files: `test/Biometrics/biometric_stream_id_routing_test.dart`
  Create a self-contained test file (copy the minimal `_FakeStub` / `_FakeConnection` /
  `_FakeResponseStream` fakes and the `_sample(...)` helper from
  `biometric_stream_client_test.dart` — do not modify the golden-master file). Construct the
  SUT with a `StreamController<String?>` wired to the new `rootIdChanges` param, plus the
  existing `moduleStateEvents` and `connectionState` controllers, `readyTimeout: 1h`, and drive
  everything under `fakeAsync` with `injectReady()`. Add these tests:
  - **bio sample carries `root.id`, not the child id (RED now):** emit `rootIdChanges('root-1')`,
    then `ModuleSessionStarted(moduleSessionId: 'child-A')`; `sendBatch([...])`, `injectReady()`;
    assert the wire sample's `sessionId == 'root-1'`. Current code tags it `'child-A'` → fails (RED);
    green under note 17.
  - **child end does NOT clear the bio id (RED now):** emit `rootIdChanges('root-1')`, start and
    then end the child (`ModuleSessionStarted('child-A')` → `ModuleSessionEnded()`); `sendBatch`,
    `injectReady()`; assert a batch is still sent under `'root-1'`. Current `_onLifecycleEvent`
    clears on `ModuleSessionEnded` → no batch → fails (RED); green under note 17. This is the
    stateful clear-condition guard — assert the real send, not a stubbed flag.
  - **global reset clears the bio id (RED now):** emit `rootIdChanges('root-1')` and confirm a
    batch flows under `'root-1'`, then emit `rootIdChanges(null)` (root gone); `sendBatch` again;
    assert no further batch is sent and the replay ring does not accumulate. Fails now (the first
    "send under root" step never happens with the unwired seam) → RED; green under note 17.
  - **gate holds — no bio before `rootId` is known (guard):** with no `rootIdChanges` emission and
    no lifecycle start, `sendBatch` is a no-op (`callCount == 0`). Locks the "held until root open"
    precondition. Expected green now and after note 17.
  Each test must clean up (`dispose()` + close controllers). Annotate in comments which tests are
  expected RED now vs guard-green, so the implementer confirms the RED set on first run.

### Phase 3: Phase-path decoupling guards (green regression locks)

- [x] **Task 3: Phase/instruction sample carries the CHILD id, not the root id**
  Files: `test/BreathModule/breath_module_state_channel_test.dart`
  Add a `group` reusing the existing `_FakeChannel` / `_FakeInstructionStream` / `_FakeStopwatch`
  and `_state(...)` helper. Emit a `ModuleState` on `channel.stateController` with
  `moduleSessionId: 'child-breath'`, drive a running state and a phase change so a marker is
  emitted, and assert the captured `_FakeInstructionStream.sendSampleCalls` entry carries
  `sessionId == 'child-breath'` — and explicitly assert it is NOT a root id (e.g. use a distinct
  `'root-1'` sentinel in the test and assert inequality). This locks that bio's retarget to
  `root.id` (note 17) never reroutes phase markers onto the root. Expected green now and after note 17.

- [x] **Task 4: Late `SESSION_NOT_FOUND` phase sample is swallowed (no throw)**
  Files: `test/Core/Grpc/module_instruction_stream_test.dart`
  Add a test that drives `ModuleInstructionStream` to an open+ready stream, then injects a
  `StreamResponse` error event with code `SESSION_NOT_FOUND` (the benign late-phase race after a
  child ended). Assert no exception propagates, the test completes normally, and the stream is not
  torn down (subsequent `emit` still works / no reconnect scheduled beyond current behavior). This
  characterizes the "drop late phase silently" guarantee note 17 relies on. Expected green now and
  after note 17.
