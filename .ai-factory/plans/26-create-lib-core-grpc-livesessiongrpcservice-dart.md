# Plan: Create `lib/Core/Grpc/LiveSessionGrpcService.dart`

## Context

Replace the Socket.IO transport with a gRPC streaming service that manages two long-lived server connections — live session (bidi) and telemetry (bidi) — with exponential back-off reconnect, while exposing the same output streams that existing consumers (`LiveBreathSessionNotifier`, `BreathTelemetryService`, `SocketDebugOverlay`) already depend on. The sync watcher is **out of scope** — `SyncGrpcListener` (§3.4) already handles `watchChanges()` with its own reconnect and event mapping.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Skeleton and reconnect infrastructure

- [x] **Task 1: Class skeleton with fields, constructor, connection state, and lifecycle**
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Create the class with:
  - Constructor taking `LiveServiceClient liveService`, `TelemetryServiceClient telemetryService`, `Stream<AuthState> authStream`. All injected via constructor per RULES.md.
  - `_connectionState` as `BehaviorSubject<SocketConnectionState>.seeded(disconnected)` — same type as `LiveSocketService`. Expose via `Stream<SocketConnectionState> get connectionState`.
  - Broadcast `StreamController`s matching `LiveSocketService`'s surface: `_sessionStateController` (`StreamController<Map<String, dynamic>>.broadcast()`), `_telemetryStateController` (`StreamController<void>.broadcast()`), `_dataAckController` (`StreamController<Map<String, dynamic>>.broadcast()`).
  - `ValueNotifier<String> lastSentMessage` and `lastReceivedMessage` for `SocketDebugOverlay`.
  - Nullable handles for the two active streams: `StreamSubscription<LiveResponse>? _liveSub`, `StreamSubscription<TelemetryResponse>? _telemetrySub`.
  - Nullable `StreamController<LiveRequest>? _liveSink` and `StreamController<TelemetryData>? _telemetrySink` — the outbound sides of the bidi streams. On reconnect, old controllers are closed and new ones created.
  - `bool _isAuthenticated` flag and `late final StreamSubscription<AuthState> _authSubscription` — subscribe in constructor: on `AuthenticatedState` set flag and call `connect()`, on `GuestState` clear flag and call `disconnect()`. Follow `SyncGrpcListener`'s auth-gating pattern.
  - `bool get isConnected` — true only when both `_liveSub` and `_telemetrySub` are non-null (no sync stream — `SyncGrpcListener` handles that independently).
  - `connect()` — opens live and telemetry streams **in parallel** via `Future.wait([_openLiveStream(), _openTelemetryStream()])`. Emits `connecting` before opening, then `connected` once both are established. If either future throws, catch the error, call `disconnect()` to tear down any partially-opened stream, then call `_scheduleReconnect()`. Use a `_isConnecting` bool guard (same deduplication pattern as `LiveSocketService`).
  - `disconnect()` — cancels both subscriptions, closes outbound sink controllers, nulls handles, cancels reconnect timer, emits `disconnected`.
  - `dispose()` — calls `disconnect()`, cancels `_authSubscription`, closes all stream controllers and BehaviorSubject, disposes `ValueNotifier`s.
  - Implement `ILiveSocketService` so `LiveBreathSessionNotifier` can use this as a drop-in. The interface requires `sessionStateEvents`, `syncChangedEvents`, and `emitLive()` — wire `sessionStateEvents` to `_sessionStateController.stream`. For `syncChangedEvents` return an empty never-emitting stream (sync now uses `SyncGrpcListener`, not this service). `emitLive()` will be filled in Task 5.
  - Also expose `telemetryStateEvents`, `dataAckEvents`, and `emitTelemetry()` (matching `LiveSocketService`'s non-interface surface) so `BreathTelemetryService` can consume them. `emitTelemetry()` body filled in Task 5.

- [x] **Task 2: Exponential back-off reconnect logic** (depends on Task 1)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Add private reconnect infrastructure:
  - `Timer? _reconnectTimer`, `int _reconnectAttempt = 0`.
  - `static const Duration _initialDelay = Duration(seconds: 1)` and `static const Duration _maxDelay = Duration(seconds: 30)` — matching `LiveSocketService`'s Socket.IO config (1s initial, 30s max).
  - `Duration _nextDelay()` — computes `min(_initialDelay * pow(2, _reconnectAttempt), _maxDelay)` with ±25% random jitter to avoid thundering herd. Increments `_reconnectAttempt`.
  - `_scheduleReconnect()` — if `!_isAuthenticated` return (auth-gated, like `SyncGrpcListener`). Cancel any existing `_reconnectTimer`. Set timer with `_nextDelay()`. On fire: call `connect()`. Log the delay with `dart:developer log()`.
  - `_resetBackoff()` — sets `_reconnectAttempt = 0`. Called inside `connect()` after both streams successfully open.
  - When either stream subscription hits `onError` or `onDone`, call `disconnect()` (tear down both streams — they share auth context, so if one dies the other is likely stale) then `_scheduleReconnect()`.

### Phase 2: gRPC stream channels

- [x] **Task 3: Live bidi stream — open, listen, map responses** (depends on Task 2)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Implement `Future<void> _openLiveStream()`:
  - Create a new `_liveSink = StreamController<LiveRequest>()`.
  - Open the bidi call: `final response = liveService.liveSession(_liveSink!.stream)`.
  - Subscribe: `_liveSub = response.listen(...)`.
  - `onData` handler receives `LiveResponse`. Switch on `response.whichEvent()`:
    - `LiveResponse_Event.sessionState` — extract `SessionStateEvent`, map to `Map<String, dynamic>` matching the JSON shape that `LiveBreathSessionNotifier._onSessionState()` expects: `{'status': _mapSessionStatus(event.status), 'liveSessionId': event.liveSessionId, 'isPaused': event.isPaused}`. **Filter `DISCONNECTED`** — do not add to `_sessionStateController`. `DISCONNECTED` is a transport-level concern, not a session lifecycle event; forwarding it would cause `LiveBreathSessionNotifier` to log `"unknown status: disconnected"` noise since it doesn't handle that value. For all other statuses, add to `_sessionStateController`. Update `lastReceivedMessage.value` with `WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle` guard (see Task 5 notes).
    - `LiveResponse_Event.sessionError` — log the error code and message. Do not propagate to session state controller (errors are transport-level, not session-level).
    - `LiveResponse_Event.notSet` — ignore.
  - Add a private `String _mapSessionStatus(SessionStatus status)` helper that maps proto enum to the lowercase string that `LiveBreathSessionNotifier` already parses: `ACTIVE→'active'`, `RESUMED→'resumed'`, `COMPLETED→'completed'`, `ABANDONED→'abandoned'`, `INTERRUPTED→'interrupted'`. Return `'unknown'` for `SESSION_STATUS_UNSPECIFIED` and `DISCONNECTED` (though `DISCONNECTED` is filtered before this point).
  - `onError` — log, call `disconnect()` then `_scheduleReconnect()`.
  - `onDone` — same as `onError`.

- [x] **Task 4: Telemetry bidi stream — open, listen, map responses** (depends on Task 2)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Implement `Future<void> _openTelemetryStream()`:
  - Create `_telemetrySink = StreamController<TelemetryData>()`.
  - Open: `final response = telemetryService.streamTelemetry(_telemetrySink!.stream)`.
  - Subscribe: `_telemetrySub = response.listen(...)`.
  - Immediately fire `_telemetryStateController.add(null)` after subscribing — this signals to `BreathTelemetryService` that the telemetry channel is open (triggers `flushBuffer()`), matching the `_telemetrySocket!.onConnect` behavior in `LiveSocketService`.
  - `onData` handler: switch on `response.whichEvent()`:
    - `TelemetryResponse_Event.ack` — extract `TelemetryAck`, map to `Map<String, dynamic>`: `{'maxSamplesPerSecond': ack.maxSamplesPerSecond, 'sessionId': ack.sessionId}`. Add to `_dataAckController`. Update `lastReceivedMessage.value` with `SchedulerPhase.idle` guard.
    - `TelemetryResponse_Event.error` — log the error.
    - `TelemetryResponse_Event.notSet` — ignore.
  - `onError` / `onDone` — log, call `disconnect()` then `_scheduleReconnect()`.

### Phase 3: Public API and proto mapping

- [x] **Task 5: `emitLive()` and `emitTelemetry()` with proto message mapping** (depends on Tasks 3, 4)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`
  Implement the outbound command methods:
  - `emitLive(String event, [Map<String, dynamic>? data])` — the `ILiveSocketService` contract. Map the string event names that `LiveBreathSessionNotifier` sends to proto messages:
    - `'activity:start'` → `LiveRequest(activityStart: ActivityStartCmd(activityType: _mapActivityType(data!['activityType']), refId: data['activityRefId']))`. Map activity type from the data parameter: `data['activityType'] == 'breath' ? ActivityType.BREATH : ActivityType.ACTIVITY_TYPE_UNSPECIFIED`. This avoids hardcoding `BREATH` and respects the proto's extensibility.
    - `'activity:end'` → `LiveRequest(activityEnd: ActivityEndCmd())`
    - `'activity:stop'` → `LiveRequest(activityStop: ActivityStopCmd())`
    - `'activity:pause'` → `LiveRequest(activityPause: ActivityPauseCmd())`
    - `'activity:resume'` → `LiveRequest(activityResume: ActivityResumeCmd())`
    - Unknown event → log a warning and return.
  - Add the `LiveRequest` to `_liveSink?.add(request)`. Guard: if `_liveSink == null` (not connected), log and drop.
  - Update `lastSentMessage.value` with `WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle` guard — match `LiveSocketService`'s pattern exactly to avoid `setState() during build` exceptions in `SocketDebugOverlay`.
  - `emitTelemetry(String event, [dynamic data])` — matches `LiveSocketService.emitTelemetry` signature. The `data` is a `Map<String, dynamic>` with `sessionId`, `timestamp`, and nested `data` map. Map to `TelemetryData(sessionId: ..., timestamp: Int64(...), moduleId: 'breath', instructionType: 'breath_phase', data: _mapToStruct(data['data']))`.
  - Add a private `Struct _mapToStruct(Map<String, dynamic> map)` helper with explicit type-dispatch for protobuf `Value` wrappers:
    - `String` → `Value(stringValue: v)`
    - `int` → `Value(numberValue: v.toDouble())` — protobuf `Value` has no int setter, must convert to double
    - `double` → `Value(numberValue: v)`
    - `bool` → `Value(boolValue: v)`
    - `null` → `Value(nullValue: NullValue.NULL_VALUE)`
    - `Map<String, dynamic>` → `Value(structValue: _mapToStruct(v))` (recursive)
    - `List` → `Value(listValue: ListValue(values: v.map(_valueFrom).toList()))` (recursive)
    - Unknown type → throw `ArgumentError` with the runtime type for debugging
    Extract a `Value _valueFrom(dynamic v)` private helper to avoid duplicating the type switch.
  - Add to `_telemetrySink?.add(telemetryData)`. Guard if null.
  - Update `lastSentMessage.value` with the same `SchedulerPhase.idle` guard.
  - Add a private `ActivityType _mapActivityType(String? type)` helper: `type == 'breath' ? ActivityType.BREATH : ActivityType.ACTIVITY_TYPE_UNSPECIFIED`.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add LiveSessionGrpcService with reconnect and live stream channel"
- **Commit 2** (after tasks 4-5): "Add telemetry channel with outbound proto mapping"
