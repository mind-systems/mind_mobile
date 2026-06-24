# ModuleStateChannel — Test Plan

**Date:** 2026-06-24  
**Source:** roadmap-test-coverage agent

## Source Overview

`ModuleStateChannel` (lib/Core/Grpc/ModuleStateChannel.dart) is the gRPC event sink for real-time module state (breathing, meditation). It manages a bidirectional stream (trackActivity) with the server, translates proto events into typed domain events, and orchestrates session lifecycle via state machine guards.

**Key behaviors added post-June 17:**
- note 152: `_openSessionStream` attaches CallOptions metadata `{'module-session-id': liveId}` when currentState holds an active live session
- note 153: `_processProtoEvent` RESUMED branch emits `ModuleSessionResumed({moduleSessionId})`
- note 154: ABANDONED branch → `ModuleSessionAbandoned` + reset; `sessionError 'no_active_session'` demoted to silent defensive reset (line 94-96)
- note 137: `start()` and `end()` accept optional `clientTimestampMs` and forward it in proto messages (Int64 conversion)

## Instantiation

```dart
ModuleStateChannel({
  required proto.ModuleStateServiceClient moduleStateService,
  required GrpcConnectionManager connectionManager,
  required Stream<AuthState> authStream,
})
```

Three required dependencies:
1. **moduleStateService**: gRPC client stub — calls `trackActivity(request, options:)` and returns `ResponseStream<StateResponse>`
2. **connectionManager**: emits `GrpcConnectionState` (connecting/connected/disconnected) and exposes `confirmConnected()` / `disconnect()` / `scheduleReconnect()`
3. **authStream**: `Stream<AuthState>` — triggers `_reset()` on `GuestState`

## Existing Coverage

Two test files use a `_FakeChannel` that **implements the interface** but never exercises the real class:
- `test/BreathModule/breath_module_state_channel_test.dart`
- `test/MeditationModule/meditation_module_state_channel_test.dart`

Both tests wrap `ModuleStateChannel` in a module-specific state channel (e.g., `BreathModuleStateChannel`) that adapts module lifecycle → channel commands. The tests verify the adapter's logic (start, pause, unpause, end, stop) but never test:
- Proto-event deserialization and routing
- Metadata attachment to CallOptions
- Client-timestamp forwarding
- State transitions from proto.StateEvent
- Event emission order and content
- Error handling (session stream errors, sessionError responses)
- Connection lifecycle

## Test Cases

### Group 1: Proto-Event Processing — RESUMED

**Branch:** Line 127–133 in `_processProtoEvent`

#### should emit ModuleSessionResumed with the moduleSessionId when proto.ActivityStatus.RESUMED arrives

- **Setup:** Create StateResponse with sessionState.status=RESUMED, moduleSessionId='test-sid'
- **Trigger:** Emit via fake response stream
- **Assert:** Events stream receives exactly one ModuleSessionResumed(moduleSessionId: 'test-sid')
- **State check:** currentState.status == ModuleStateStatus.active, currentState.moduleSessionId == 'test-sid'

#### should clear isPendingStart and isPendingPause flags on RESUMED

- **Setup:** Set _isPendingStart=true and _isPendingPause=true (via prior command attempt or internal flag)
- **Trigger:** Emit RESUMED event
- **Assert:** Subsequent state transitions are processed (no guard blocks them); _isPendingStart and _isPendingPause are false (verified indirectly by observing normal lifecycle behavior)

#### should handle RESUMED with isPaused=true

- **Setup:** Emit RESUMED with isPaused=true
- **Trigger:** Receive event
- **Assert:** currentState.isPaused == true; ModuleSessionResumed emitted with correct moduleSessionId

#### should handle RESUMED with isPaused=false

- **Setup:** Emit RESUMED with isPaused=false
- **Trigger:** Receive event
- **Assert:** currentState.isPaused == false; ModuleSessionResumed emitted

### Group 2: Proto-Event Processing — ABANDONED

**Branch:** Line 152–154 in `_processProtoEvent`

#### should emit ModuleSessionAbandoned and reset state when proto.ActivityStatus.ABANDONED arrives

- **Setup:** Initialize with active session (moduleSessionId='active-id')
- **Trigger:** Emit ABANDONED event
- **Assert:** Events stream receives ModuleSessionAbandoned; currentState == ModuleState.initial()

#### should reset moduleSessionId to null on ABANDONED

- **Setup:** currentState holds moduleSessionId='live-id'
- **Trigger:** Emit ABANDONED
- **Assert:** currentState.moduleSessionId == null; subsequent state reads return null

### Group 3: Session Error — no_active_session Demotion

**Branch:** Line 92–96 in `_openSessionStream`

#### should silently reset to ModuleState.initial() when sessionError with code='no_active_session' arrives (no log, no event emission)

- **Setup:** Establish connected session stream
- **Trigger:** Emit StateResponse with sessionError.code='no_active_session', sessionError.message='<any>'
- **Assert:** currentState == ModuleState.initial(); no event emitted; only log line "[ModuleStateChannel] session error: no_active_session — ..." is produced (silent defensive reset, per note 154)

#### should not emit any ModuleStateEvent when no_active_session error is received

- **Setup:** Stream listener collecting events
- **Trigger:** Receive no_active_session error
- **Assert:** Events stream receives no messages (only internal state.add() occurs)

### Group 4: Metadata Attachment — module-session-id Header

**Branch:** Line 76–79 in `_openSessionStream`

#### should attach module-session-id metadata when opening stream with active status and non-empty moduleSessionId

- **Setup:** currentState = ModuleState(moduleSessionId: 'live-123', status: active)
- **Trigger:** Emit connection-state=connected (calls _openSessionStream)
- **Assert:** moduleStateService.trackActivity was called with CallOptions(metadata: {'module-session-id': 'live-123'})

#### should not attach module-session-id metadata when status != active

- **Setup:** currentState = ModuleState(moduleSessionId: 'live-123', status: idle)
- **Trigger:** Emit connection-state=connected
- **Assert:** moduleStateService.trackActivity was called with options=null (or no metadata)

#### should not attach module-session-id metadata when moduleSessionId is null

- **Setup:** currentState = ModuleState(moduleSessionId: null, status: active)
- **Trigger:** Emit connection-state=connected
- **Assert:** moduleStateService.trackActivity was called with options=null

#### should not attach module-session-id metadata when moduleSessionId is empty string

- **Setup:** currentState = ModuleState(moduleSessionId: '', status: active)
- **Trigger:** Emit connection-state=connected
- **Assert:** moduleStateService.trackActivity was called with options=null

#### should attach module-session-id metadata only on first _openSessionStream call after connection (connection-state=connecting → connected)

- **Setup:** Initial state is idle; moduleState stream emits active+moduleSessionId='s1'
- **Trigger:** connectionState.add(connected)
- **Assert:** trackActivity called once with metadata; subsequent calls to _openSessionStream (e.g., on reconnect) re-attach the current moduleSessionId

### Group 5: Client Timestamp Forwarding

**Branch:** Line 165–174 (start), Line 189–196 (end)

#### should forward clientTimestampMs from start() to proto.ActivityStartCmd

- **Setup:** Create channel, wire connection/auth streams
- **Trigger:** Call channel.start(type: breath, refId: 'sess-1', clientTimestampMs: 1234567890)
- **Assert:** Captured StateRequest contains activityStart.clientTimestampMs == Int64(1234567890)

#### should send Int64.ZERO if clientTimestampMs=0 is passed to start()

- **Setup:** Call start with clientTimestampMs: 0
- **Trigger:** Capture StateRequest
- **Assert:** activityStart.clientTimestampMs == Int64(0) (not null; zero is a valid timestamp)

#### should not set clientTimestampMs field if start() is called without clientTimestampMs argument

- **Setup:** Call start(type: breath, refId: 'sess-1') — no clientTimestampMs
- **Trigger:** Capture StateRequest
- **Assert:** activityStart.clientTimestampMs is unset/default (or proto field is null/zero depending on protobuf encoding)

#### should forward clientTimestampMs from end() to proto.ActivityEndCmd

- **Setup:** Start a session first, then call end(clientTimestampMs: 9876543210)
- **Trigger:** Capture StateRequest
- **Assert:** activityEnd.clientTimestampMs == Int64(9876543210)

#### should not set clientTimestampMs in ActivityEndCmd if end() is called without clientTimestampMs

- **Setup:** Call end() with no clientTimestampMs
- **Trigger:** Capture StateRequest
- **Assert:** activityEnd.clientTimestampMs is unset

### Group 6: State Transitions — ACTIVE / COMPLETED / INTERRUPTED / ACTIVITY_STATUS_UNSPECIFIED

**Branch:** Line 134–160 (covers all other proto.ActivityStatus values)

#### should handle ACTIVE as before (emit ModuleSessionStarted on first active, ModuleSessionPaused on pause, ModuleSessionUnpaused on resume)

- **Setup:** Emit ACTIVE with status transitions (idle→active, active+paused→active+!paused)
- **Trigger:** Receive events
- **Assert:** Verify ModuleSessionStarted, ModuleSessionPaused, ModuleSessionUnpaused are emitted appropriately

#### should emit ModuleSessionEnded when COMPLETED arrives

- **Setup:** Initialize with active session
- **Trigger:** Emit COMPLETED
- **Assert:** Events stream receives ModuleSessionEnded; state reset to initial

#### should emit ModuleSessionEnded when INTERRUPTED arrives

- **Setup:** Initialize with active session
- **Trigger:** Emit INTERRUPTED
- **Assert:** Events stream receives ModuleSessionEnded; state reset to initial

#### should reset to initial state when ACTIVITY_STATUS_UNSPECIFIED arrives

- **Setup:** Initialize with active session
- **Trigger:** Emit ACTIVITY_STATUS_UNSPECIFIED
- **Assert:** currentState == ModuleState.initial(); _isPendingStart=false, _isPendingPause=false

#### should log unhandled status when an unknown ActivityStatus is received

- **Setup:** Mock logPrint or capture logs
- **Trigger:** Emit StateResponse with unknown/future status value
- **Assert:** Log contains "[ModuleStateChannel] unhandled status: ..."

### Group 7: Stream Lifecycle — Connection State Transitions

**Branch:** Line 55–64 (constructor), Line 72–114 (_openSessionStream)

#### should open session stream when connectionState=connected

- **Setup:** Construct channel with mocked connectionManager
- **Trigger:** connectionManager.connectionState.add(connected)
- **Assert:** moduleStateService.trackActivity was called; _sessionSub is not null; _sessionSink is not null

#### should close session stream when connectionState=disconnected

- **Setup:** Initialize in connected state
- **Trigger:** connectionManager.connectionState.add(disconnected)
- **Assert:** _sessionSub is cancelled; _sessionSink is closed; isConnected == false

#### should do nothing on connectionState=connecting

- **Setup:** Construct channel
- **Trigger:** connectionManager.connectionState.add(connecting)
- **Assert:** No stream operations; _sessionSub and _sessionSink remain null (or unchanged)

#### should confirm connection on first successful proto event after backoff (confirmConnected called once)

- **Setup:** Initialize with connected state
- **Trigger:** Emit first StateResponse via trackActivity
- **Assert:** connectionManager.confirmConnected() called exactly once; _backoffConfirmed toggled to true

#### should not call confirmConnected again on subsequent events

- **Setup:** Emit first event (confirmConnected called), then emit second event
- **Trigger:** Receive events
- **Assert:** confirmConnected called only once (guard at line 83-85)

#### should disconnect and schedule reconnect on session stream error

- **Setup:** Initialize in connected state
- **Trigger:** trackActivity stream.listen onError callback fires with exception
- **Assert:** connectionManager.disconnect() called; connectionManager.scheduleReconnect() called; _sessionSub cancelled; log "[ModuleStateChannel] session stream error: ..."

#### should disconnect and schedule reconnect on session stream done

- **Setup:** Initialize in connected state
- **Trigger:** trackActivity stream.listen onDone callback fires
- **Assert:** connectionManager.disconnect() called; connectionManager.scheduleReconnect() called; _sessionSub cancelled; log "[ModuleStateChannel] session stream done"

#### should filter DISCONNECTED status silently (return without processing)

- **Setup:** Emit StateResponse with sessionState.status=DISCONNECTED
- **Trigger:** Receive event
- **Assert:** _processProtoEvent returns early (line 90); no state change; no event emission

### Group 8: Auth State Transitions

**Branch:** Line 65–67 (constructor)

#### should reset state when authStream emits GuestState

- **Setup:** Initialize in active state with moduleSessionId='test'
- **Trigger:** authStream.add(GuestState(...))
- **Assert:** currentState == ModuleState.initial(); _isPendingStart=false, _isPendingPause=false

#### should not reset state when authStream emits AuthenticatedState

- **Setup:** Initialize in active state
- **Trigger:** authStream.add(AuthenticatedState(...))
- **Assert:** currentState unchanged

#### should react to guest logout even if session stream is disconnected

- **Setup:** Initialize, then trigger connectionState=disconnected
- **Trigger:** authStream.add(GuestState(...))
- **Assert:** currentState reset to initial; no stream errors logged

### Group 9: Request Sending — _sendSessionRequest Guard

**Branch:** Line 205–211

#### should drop request if _sessionSink is null (not connected)

- **Setup:** Construct channel but keep connectionState=disconnected (_sessionSink=null)
- **Trigger:** Call start(), pause(), unpause(), end(), stop()
- **Assert:** Log "[ModuleStateChannel] not connected, dropping request"; _sessionSink.add never called

#### should send request if _sessionSink is not null

- **Setup:** Initialize in connected state
- **Trigger:** Call start(type: breath, refId: 'sess-1')
- **Assert:** _sessionSink.add(StateRequest) called exactly once; no log

### Group 10: Disposal and Cleanup

**Branch:** Line 230–236 (dispose)

#### should cancel connectionState subscription on dispose

- **Setup:** Construct and dispose
- **Trigger:** Call connectionManager.connectionState.add(disconnected) after dispose
- **Assert:** No stream operations occur; _closeSessionStream not called again

#### should cancel authState subscription on dispose

- **Setup:** Construct and dispose
- **Trigger:** authStream.add(GuestState(...)) after dispose
- **Assert:** _reset() not called; state unchanged

#### should close session stream on dispose

- **Setup:** Initialize in connected state
- **Trigger:** Call dispose()
- **Assert:** _sessionSub cancelled; _sessionSink closed; isConnected == false

#### should close state and events BehaviorSubject/PublishSubject on dispose

- **Setup:** Construct channel
- **Trigger:** Call dispose()
- **Assert:** Listeners on state and events receive done event (stream closed); no further events can be emitted

## Gotchas

1. **Int64 conversion:** clientTimestampMs is wrapped in `Int64(...)` in proto messages. Fake stream responses must also use Int64 for comparison.

2. **CallOptions metadata:** gRPC metadata is a Map<String, String>. The fake moduleStateService must capture the options parameter and expose it for assertion (e.g., via a recorded call log).

3. **Proto enum values:** ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED is sentinel 0; RESUMED is 6. Both must be imported and used correctly in tests.

4. **Backoff guard:** The `_backoffConfirmed` flag is set to false on _openSessionStream and toggled true on first response. Tests opening a new stream must emit at least one event to verify confirmConnected was called.

5. **DISCONNECTED filtering:** Line 90 returns early and **never calls _processProtoEvent**; this is a silent filter. Tests must verify no event emission, not just check for a no-op in _processProtoEvent.

6. **no_active_session demotion:** This error code resets state silently without emitting a ModuleStateEvent. Distinguish from other sessionError codes that should log and potentially trigger reconnect (not currently handled, but document as a gotcha).

7. **Metadata attachment decision:** The guard at line 76–77 checks both `status == active` AND `liveId != null && liveId.isNotEmpty`. All three conditions must align for metadata to attach. Empty string is treated like null.

8. **Pending guards:** `_isPendingStart` and `_isPendingPause` prevent duplicate requests. Tests confirming these are cleared must observe that a *different* command works (e.g., after RESUMED clears _isPendingStart, a subsequent pause should be allowed even if it was previously guarded).

9. **Subscription lifetime:** The _connectionSub and _authSub are late-initialized in the constructor and must remain alive across connection cycles. Tests resetting state must verify subscriptions survive (e.g., by emitting another event post-reset).

10. **StateResponse.whichEvent():** This oneof discriminator determines which event type is populated. Must use the proto API correctly to create test responses with only one event set (sessionState, sessionError, or notSet).
