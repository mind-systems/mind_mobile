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
})  : _moduleStateService = moduleStateService,
      _connectionManager = connectionManager
```

Three required dependencies (ModuleStateChannel.dart:49–53):
1. **moduleStateService**: `proto.ModuleStateServiceClient` — calls `trackActivity(stream, options:)` at line 80, returns `ResponseStream<proto.StateResponse>`
2. **connectionManager**: `GrpcConnectionManager` — emits `Stream<GrpcConnectionState>` via `.connectionState` (line 55); exposes `.confirmConnected()` (line 85, GrpcConnectionManager.dart:104), `.disconnect()` (line 104, GrpcConnectionManager.dart:93), `.scheduleReconnect()` (line 105, GrpcConnectionManager.dart:111)
3. **authStream**: `Stream<AuthState>` — triggers `_reset()` on `GuestState` (line 66)

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
- **Assert:** Events stream receives exactly one ModuleSessionResumed(moduleSessionId: 'test-sid') (ModuleSessionResumed declared ModuleStateEvent.dart:8–10)
- **State check:** currentState.status == ModuleStateStatus.active, currentState.moduleSessionId == 'test-sid' (ModuleState.dart:1–11; ModuleStateStatus enum at line 1; ModuleState.active constructor at line 8; state updated at ModuleStateChannel.dart:132)

#### should clear isPendingStart and isPendingPause flags on RESUMED

- **Setup:** Set _isPendingStart=true and _isPendingPause=true (private fields at ModuleStateChannel.dart:31–32)
- **Trigger:** Emit RESUMED event (ActivityStatus.RESUMED defined as proto enum value 6 in module_state.pbenum.dart:59–60)
- **Assert:** Both flags reset to false (lines 130–131 in _processProtoEvent RESUMED branch); subsequent state transitions are processed without guard blocks

#### should handle RESUMED with isPaused=true

- **Setup:** Emit StateResponse with sessionState.status=RESUMED, sessionState.isPaused=true, sessionState.moduleSessionId='test-id'
- **Trigger:** Receive event via trackActivity stream
- **Assert:** currentState.isPaused == true (ModuleState.dart:6, default isPaused=false at line 8); ModuleSessionResumed(moduleSessionId: 'test-id') emitted (ModuleStateChannel.dart:133)

#### should handle RESUMED with isPaused=false

- **Setup:** Emit StateResponse with sessionState.status=RESUMED, sessionState.isPaused=false
- **Trigger:** Receive event via trackActivity stream
- **Assert:** currentState.isPaused == false (line 132 sets isPaused: isPaused); ModuleSessionResumed emitted at line 133

### Group 2: Proto-Event Processing — ABANDONED

**Branch:** Line 152–154 in `_processProtoEvent`

#### should emit ModuleSessionAbandoned and reset state when proto.ActivityStatus.ABANDONED arrives

- **Setup:** Initialize with active session (moduleSessionId='active-id'); currentState.status=active
- **Trigger:** Emit StateResponse with sessionState.status=ABANDONED (proto enum value 4 at module_state.pbenum.dart:55–56)
- **Assert:** Events stream receives ModuleSessionAbandoned (declared ModuleStateEvent.dart:19); currentState == ModuleState.initial() (line 150 in _processProtoEvent)

#### should reset moduleSessionId to null on ABANDONED

- **Setup:** currentState holds moduleSessionId='live-id' (ModuleState.dart:4)
- **Trigger:** Emit StateResponse with sessionState.status=ABANDONED
- **Assert:** currentState == ModuleState.initial() (line 150); moduleSessionId field is null per ModuleState.initial() at ModuleState.dart:10–11

### Group 3: Session Error — no_active_session Demotion

**Branch:** Line 92–96 in `_openSessionStream`

#### should silently reset to ModuleState.initial() when sessionError with code='no_active_session' arrives

- **Setup:** Establish connected session stream; currentState.status=active
- **Trigger:** Emit StateResponse with sessionError.code='no_active_session', sessionError.message='<any>' (StateErrorEvent.dart fields: code at module_state.pb.dart:413)
- **Assert:** currentState == ModuleState.initial() (line 95); log line produced at line 93: "[ModuleStateChannel] session error: no_active_session — ..."; no ModuleStateEvent emitted (only state.add occurs, no events.add)

#### should not emit any ModuleStateEvent when no_active_session error is received

- **Setup:** Stream listener collecting events (via channel.events PublishSubject at ModuleStateChannel.dart:23)
- **Trigger:** Receive StateResponse with sessionError.code='no_active_session'
- **Assert:** Events stream receives no messages; only state BehaviorSubject updated at line 95 (no events.add() call in the error handler lines 92–96)

### Group 4: Metadata Attachment — module-session-id Header

**Branch:** Line 76–79 in `_openSessionStream`

#### should attach module-session-id metadata when opening stream with active status and non-empty moduleSessionId

- **Setup:** currentState = ModuleState(moduleSessionId: 'live-123', status: active); connectionManager.connectionState emits connected
- **Trigger:** Emit connection-state=connected (triggers _openSessionStream at line 58)
- **Assert:** moduleStateService.trackActivity called at line 80 with CallOptions(metadata: {'module-session-id': 'live-123'}); metadata guard at lines 76–79: status == ModuleStateStatus.active AND liveId != null AND liveId.isNotEmpty

#### should not attach module-session-id metadata when status != active

- **Setup:** currentState = ModuleState(moduleSessionId: 'live-123', status: idle)
- **Trigger:** Emit connection-state=connected (calls _openSessionStream at line 58)
- **Assert:** moduleStateService.trackActivity called at line 80 with options=null (guard at line 76: status == ModuleStateStatus.active fails)

#### should not attach module-session-id metadata when moduleSessionId is null

- **Setup:** currentState = ModuleState(moduleSessionId: null, status: active)
- **Trigger:** Emit connection-state=connected (calls _openSessionStream at line 58)
- **Assert:** moduleStateService.trackActivity called at line 80 with options=null (guard at line 77: liveId != null fails)

#### should not attach module-session-id metadata when moduleSessionId is empty string

- **Setup:** currentState = ModuleState(moduleSessionId: '', status: active)
- **Trigger:** Emit connection-state=connected (calls _openSessionStream at line 58)
- **Assert:** moduleStateService.trackActivity called at line 80 with options=null (guard at line 77: liveId.isNotEmpty fails for empty string)

#### should attach module-session-id metadata on each _openSessionStream call based on current state

- **Setup:** Initial state is idle; currentState.moduleSessionId=null; then state transitions to active with moduleSessionId='s1'
- **Trigger:** connectionState.add(connected) → _openSessionStream called (line 58)
- **Assert:** trackActivity called at line 80 with metadata based on currentState at call time (line 75: liveId = currentState.moduleSessionId); _backoffConfirmed reset to false at line 73 on each _openSessionStream call

### Group 5: Client Timestamp Forwarding

**Branch:** Line 165–174 (start), Line 189–196 (end)

#### should forward clientTimestampMs from start() to proto.ActivityStartCmd

- **Setup:** Create channel, wire connection/auth streams, establish connected state
- **Trigger:** Call channel.start(type: ActivityType.breath, refId: 'sess-1', clientTimestampMs: 1234567890) (ModuleStateChannel.dart:165)
- **Assert:** Captured StateRequest.activityStart.clientTimestampMs == Int64(1234567890) (line 172 wraps clientTimestampMs in Int64(); ActivityStartCmd.dart field at module_state.pb.dart:98, type $fixnum.Int64)

#### should send Int64.ZERO if clientTimestampMs=0 is passed to start()

- **Setup:** Call start(type: breath, refId: '', clientTimestampMs: 0) (line 165)
- **Trigger:** Capture StateRequest via _sessionSink.add at line 210
- **Assert:** activityStart.clientTimestampMs == Int64(0) (line 172: clientTimestampMs != null check means 0 is treated as truthy, Int64(0) sent, not null)

#### should not set clientTimestampMs field if start() is called without clientTimestampMs argument

- **Setup:** Call start(type: breath, refId: 'sess-1') — clientTimestampMs omitted (optional, defaults to null at line 165)
- **Trigger:** Capture StateRequest via _sessionSink.add at line 210
- **Assert:** activityStart.clientTimestampMs is not set (line 172: clientTimestampMs != null check fails, null is passed to ActivityStartCmd constructor; proto field uninitialized per module_state.pb.dart:113 factory)

#### should forward clientTimestampMs from end() to proto.ActivityEndCmd

- **Setup:** Start a session first (channel.start(...)), then call end(clientTimestampMs: 9876543210) (line 189)
- **Trigger:** Capture StateRequest via _sessionSink.add at line 210
- **Assert:** activityEnd.clientTimestampMs == Int64(9876543210) (line 193: clientTimestampMs != null check, Int64 wrapping; ActivityEndCmd field at module_state.pb.dart:155, type $fixnum.Int64)

#### should not set clientTimestampMs in ActivityEndCmd if end() is called without clientTimestampMs

- **Setup:** Call end() with no clientTimestampMs argument (optional, defaults to null at line 189)
- **Trigger:** Capture StateRequest via _sessionSink.add at line 210
- **Assert:** activityEnd.clientTimestampMs is not set (line 193: clientTimestampMs != null check fails, null passed to ActivityEndCmd; proto field uninitialized per module_state.pb.dart:113)

### Group 6: State Transitions — ACTIVE / COMPLETED / INTERRUPTED / ACTIVITY_STATUS_UNSPECIFIED

**Branch:** Line 134–160 (covers all other proto.ActivityStatus values)

#### should handle ACTIVE as before (emit ModuleSessionStarted on first active, ModuleSessionPaused on pause, ModuleSessionUnpaused on resume)

- **Setup:** Emit ACTIVE (proto enum value 1 at module_state.pbenum.dart:49–50) with status transitions (idle→active, active+paused→active+!paused)
- **Trigger:** Receive StateResponse with sessionState.status=ACTIVE via trackActivity stream
- **Assert:** ModuleSessionStarted emitted on first active (line 143); ModuleSessionPaused emitted when isPaused transitions true (line 145); ModuleSessionUnpaused emitted when isPaused transitions false (line 147)

#### should emit ModuleSessionEnded when COMPLETED arrives

- **Setup:** Initialize with active session (currentState.status=active)
- **Trigger:** Emit StateResponse with sessionState.status=COMPLETED (proto enum value 3 at module_state.pbenum.dart:53–54)
- **Assert:** Events stream receives ModuleSessionEnded (declared ModuleStateEvent.dart:17); state reset to initial (line 150–151)

#### should emit ModuleSessionEnded when INTERRUPTED arrives

- **Setup:** Initialize with active session (currentState.status=active)
- **Trigger:** Emit StateResponse with sessionState.status=INTERRUPTED (proto enum value 5 at module_state.pbenum.dart:57–58)
- **Assert:** Events stream receives ModuleSessionEnded; state reset to initial (line 149–151)

#### should reset to initial state when ACTIVITY_STATUS_UNSPECIFIED arrives

- **Setup:** Initialize with active session (currentState.status=active)
- **Trigger:** Emit StateResponse with sessionState.status=ACTIVITY_STATUS_UNSPECIFIED (proto enum value 0, sentinel, at module_state.pbenum.dart:47–48)
- **Assert:** currentState == ModuleState.initial() (line 157); _isPendingStart=false, _isPendingPause=false (line 156, both reset)

#### should log unhandled status when an unknown ActivityStatus is received

- **Setup:** Mock logPrint or capture logs; create StateResponse with sessionState.status=unknown (future enum value not yet handled by switch)
- **Trigger:** Emit via trackActivity stream
- **Assert:** Log at line 159: "[ModuleStateChannel] unhandled status: $status"

### Group 7: Stream Lifecycle — Connection State Transitions

**Branch:** Line 55–64 (constructor), Line 72–114 (_openSessionStream)

#### should open session stream when connectionState=connected

- **Setup:** Construct channel with mocked connectionManager (GrpcConnectionManager.dart provides connectionState Stream)
- **Trigger:** connectionManager.connectionState.add(GrpcConnectionState.connected)
- **Assert:** moduleStateService.trackActivity called at line 80; _sessionSub assigned at line 81; _sessionSink assigned at line 74; isConnected==true (line 40)

#### should close session stream when connectionState=disconnected

- **Setup:** Initialize in connected state (_sessionSub != null, _sessionSink != null)
- **Trigger:** connectionManager.connectionState.add(GrpcConnectionState.disconnected)
- **Assert:** _closeSessionStream called at line 60; _sessionSub cancelled at line 117; _sessionSink closed at line 119; isConnected==false (line 40 checks _sessionSub != null)

#### should do nothing on connectionState=connecting

- **Setup:** Construct channel; _sessionSub=null, _sessionSink=null (initial state)
- **Trigger:** connectionManager.connectionState.add(GrpcConnectionState.connecting)
- **Assert:** switch case at line 61 hits break (no-op); _sessionSub and _sessionSink remain null

#### should confirm connection on first successful proto event after backoff (confirmConnected called once)

- **Setup:** Initialize with connected state (connectionState=connected, _openSessionStream called at line 58); _backoffConfirmed=false at line 73
- **Trigger:** Emit first StateResponse via trackActivity stream
- **Assert:** connectionManager.confirmConnected() called at line 85 exactly once; _backoffConfirmed set to true at line 84

#### should not call confirmConnected again on subsequent events

- **Setup:** Emit first StateResponse (confirmConnected called at line 85, _backoffConfirmed set to true at line 84), then emit second StateResponse
- **Trigger:** Receive second event via stream.listen at line 82
- **Assert:** confirmConnected not called again (guard at line 83: if (!_backoffConfirmed) fails because it's now true)

#### should disconnect and schedule reconnect on session stream error

- **Setup:** Initialize in connected state (_sessionSub assigned at line 81)
- **Trigger:** trackActivity stream fires onError callback with exception (line 101)
- **Assert:** _closeSessionStream called at line 103; connectionManager.disconnect() at line 104 (GrpcConnectionManager.dart:93); connectionManager.scheduleReconnect() at line 105 (GrpcConnectionManager.dart:111); log at line 102: "[ModuleStateChannel] session stream error: $e"

#### should disconnect and schedule reconnect on session stream done

- **Setup:** Initialize in connected state (_sessionSub assigned at line 81)
- **Trigger:** trackActivity stream fires onDone callback (line 107)
- **Assert:** _closeSessionStream called at line 109; connectionManager.disconnect() at line 110 (GrpcConnectionManager.dart:93); connectionManager.scheduleReconnect() at line 111 (GrpcConnectionManager.dart:111); log at line 108: "[ModuleStateChannel] session stream done"

#### should filter DISCONNECTED status silently (return without processing)

- **Setup:** Emit StateResponse with sessionState.status=DISCONNECTED (proto enum value 2 at module_state.pbenum.dart:51–52)
- **Trigger:** Receive event via stream.listen at line 82
- **Assert:** switch at line 87 branches sessionState case (line 88), then line 90 check (event.status == proto.ActivityStatus.DISCONNECTED) is true, return statement at line 90 exits without calling _processProtoEvent; no state change; no event emission

### Group 8: Auth State Transitions

**Branch:** Line 65–67 (constructor)

#### should reset state when authStream emits GuestState

- **Setup:** Initialize in active state with moduleSessionId='test' (ModuleState(moduleSessionId: 'test', status: active)); authStream listener at line 65
- **Trigger:** authStream.add(GuestState(...)) (exact type from User/Models/AuthState.dart)
- **Assert:** _reset() called at line 66; currentState == ModuleState.initial() (line 225); _isPendingStart=false (line 223), _isPendingPause=false (line 224)

#### should not reset state when authStream emits AuthenticatedState

- **Setup:** Initialize in active state (currentState.status=active)
- **Trigger:** authStream.add(AuthenticatedState(...)) (exact type from User/Models/AuthState.dart)
- **Assert:** authStream listener at line 65 checks if (auth is GuestState) — false for AuthenticatedState, so _reset() not called; currentState unchanged

#### should react to guest logout even if session stream is disconnected

- **Setup:** Initialize in active state; connectionManager.connectionState.add(GrpcConnectionState.disconnected) — _closeSessionStream called at line 60, _sessionSub=null, _sessionSink=null
- **Trigger:** authStream.add(GuestState(...))
- **Assert:** _reset() called at line 66 regardless of connection state; currentState == ModuleState.initial() (line 225); _sendSessionRequest guard at line 206 prevents any attempted send

### Group 9: Request Sending — _sendSessionRequest Guard

**Branch:** Line 205–211

#### should drop request if _sessionSink is null (not connected)

- **Setup:** Construct channel; connectionState=disconnected (or never set to connected) — _sessionSink=null
- **Trigger:** Call start(type: breath), pause(), unpause(), end(), or stop()
- **Assert:** _sendSessionRequest called at lines 174, 180, 186, 194, 200 respectively; guard at line 206 (_sessionSink == null) is true; log at line 207: "[ModuleStateChannel] not connected, dropping request"; _sessionSink.add never executed

#### should send request if _sessionSink is not null

- **Setup:** Initialize in connected state; _sessionSink = StreamController<proto.StateRequest>() at line 74, not null
- **Trigger:** Call start(type: ActivityType.breath, refId: 'sess-1') (line 165); _sendSessionRequest at line 174
- **Assert:** Guard at line 206 (_sessionSink == null) is false; _sessionSink!.add(request) at line 210 called exactly once with StateRequest; no log produced

### Group 10: Disposal and Cleanup

**Branch:** Line 230–236 (dispose)

#### should cancel connectionState subscription on dispose

- **Setup:** Construct channel (_connectionSub = ... at line 55); call dispose()
- **Trigger:** Call connectionManager.connectionState.add(GrpcConnectionState.disconnected) after dispose
- **Assert:** _connectionSub.cancel() at line 231 cancels the subscription; no listener fires; _openSessionStream or _closeSessionStream not called again

#### should cancel authState subscription on dispose

- **Setup:** Construct channel (_authSub = ... at line 65); call dispose()
- **Trigger:** authStream.add(GuestState(...)) after dispose
- **Assert:** _authSub.cancel() at line 232 cancels the subscription; no listener fires; _reset() not called; state unchanged

#### should close session stream on dispose

- **Setup:** Initialize in connected state (_sessionSub != null, _sessionSink != null from _openSessionStream at line 58)
- **Trigger:** Call dispose() (line 230)
- **Assert:** _closeSessionStream() at line 233; _sessionSub.cancel() at line 117; _sessionSink.close() at line 119; isConnected==false (line 40 checks _sessionSub != null)

#### should close state and events BehaviorSubject/PublishSubject on dispose

- **Setup:** Construct channel; attach listeners to state (line 25: _state.stream) and events (line 26: _events.stream)
- **Trigger:** Call dispose() (line 230)
- **Assert:** _state.close() at line 234 (BehaviorSubject<ModuleState>, line 22); _events.close() at line 235 (PublishSubject<ModuleStateEvent>, line 23); listeners receive done/close event; no further events can be emitted

## Gotchas

1. **Int64 conversion:** clientTimestampMs is wrapped in `Int64(...)` (line 172 in start(), line 193 in end()) before passing to ActivityStartCmd/ActivityEndCmd proto messages. Fake stream responses must also use Int64 (fixnum.Int64) for comparison (module_state.pb.dart:98, 155).

2. **CallOptions metadata:** gRPC metadata is a Map<String, String>. At line 78, CallOptions(metadata: {'module-session-id': liveId}) creates the options map. The fake moduleStateService must capture the options parameter at line 80 (trackActivity call) and expose it for assertion (e.g., via a recorded call log).

3. **Proto enum values:** ActivityStatus values from module_state.pbenum.dart: ACTIVITY_STATUS_UNSPECIFIED=0 (line 47), ACTIVE=1 (line 49), DISCONNECTED=2 (line 51), COMPLETED=3 (line 53), ABANDONED=4 (line 55), INTERRUPTED=5 (line 57), RESUMED=6 (line 59). Must be imported as proto.ActivityStatus and used correctly in tests.

4. **Backoff guard:** The `_backoffConfirmed` field (line 33) is set to false on _openSessionStream (line 73) and toggled true on first response (line 84). Tests opening a new stream must emit at least one StateResponse to verify confirmConnected was called at line 85.

5. **DISCONNECTED filtering:** Line 90 returns early (if event.status == proto.ActivityStatus.DISCONNECTED) return; and **never calls _processProtoEvent** at line 91. This is a silent filter applied before _processProtoEvent. Tests must verify no event emission and no state change, not just check for a no-op in _processProtoEvent.

6. **no_active_session demotion:** This error code (checked at line 94: if (r.sessionError.code == 'no_active_session')) resets state silently at line 95 (state.add(ModuleState.initial())) without emitting a ModuleStateEvent (no events.add() call). Log is produced at line 93 for all sessionError responses. Distinguish from other sessionError codes that should log but currently don't trigger reconnect (per current implementation at lines 92–96).

7. **Metadata attachment decision:** The guard at lines 76–77 checks three conditions: (1) currentState.status == ModuleStateStatus.active (line 76), (2) liveId != null (line 77), (3) liveId.isNotEmpty (line 77). All three must be true for metadata to attach at line 78. Empty string is treated like null (line 77 condition fails on empty string).

8. **Pending guards:** `_isPendingStart` (line 31) and `_isPendingPause` (line 32) prevent duplicate requests. start() returns early at line 166 if (currentState.status == active || _isPendingStart). pause() returns early at line 178 if (currentState.isPaused || _isPendingPause). Tests confirming these are cleared must observe that a different command works (e.g., after RESUMED clears _isPendingStart at line 130, a subsequent pause should be allowed even if it was previously guarded).

9. **Subscription lifetime:** The _connectionSub (late final at line 44) and _authSub (late final at line 45) are late-initialized in the constructor (lines 55, 65) and must remain alive across connection cycles. dispose() cancels them at lines 231–232. Tests resetting state must verify subscriptions survive (e.g., by emitting another event post-reset to confirm listeners still fire).

10. **StateResponse.whichEvent():** At line 87, r.whichEvent() is called on StateResponse (module_state.pb.dart:654–655). Returns StateResponse_Event enum (line 592): sessionState, sessionError, or notSet. Must use the proto API correctly to create test responses with only one event set. StateResponse factory at module_state.pb.dart:597 accepts sessionState and sessionError; use only one to match proto oneof semantics.
