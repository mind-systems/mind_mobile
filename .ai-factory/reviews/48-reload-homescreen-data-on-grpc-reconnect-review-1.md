# Code Review: 48-reload-homescreen-data-on-grpc-reconnect

**Plan:** `.ai-factory/plans/48-reload-homescreen-data-on-grpc-reconnect.md`
**Changes reviewed:**
- `lib/HomeModule/Presentation/HomeScreen/Models/HomeDTOs.dart`
- `lib/HomeModule/HomeService.dart`
- `lib/HomeModule/HomeModule.dart`
- `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart`

## Verification against plan

- **Task 1** — `HomeGrpcReconnected extends HomeEvent` added at the bottom of the sealed family in `HomeDTOs.dart:36`. Matches plan.
- **Task 2** — `HomeService` gains `connectionStateStream` field (`HomeService.dart:20`), required ctor parameter (`HomeService.dart:28`), the `GrpcConnectionState` import (`HomeService.dart:3`), and a `pairwise()`-based fifth stream merged into the return (`HomeService.dart:70-81`). Matches plan verbatim.
- **Task 3** — `HomeModule.buildHomeScreen` passes `App.shared.connectionManager.connectionState` (`HomeModule.dart:17`). The accessor was verified against `GrpcConnectionManager.dart:18` (`Stream<GrpcConnectionState> get connectionState => _connectionState.stream;`). Matches plan.
- **Task 4** — `HomeViewModel._onEvent` gains `case HomeGrpcReconnected _: _loadInitialData();` right after the `HomeAppResumed` case (`HomeViewModel.dart:68-69`). Matches plan.

The sealed switch over `HomeEvent` remains exhaustive (the analyzer will enforce this), and `_loadInitialData()` already reloads both suggestions and stats.

## Correctness analysis

### Pairwise + BehaviorSubject seed
`GrpcConnectionManager._connectionState` is a `BehaviorSubject.seeded(disconnected)` (`GrpcConnectionManager.dart:14-16`). On subscribe, the seed replays:

- If the manager is still at the seeded `disconnected` value, `pairwise()` holds the single emission silently until the next state arrives — correct, no spurious fire.
- If the user has already authenticated and the manager has advanced to `connected` before `HomeService` subscribes, only the current value (`connected`) is replayed — still a single emission, `pairwise()` holds it, no fire on subscribe. Correct.
- On a real drop+reconnect (`connected → disconnected → connecting → connected`), `pairwise()` yields `(connected, disconnected)`, `(disconnected, connecting)`, `(connecting, connected)`; only the last passes the filter. One reload per genuine reconnect — correct.

### Cold-start fan-out (informational, not a bug)
On the cold-start authentication path:
1. `HomeViewModel.build()` schedules `_loadInitialData()` via `Future.microtask` (`HomeViewModel.dart:26`).
2. `UserNotifier` transitions to `AuthenticatedState` → `HomeAuthenticated` event → `_loadInitialData()` again.
3. `GrpcConnectionManager.connect()` (triggered by the auth listener) emits `connecting` then `connected`. After the seeded `disconnected` replay, `pairwise()` produces `(disconnected, connecting)` (filtered out) then `(connecting, connected)` → `HomeGrpcReconnected` → `_loadInitialData()` a third time.

The plan review acknowledged this duplicate-fetch scenario as accepted. Calls are idempotent, no functional issue, but worth being aware of (three back-to-back `fetchSuggestions`/`fetchStats` round-trips per login). If anyone later complains about extra network chatter at login, the fix would be `.distinct().skip(1)` instead of `.pairwise()` — out of scope for this plan.

### Concurrency / race conditions
`_loadSuggestions` and `_loadStats` are independent async flows. Rapid reconnect oscillation could in principle interleave responses such that an older response overwrites a newer one (no in-flight cancellation guard). This risk already existed for `HomeAuthenticated` and `HomeAppResumed`; the new event does not amplify it materially, and `_loadInitialData()` is not part of a sequenced state machine. Pre-existing, not introduced here.

### Resource management
The merged stream is consumed by exactly one subscriber in `HomeViewModel.build()` and cancelled via `ref.onDispose` (`HomeViewModel.dart:23-24`). The connection state stream itself is a `BehaviorSubject.stream` (broadcast) so the new subscription does not interfere with other listeners. No leak introduced.

### Type / null safety
- `pairwise()` is a stock rxdart operator; returns `Stream<Iterable<GrpcConnectionState>>`. `.last` / `.first` on the pair are non-null (the operator always emits a pair of length 2). Safe.
- The explicit `as HomeEvent` cast in `.map((_) => HomeGrpcReconnected() as HomeEvent)` mirrors the other streams and keeps `mergeWith` happy. Correct.

### Import ordering nit
`HomeService.dart:3` inserts `package:mind/Core/Grpc/GrpcConnectionState.dart` between `package:rxdart/rxdart.dart` and `package:mind/Core/Grpc/ModuleStateChannel.dart`. The file's existing ordering is already not strictly alphabetical (`rxdart` precedes `mind`), so the new placement is consistent with the file's existing style and groups all `mind/Core/Grpc/...` imports together. Linter formatter (`dart format`) does not reorder imports; no action required.

## Security
No new external input, no new authentication path, no logging of credentials. The reconnect event only triggers re-execution of pre-existing API calls (`fetchSuggestions`, `fetchStats`) that are guarded by `isGuest`. No security impact.

## Runtime risk summary
- No migration, no schema change, no codegen affected.
- No public API change outside this module.
- Single new compile-time dependency (`GrpcConnectionState`) already widely imported elsewhere in the project.
- Sealed-class exhaustive switch updated — no analyzer-warning fallout expected.

## Conclusion

The implementation matches the plan exactly and behaves correctly under all reasonable connection-state transitions, including the seeded-BehaviorSubject replay case the plan was specifically designed to handle. The only observation is the previously-acknowledged cold-start triple `_loadInitialData()` fan-out, which is intentional/accepted scope.

REVIEW_PASS
