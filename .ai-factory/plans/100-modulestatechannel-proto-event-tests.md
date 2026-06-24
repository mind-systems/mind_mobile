# Test Plan: ModuleStateChannel proto-event tests

## Context
`lib/Core/Grpc/ModuleStateChannel.dart` is the bidirectional gRPC sink that translates
server `StateResponse` frames into typed `ModuleStateEvent`s and drives the session
state machine. The existing Breath/Meditation channel tests only exercise a `_FakeChannel`
adapter — the real class (proto deserialization, metadata attachment, timestamp forwarding,
error demotion, lifecycle) has zero coverage. This plan covers the real class directly with
a fake gRPC stub.

## Settings
- Testing: yes
- Logging: minimal
- Docs: no

## Test Command
`/usr/local/bin/flutter test test/Core/Grpc/module_state_channel_test.dart`

## Target Spec File
`test/Core/Grpc/module_state_channel_test.dart`

## Source-of-truth notes
- Implementation: `lib/Core/Grpc/ModuleStateChannel.dart`
- Detailed test spec: `.ai-factory/notes/178-test-plan-module-state-channel.md`
- Models: `lib/Core/Grpc/ModuleState.dart`, `lib/Core/Grpc/ModuleStateEvent.dart`, `lib/Core/Grpc/ActivityType.dart`
- Proto: `lib/Core/Grpc/generated/module_state.pb.dart` (+ `.pbenum.dart`, `.pbgrpc.dart`)

---

## Fake Infrastructure (set up inside the spec file — no shared infra refactor)

The implementer must build three local fakes at the top of the spec file. These are the
load-bearing details; get them right and every task below is mechanical.

### 1. Controllable `ResponseStream` from a fake `ClientCall`
`proto.ModuleStateServiceClient.trackActivity(...)` returns
`grpc.ResponseStream<proto.StateResponse>` (`module_state.pbgrpc.dart:35`).
`ResponseStream` (grpc-5.1.0 `common.dart:78`) is a `StreamView<R>` whose constructor takes a
`ClientCall<dynamic, R>` and forwards `_call.response` to the view. The channel only ever calls
`.listen(onData, onError:, onDone:)` on it (`ModuleStateChannel.dart:81`), so a fake
`ClientCall` exposing just a `response` getter is sufficient:

```dart
class _FakeClientCall implements grpc.ClientCall<proto.StateRequest, proto.StateResponse> {
  final Stream<proto.StateResponse> _responses;
  _FakeClientCall(this._responses);
  @override
  Stream<proto.StateResponse> get response => _responses;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

Wrap a `StreamController<proto.StateResponse>` so the test can `add(...)` frames, `addError(...)`
to drive `onError`, and `close()` to drive `onDone`. Return
`grpc.ResponseStream<proto.StateResponse>(_FakeClientCall(controller.stream))` from the fake stub.

### 2. Fake `proto.ModuleStateServiceClient`
`implements proto.ModuleStateServiceClient` with `noSuchMethod`, overriding only `trackActivity`.
It must record, per call:
- the `options` argument (a `grpc.CallOptions?`) so metadata can be asserted —
  read back via `options?.metadata['module-session-id']`
- the inbound `request` stream (the channel passes `_sessionSink!.stream`) — subscribe to it and
  append every received `proto.StateRequest` to a public `sentRequests` list so `start()`/`end()`
  payloads can be asserted
- expose the response `StreamController` (or a per-call handle) so the test can emit frames

Because the channel opens a fresh stream on every `connected` transition
(`ModuleStateChannel.dart:72-80`), the fake should keep a list of calls (each with its own
options + response controller) and expose the latest.

### 3. Plain stream-controller fakes for the two stream dependencies
- `GrpcConnectionManager` — the channel only consumes `.connectionState` (a
  `Stream<GrpcConnectionState>`) and calls `.confirmConnected()`, `.disconnect()`,
  `.scheduleReconnect()`. Fake it with `implements` + `noSuchMethod`, backing `connectionState`
  with a broadcast `StreamController<GrpcConnectionState>` and counting the three method calls.
  (Do NOT construct a real `GrpcConnectionManager` — keep the SUT isolated.)
- `authStream` — a plain `StreamController<AuthState>.broadcast()`; emit
  `AuthenticatedState(user)` / `GuestState(user)` (`lib/User/Models/AuthState.dart`). Build users
  the same way `grpc_connection_manager_backoff_test.dart` does.

### Test conventions (match existing tests)
- Use `flutter_test`, `group`/`test`, `expect`.
- Drive async stream propagation with `await Future<void>.delayed(Duration.zero);` after every emission
  (pattern used throughout `meditation_module_state_channel_test.dart`).
- A helper `_make()` returning a record fixture `(channel, service, connManager, authCtrl)` mirrors
  the existing `_make()`/`_Fixture` style; always `dispose()` the channel at test end.
- Helper to open a live stream: emit `GrpcConnectionState.connected` on the conn-manager fake, then
  pump a microtask, so `_openSessionStream` runs and `_sessionSink` becomes non-null before sending commands.
- Collect emitted events with `channel.events.listen(received.add)` (PublishSubject — subscribe before triggering).
- Proto enums: import `module_state.pbgrpc.dart as proto`; use `proto.ActivityStatus.RESUMED`, etc.
- `Int64` comes from `package:fixnum/fixnum.dart`.

---

## Tasks

### Phase 1: Proto-event processing — RESUMED (note Group 1; src 127-133)

- [x] **Task 1: `_processProtoEvent` — RESUMED branch**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should emit ModuleSessionResumed with the moduleSessionId when a RESUMED frame arrives`
  - `should set currentState to active with the frame's moduleSessionId on RESUMED`
  - `should set currentState.isPaused to true when RESUMED frame has isPaused=true`
  - `should set currentState.isPaused to false when RESUMED frame has isPaused=false`
  - `should not fold RESUMED into ModuleSessionStarted (emits Resumed, not Started)`
  - `should clear pending-start and pending-pause guards on RESUMED so a subsequent pause is allowed`

### Phase 2: Proto-event processing — ABANDONED (note Group 2; src 152-154)

- [x] **Task 2: `_processProtoEvent` — ABANDONED branch**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should emit ModuleSessionAbandoned when an ABANDONED frame arrives`
  - `should reset currentState to ModuleState.initial (idle, null id) on ABANDONED`

### Phase 3: Session error — no_active_session demotion (note Group 3; src 92-96)

- [x] **Task 3: sessionError handling**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should silently reset currentState to initial when sessionError code is 'no_active_session'`
  - `should not emit any ModuleStateEvent when 'no_active_session' error is received`
  - `should not reset state when a sessionError with a different code arrives` (only `no_active_session` triggers the reset at src:94-95)

### Phase 4: module-session-id metadata attachment (note Group 4; src 75-80)

- [x] **Task 4: CallOptions metadata guard**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should attach module-session-id metadata when currentState is active with a non-empty id`
  - `should pass null options when currentState.status is not active`
  - `should pass null options when moduleSessionId is null`
  - `should pass null options when moduleSessionId is an empty string`
  - `should recompute metadata from currentState on each reconnect (stream re-open)`

### Phase 5: client timestamp forwarding (note Group 5; src 165-174, 189-196)

- [x] **Task 5: start() / end() clientTimestampMs forwarding**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should forward clientTimestampMs as Int64 in ActivityStartCmd when start() is given a timestamp`
  - `should send Int64(0) in ActivityStartCmd when start() is given clientTimestampMs=0` (0 is non-null, so it is forwarded)
  - `should leave ActivityStartCmd.clientTimestampMs unset when start() is called without a timestamp`
  - `should forward clientTimestampMs as Int64 in ActivityEndCmd when end() is given a timestamp`
  - `should leave ActivityEndCmd.clientTimestampMs unset when end() is called without a timestamp`
  - `should not call DateTime.now() internally — timestamp originates only from the caller` (assert the field is unset when the arg is omitted; no server-side default appears)

### Phase 6: other state transitions (note Group 6; src 134-160)

- [x] **Task 6: ACTIVE / COMPLETED / INTERRUPTED / UNSPECIFIED / unknown**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should emit ModuleSessionStarted on the first ACTIVE frame from idle`
  - `should emit ModuleSessionPaused when an ACTIVE frame transitions isPaused false to true`
  - `should emit ModuleSessionUnpaused when an ACTIVE frame transitions isPaused true to false`
  - `should not emit a lifecycle event when an ACTIVE frame repeats the same paused state`
  - `should emit ModuleSessionEnded and reset to initial when a COMPLETED frame arrives`
  - `should emit ModuleSessionEnded and reset to initial when an INTERRUPTED frame arrives`
  - `should reset to initial and clear pending-start on an ACTIVITY_STATUS_UNSPECIFIED frame`
  - `should ignore a DISCONNECTED frame (no state change, no event emitted)`

### Phase 7: stream lifecycle & backoff confirmation (note Group 7; src 55-114)

- [x] **Task 7: connection-state driven stream open/close**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should open the trackActivity stream and report isConnected=true when connectionState becomes connected`
  - `should close the stream and report isConnected=false when connectionState becomes disconnected`
  - `should do nothing on connectionState=connecting`

- [x] **Task 8: backoff confirmation & transport failures**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should call confirmConnected exactly once on the first received frame after opening a stream`
  - `should not call confirmConnected again on subsequent frames`
  - `should close stream, disconnect, and scheduleReconnect when the response stream errors`
  - `should close stream, disconnect, and scheduleReconnect when the response stream is done`

### Phase 8: auth reset & request-send guard (note Groups 8 & 9; src 65-67, 205-211)

- [x] **Task 9: auth-driven reset**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should reset currentState to initial when authStream emits GuestState`
  - `should not reset currentState when authStream emits AuthenticatedState`
  - `should reset on GuestState even while the session stream is disconnected`

- [x] **Task 10: `_sendSessionRequest` connectivity guard**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should drop the request and not throw when start() is called while sink is null (not connected)`
  - `should deliver exactly one StateRequest to the stub when start() is called while connected`

### Phase 9: disposal (note Group 10; src 230-236)

- [x] **Task 11: dispose teardown**
  Files: `test/Core/Grpc/module_state_channel_test.dart`
  Test cases:
  - `should stop reacting to connectionState emissions after dispose`
  - `should stop reacting to authStream emissions after dispose`
  - `should close the session stream and report isConnected=false after dispose`
  - `should close the state and events streams on dispose`
