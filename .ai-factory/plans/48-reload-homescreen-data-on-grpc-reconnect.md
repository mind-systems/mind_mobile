# Plan: Reload HomeScreen data on gRPC reconnect

## Context
After a gRPC drop+reconnect (user remains authenticated), `HomeScreen` never refetches suggestions/stats because `HomeService.observeChanges()` doesn't subscribe to `GrpcConnectionManager.connectionState`. This plan adds a `HomeGrpcReconnected` event and wires it through the service → ViewModel chain so the home data is refreshed on genuine reconnect transitions (without firing on the `BehaviorSubject` seed replay).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Event, service, wiring

- [x] **Task 1: Add `HomeGrpcReconnected` event**
  Files: `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart`
  Append a new subclass to the existing sealed `HomeEvent` hierarchy:
  ```dart
  class HomeGrpcReconnected extends HomeEvent {}
  ```
  Place it after `HomeAppResumed` to preserve the existing order.

- [x] **Task 2: Subscribe to gRPC connection state in `HomeService`** (depends on Task 1)
  Files: `lib/HomeModule/HomeService.dart`
  - Add import: `import 'package:mind/Core/Grpc/GrpcConnectionState.dart';`
  - Add a new required constructor parameter:
    ```dart
    final Stream<GrpcConnectionState> connectionStateStream;
    ```
    Include it in the constructor initializer list with `required this.connectionStateStream`.
  - In `observeChanges()`, build a fifth stream that uses rxdart `.pairwise()` to detect only genuine transitions to `connected` (skipping the BehaviorSubject's replayed seed):
    ```dart
    final reconnected = connectionStateStream
        .pairwise()
        .where((pair) =>
            pair.last == GrpcConnectionState.connected &&
            pair.first != GrpcConnectionState.connected)
        .map((_) => HomeGrpcReconnected() as HomeEvent);
    ```
  - Merge it into the return:
    ```dart
    return statsInvalidated.mergeWith([
      sessionExpired,
      authenticated,
      resumeEvents,
      reconnected,
    ]);
    ```
  Rationale for `pairwise()`: `BehaviorSubject` replays its current value on subscribe. If the connection is already `connected` when `HomeService` is constructed, that replay would otherwise cause a spurious reload on startup. `pairwise()` requires two emissions before producing a pair, so the replayed seed is consumed silently and only a true `non-connected → connected` transition fires the event.

- [x] **Task 3: Inject the connection state stream in `HomeModule`** (depends on Task 2)
  Files: `lib/HomeModule/HomeModule.dart`
  Pass `App.shared.connectionManager.connectionState` when constructing `HomeService`:
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
  No other call sites instantiate `HomeService` (only the module composes it), so no further wiring is needed.

- [x] **Task 4: Handle `HomeGrpcReconnected` in `HomeViewModel`** (depends on Task 1)
  Files: `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`
  Add a new branch to the `switch (event)` block in `_onEvent`, placed immediately after the `HomeAppResumed` case (preserves severity/frequency ordering):
  ```dart
  case HomeGrpcReconnected _:
    _loadInitialData();
  ```
  `_loadInitialData()` already reloads both suggestions and stats — identical to the `HomeAuthenticated` behaviour, which is the intent.
