# Plan: Create SyncGrpcListener

## Context
Replace the Socket.IO-based `SyncSocketListener` with a gRPC server-streaming `SyncGrpcListener` that calls `SyncServiceClient.watchChanges` and feeds received `ChangeEvent` messages into `SyncEngine.processEvents()`. This eliminates the dependency on `LiveSocketService` for sync change notifications.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Create SyncGrpcListener

- [x] **Task 1: Create `SyncGrpcListener`**
  Files: `lib/Core/Sync/SyncGrpcListener.dart`

  Create a new class `SyncGrpcListener` that replaces `SyncSocketListener`. It subscribes to a gRPC server-streaming call `SyncServiceClient.watchChanges` and forwards received events to `SyncEngine.processEvents()`.

  Constructor parameters (all injected):
  - `SyncServiceClient syncService` — the gRPC stub (already available via `grpcClient.syncService`)
  - `SyncEngine syncEngine` — same as current `SyncSocketListener`
  - `ISyncStateDao syncStateDao` — to read the current cursor for the `after_id` field
  - `Stream<AuthState> authStream` — to start/stop the stream on login/logout

  Behavior:
  - On construction, subscribe to `authStream`. When `AuthenticatedState` is emitted, call `_startWatching()`. When `GuestState` is emitted (logout), call `_stopWatching()`.
  - `_startWatching()`: read `lastEventId` from `syncStateDao`, then call `syncService.watchChanges(WatchChangesRequest(afterId: Int64(lastEventId)))`. Listen to the returned `ResponseStream<ChangeEvent>`. For each proto `ChangeEvent` message, map its `repeated SyncEventDto events` to `List<ChangeEvent>` (the domain model from `lib/Core/Api/Models/ChangeEvent.dart`) using the same mapping as `SyncGrpcApi._mapEvent` — create a private `_mapEvent(SyncEventDto)` method. Then call `syncEngine.processEvents(mapped)` with `.catchError` logging (same pattern as `SyncSocketListener`).
  - `_stopWatching()`: cancel the active `StreamSubscription` if any, set it to null.
  - **Reconnection on stream drop:** On stream error or stream done while the user is still authenticated, re-read the cursor from `syncStateDao` and re-call `watchChanges` after a short delay (`Future.delayed(Duration(seconds: 3))`). Track a `bool _isAuthenticated` flag (set `true` on `AuthenticatedState`, `false` on `GuestState`) so reconnection only fires when still logged in. On `GuestState` (logout), cancel any pending reconnect timer and the active subscription — do not reconnect. Log each reconnection attempt: `[SyncGrpcListener] stream ended, reconnecting in 3s`.
  - `dispose()`: cancel the auth subscription and the active watch subscription.

  **Import aliasing:** The proto file generates a `ChangeEvent` class (the streaming envelope in `sync.pb.dart`) which collides with the domain `ChangeEvent` from `lib/Core/Api/Models/ChangeEvent.dart`. Follow the same aliasing pattern as `SyncGrpcApi`: import `sync.pb.dart as syncProto` and import `sync.pbgrpc.dart show SyncServiceClient`. Use `syncProto.SyncEventDto` for the mapping method parameter type.

  Follow the `SyncSocketListener` pattern: constructor immediately subscribes to the auth stream (dependency injection via constructor per `RULES.md`). No `StreamController` — this is infrastructure, not a module service.

  Note on auth for streaming: `GrpcAuthInterceptor.interceptStreaming` attaches `_cachedToken` synchronously. The token is cached from the most recent unary call (which happens during `SyncEngine.waitForColdStart` → `SyncGrpcApi.fetchChanges` before `SyncGrpcListener` is constructed). This means the token will be available for the streaming call.

### Phase 2: Wire in App.dart

- [x] **Task 2: Replace `SyncSocketListener` with `SyncGrpcListener` in `App.dart`**
  Files: `lib/Core/App.dart`

  In `App.dart`:

  1. **Replace the import:** change `package:mind/Core/Sync/SyncSocketListener.dart` to `package:mind/Core/Sync/SyncGrpcListener.dart`.

  2. **Change the field type:** on the `App` class, change the field from `final SyncSocketListener syncSocketListener` to `final SyncGrpcListener syncGrpcListener`. Update both the field declaration (around line 85) and the named constructor parameter (around line 109).

  3. **Replace the instantiation** (around line 170): remove:
     ```dart
     final syncSocketListener = SyncSocketListener(liveSocketService: liveSocketService, syncEngine: syncEngine);
     ```
     Replace with a single-line initializer (per the App.dart style rule):
     ```dart
     final syncGrpcListener = SyncGrpcListener(syncService: grpcClient.syncService, syncEngine: syncEngine, syncStateDao: db.syncStateDao, authStream: userNotifier.stream);
     ```
     This must be placed **after** `syncEngine.waitForColdStart()` completes (so the gRPC auth token is cached) and the `syncEngine` local variable exists. The current position (after line 148, around line 170) works — but it can also move right after line 148 since `liveSocketService` is no longer a dependency.

  4. **Update the `App._()` constructor call** (around line 199): change `syncSocketListener: syncSocketListener` to `syncGrpcListener: syncGrpcListener`.

- [x] **Task 3: Remove `SyncSocketListener`** (depends on Task 2)
  Files: `lib/Core/Sync/SyncSocketListener.dart`

  Delete `lib/Core/Sync/SyncSocketListener.dart`. It is fully replaced by `SyncGrpcListener` and should have no remaining imports after Task 2.

  Verify no other file imports `SyncSocketListener` (grep the codebase). The only consumer was `App.dart`.
