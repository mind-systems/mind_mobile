# HomeScreen reload on gRPC reconnect

## Problem

After a gRPC drop + reconnect (e.g. server briefly unreachable), `HomeScreen` never reloads suggestions or stats. `HomeService.observeChanges()` merges four streams — none of them fires on a gRPC reconnect. `UserNotifier` stays in `AuthenticatedState` throughout, so `HomeAuthenticated` never fires. `HomeAppResumed` fires only on foreground lifecycle events. Result: the user sits on a stale or empty screen until they background/foreground the app.

`GrpcConnectionManager` already exposes `connectionState: BehaviorSubject<GrpcConnectionState>`, but `HomeService` never subscribes to it.

## Target behaviour

When `GrpcConnectionManager.connectionState` transitions from any non-connected state to `GrpcConnectionState.connected` (i.e. a real reconnect, not the initial seeded value), `HomeViewModel` calls `_loadInitialData()` exactly as it does on `HomeAuthenticated`.

## Files to change

### 1. `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart`

Add one event type to the existing sealed class:

```dart
class HomeGrpcReconnected extends HomeEvent {}
```

### 2. `lib/HomeModule/HomeService.dart`

Add one constructor parameter:

```dart
final Stream<GrpcConnectionState> connectionStateStream;
```

Full constructor:
```dart
HomeService({
  required this.userApi,
  required this.statsApi,
  required this.moduleStateChannel,
  required this.userNotifier,
  required this.resumeStream,
  required this.connectionStateStream,
});
```

Add the import:
```dart
import 'package:mind/Core/Grpc/GrpcConnectionState.dart';
```

In `observeChanges()`, add a fifth stream using rxdart `.pairwise()` to detect only genuine transitions to `connected` (not the BehaviorSubject's replay of the current value):

```dart
final reconnected = connectionStateStream
    .pairwise()
    .where((pair) => pair.last == GrpcConnectionState.connected &&
        pair.first != GrpcConnectionState.connected)
    .map((_) => HomeGrpcReconnected() as HomeEvent);
```

Merge into the return:
```dart
return statsInvalidated.mergeWith([
  sessionExpired,
  authenticated,
  resumeEvents,
  reconnected,
]);
```

Why `pairwise()`: `BehaviorSubject` replays its current value on subscription. If the connection is already `connected` when `HomeService` is created, the replay emits `connected` immediately — without `pairwise()` that would trigger a spurious reload on startup. `pairwise()` accumulates pairs and only emits when two values have arrived, so the replayed seed is consumed silently; only a genuine `non-connected → connected` transition fires.

### 3. `lib/HomeModule/HomeModule.dart`

Pass the stream when constructing `HomeService`:

```dart
final service = HomeService(
  userApi: App.shared.userApi,
  statsApi: App.shared.statsApi,
  moduleStateChannel: App.shared.moduleStateChannel,
  userNotifier: App.shared.userNotifier,
  resumeStream: App.shared.appLifecycleService.onResume,
  connectionStateStream: App.shared.connectionManager.connectionState,
);
```

### 4. `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`

Handle the new event in `_onEvent`:

```dart
case HomeGrpcReconnected _:
  _loadInitialData();
```

Insert after `HomeAppResumed` to keep the switch readable by severity/frequency.
