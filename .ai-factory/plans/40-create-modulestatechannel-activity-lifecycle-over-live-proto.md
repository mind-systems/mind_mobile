# Plan: Create ModuleStateChannel — activity lifecycle over live.proto

## Context

Extract the activity lifecycle bidi stream (`LiveService/LiveSession`) into a standalone `ModuleStateChannel` that processes proto `SessionStateEvent` directly into typed Dart events — removing the `Map<String, dynamic>` intermediate. The channel absorbs `LiveBreathSessionNotifier`'s pending-guard logic and state mapping, subscribes to `GrpcConnectionManager.connectionState` for stream lifecycle, and becomes the single owner of the live bidi stream. `LiveSessionGrpcService` is updated to delegate its `ILiveSessionService` session methods to the channel (backward compat for `LiveBreathSessionNotifier` until it is deleted in the next milestone).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Define types

- [x] **Task 1: Create `ModuleState` and `ModuleStateEvent` types**
  Files: `lib/Core/Grpc/ModuleState.dart` (new), `lib/Core/Grpc/ModuleStateEvent.dart` (new)

  **`ModuleState.dart`** — follow `LiveBreathSessionState.dart` structure exactly:
  - `enum ModuleStateStatus { idle, active }`
  - `class ModuleState` with fields `liveSessionId: String?`, `status: ModuleStateStatus`, `isPaused: bool` (default `false`)
  - `const` constructor, `factory ModuleState.initial()` returning `idle` with `liveSessionId: null`

  **`ModuleStateEvent.dart`** — follow `LiveBreathSessionEvent.dart` structure:
  - `sealed class ModuleStateEvent {}`
  - `class ModuleSessionStarted extends ModuleStateEvent` with `String? liveSessionId`
  - `class ModuleSessionPaused extends ModuleStateEvent`
  - `class ModuleSessionUnpaused extends ModuleStateEvent`
  - `class ModuleSessionEnded extends ModuleStateEvent`
  - `class ModuleSessionAbandoned extends ModuleStateEvent`

### Phase 2: Make GrpcConnectionManager a pure state machine

- [x] **Task 2: Remove callbacks from `GrpcConnectionManager`** (depends on Task 1)
  Files: `lib/Core/Grpc/GrpcConnectionManager.dart`

  The manager currently creates streams via `onConnect`/`onDisconnect` callbacks. Refactor it into a pure state machine that only signals _when_ to connect — consumers subscribe to `connectionState` and handle their own stream lifecycle.

  Changes:
  - Remove constructor params `onConnect`, `onDisconnect`, `isConnected` and their backing fields (`_onConnect`, `_onDisconnect`, `_isConnected`).
  - `connect()` — change return type to `void` (remove `async`); replace `_isConnected()` guard with `currentState == GrpcConnectionState.connected`; remove `await _onConnect()` try/catch and `finally` block; emit `connecting` then `connected` synchronously; set `_isConnecting = false` at the end of the method body (after emitting `connected`) — this replaces the `finally` block that existed in the async version. Keep `_isConnecting = true` guard at the top as defense-in-depth.
  - **Do NOT call `_resetBackoff()` inside `connect()`.** In the old design, `_resetBackoff()` was gated behind `await _onConnect()` success, so the backoff escalated when the callback threw. Now that `connect()` is synchronous and consumers open their own streams asynchronously, calling `_resetBackoff()` in `connect()` would reset the attempt counter on every cycle — making the backoff stuck at ~1s forever. Instead, add a public `confirmConnected()` method that calls `_resetBackoff()`. Consumers (channel/service) call `confirmConnected()` once their stream is successfully established. This preserves the original semantics: backoff only resets on actual success.
  - `disconnect()` — remove `_onDisconnect()` call; just cancel reconnect timer and emit `disconnected`.
  - `_resumeSubscription` handler (line 76) — replace `!_isConnected()` with `currentState != GrpcConnectionState.connected` (the `_isConnected` callback is being removed).
  - Keep everything else unchanged: auth/connectivity subscriptions, `scheduleReconnect()`, exponential backoff, `dispose()`.

### Phase 3: Create ModuleStateChannel

- [x] **Task 3: Implement `ModuleStateChannel`** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart` (new)

  Constructor parameters: `LiveServiceClient liveService`, `GrpcConnectionManager connectionManager`, `Stream<AuthState> authStream`. All injected and subscribed to internally (per project rule: class manages its own subscriptions).

  **State and events** (follow `LiveBreathSessionNotifier` pattern — `BehaviorSubject` for state, `PublishSubject` for events):
  - `final _state = BehaviorSubject<ModuleState>.seeded(ModuleState.initial())`
  - `final _events = PublishSubject<ModuleStateEvent>()`
  - Expose: `Stream<ModuleState> get state`, `Stream<ModuleStateEvent> get events`, `ModuleState get currentState`

  **Backward-compat hook** (temporary, for `LiveSessionGrpcService` bridge until 7.4 deletes it):
  - `final _rawSessionEvents = StreamController<proto.SessionStateEvent>.broadcast()`
  - `Stream<proto.SessionStateEvent> get rawSessionEvents => _rawSessionEvents.stream`
  - Every `SessionStateEvent` received from the bidi stream (after filtering `DISCONNECTED`) is added to `_rawSessionEvents` before processing into typed state/events.

  **Connection state subscription:**
  - On `GrpcConnectionState.connected` → call `_openLiveStream()`
  - On `GrpcConnectionState.disconnected` → call `_closeLiveStream()`
  - On `GrpcConnectionState.connecting` → no-op

  **Bidi stream management** (absorb from `LiveSessionGrpcService._openLiveStream()`):
  - `_openLiveStream()` — create `StreamController<proto.LiveRequest>` as `_liveSink`, call `_liveService.liveSession(_liveSink!.stream)`, subscribe to response stream as `_liveSub`. On successful subscription setup, call `_connectionManager.confirmConnected()` to reset the backoff — this signals that the live stream was actually established (see Task 2 backoff design).
  - `_closeLiveStream()` — cancel `_liveSub`, close `_liveSink`, null both
  - `bool get isConnected => _liveSub != null`
  - On response: dispatch `r.whichEvent()` — for `sessionState`, filter `DISCONNECTED`, push to `_rawSessionEvents`, then call `_processProtoEvent(event)`. For `sessionError`, log. For `notSet`, ignore.
  - On stream error/done: call `_closeLiveStream()`, then `_connectionManager.disconnect()` + `_connectionManager.scheduleReconnect()`

  **Proto→typed mapping** (absorb from `LiveBreathSessionNotifier._onSessionState`, but work with proto `SessionStatus` directly instead of Map strings):
  - `_processProtoEvent(proto.SessionStateEvent event)`:
    - `ACTIVE` or `RESUMED` → set status `active`, extract `isPaused` and `liveSessionId`; emit `ModuleSessionStarted` if transitioning from non-active, `ModuleSessionPaused` if `!wasPaused && isPaused`, `ModuleSessionUnpaused` if `wasPaused && !isPaused`; clear both pending flags.
    - `COMPLETED` or `INTERRUPTED` → reset to `ModuleState.initial()`, emit `ModuleSessionEnded`.
    - `ABANDONED` → reset to `ModuleState.initial()`, emit `ModuleSessionAbandoned`.
    - `SESSION_STATUS_UNSPECIFIED` → clear `_isPendingStart`, reset to `ModuleState.initial()` (replaces the `idle` branch in the old notifier — the unspecified sentinel is what the server sends for "no active session").
    - Anything else → log warning, ignore.

  **Pending guards** (absorb from `LiveBreathSessionNotifier`):
  - `bool _isPendingStart = false`, `bool _isPendingPause = false`
  - `start({required ActivityType type, String? refId})` — return early if `currentState.status == active || _isPendingStart`; set `_isPendingStart = true`; send `LiveRequest(activityStart: ActivityStartCmd(activityType: mapType(type), refId: refId ?? ''))` via `_sendLiveRequest()`.
  - `pause()` — return early if `status != active || isPaused || _isPendingPause`; set `_isPendingPause = true`; send `LiveRequest(activityPause: ActivityPauseCmd())`.
  - `unpause()` — return early if `!isPaused`; clear `_isPendingPause`; send `LiveRequest(activityResume: ActivityResumeCmd())`.
  - `end()` — return early if `status == idle`; send `LiveRequest(activityEnd: ActivityEndCmd())`.
  - `stop()` — return early if `status == idle`; send `LiveRequest(activityStop: ActivityStopCmd())`.
  - `_sendLiveRequest(proto.LiveRequest request)` — drop with log if `_liveSink == null`.

  **Auth reset:**
  - `authStream.listen((auth) { if (auth is GuestState) _reset(); })`
  - `_reset()` — clear both pending flags, emit `ModuleState.initial()`

  **Dispose:**
  - Cancel `_connectionSub`, `_authSub`, `_liveSub`; close `_liveSink`, `_state`, `_events`, `_rawSessionEvents`

  Copy `_mapActivityType()` helper from `LiveSessionGrpcService` (maps `ActivityType.breath` → `proto.ActivityType.BREATH`).

### Phase 4: Integration

- [x] **Task 4: Update `LiveSessionGrpcService` to delegate live stream to `ModuleStateChannel`** (depends on Task 3)
  Files: `lib/Core/Grpc/LiveSessionGrpcService.dart`

  The service stops owning the live bidi stream (the channel owns it). It keeps only telemetry stream management and provides backward-compat `ILiveSessionService` for `LiveBreathSessionNotifier` until the notifier is deleted in the next milestone.

  **Constructor** — replace current params with: `GrpcConnectionManager connectionManager`, `ModuleStateChannel channel`, `TelemetryServiceClient telemetryService`. Remove `liveService`, `authStream`, `connectivityStream`, `resumeStream` params (those now go directly to the manager/channel). Store all three as final fields.

  **Remove** all live stream code: `_openLiveStream()`, `_liveSub`, `_liveSink`, `_sessionStateController`, `_sendLiveRequest()`, `_mapActivityType()` helper. Keep `_mapSessionStatus()` for the backward-compat Map conversion.

  **Add connection state subscription** — subscribe to `_connectionManager.connectionState` in the constructor body:
  - On `connected` → call `_openTelemetryStream()` (existing method, unchanged)
  - On `disconnected` → close `_telemetrySub` and `_telemetrySink`, null both
  - This replaces the old `_connect()` / `_disconnect()` callback pair.
  Remove the `_connect()` and `_disconnect()` methods.

  **Telemetry stream success** — after `_openTelemetryStream()` successfully sets up the subscription, call `_connectionManager.confirmConnected()` (same pattern as Task 3's `_openLiveStream()`). Both consumers (channel and service) confirm independently; the first call resets the backoff counter.

  **Telemetry stream error/done handlers** — change from calling `_connectionManager.disconnect()` + `_connectionManager.scheduleReconnect()` (same behavior, now on the injected manager reference).

  **`ILiveSessionService` backward-compat delegation:**
  - `sessionStateEvents` → subscribe to `_channel.rawSessionEvents` and `.map()` each proto `SessionStateEvent` to `Map<String, dynamic>` using the existing `_mapSessionStatus()` helper: `{'status': _mapSessionStatus(e.status), 'liveSessionId': e.liveSessionId, 'isPaused': e.isPaused}`.
  - `sendActivityStart(...)` → `_channel.start(type: type, refId: refId)`
  - `sendActivityEnd()` → `_channel.end()`
  - `sendActivityStop()` → `_channel.stop()`
  - `sendActivityPause()` → `_channel.pause()`
  - `sendActivityResume()` → `_channel.unpause()`

  **Other accessors:**
  - `connectionState` → `_connectionManager.connectionState`
  - `isConnected` → `_channel.isConnected && _telemetrySub != null`

  **`dispose()`** — cancel telemetry subscription, close telemetry sink, close `_telemetryStateController`, close `_dataAckController`, cancel connection state subscription. Do NOT dispose the channel or manager (App.dart owns their lifecycle).

- [x] **Task 5: Wire `GrpcConnectionManager`, `ModuleStateChannel`, and updated `LiveSessionGrpcService` in `App.dart`** (depends on Task 4)
  Files: `lib/Core/App.dart`

  **Add fields** to `App` class: `final GrpcConnectionManager connectionManager;` and `final ModuleStateChannel moduleStateChannel;`.
  Add `required this.connectionManager` and `required this.moduleStateChannel` to `App._({})`.

  **Update `initialize()`** — replace the current `liveGrpcService` line (159) with three single-line statements (follow the existing one-line style, no trailing commas):
  ```
  final connectionManager = GrpcConnectionManager(authStream: userNotifier.stream, connectivityStream: Connectivity().onConnectivityChanged, resumeStream: appLifecycleService.onResume);
  final moduleStateChannel = ModuleStateChannel(liveService: grpcClient.liveService, connectionManager: connectionManager, authStream: userNotifier.stream);
  final liveGrpcService = LiveSessionGrpcService(connectionManager: connectionManager, channel: moduleStateChannel, telemetryService: grpcClient.telemetryService);
  ```
  Order matters: manager first (no deps on other two), channel second (depends on manager), service third (depends on both).

  **Update `shared = App._(...)`** — add `connectionManager: connectionManager` and `moduleStateChannel: moduleStateChannel`.

  **Add imports** for `GrpcConnectionManager`, `ModuleStateChannel`.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add ModuleState types and make GrpcConnectionManager a pure state machine"
- **Commit 2** (after tasks 3-5): "Create ModuleStateChannel and wire live stream delegation"
