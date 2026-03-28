# Review: Remove `syncChangedEvents` from `ILiveSocketService`

**Files Changed:** 3 (`ILiveSocketService.dart`, `LiveSessionGrpcService.dart`, `live_session_notifier_test.dart`)

## Compliance

- **ARCHITECTURE.md** — WARN: No violations. The change is a pure interface narrowing within `lib/Core/Grpc/` (infrastructure layer). No domain/module boundary affected.
- **CLAUDE.md** — WARN: No violations.

## Findings

### No issues found

The change is a clean dead-code removal:

1. **`ILiveSocketService.dart`** — `syncChangedEvents` getter removed. Interface now has exactly `sessionStateEvents` and `emitLive`, both of which have live consumers (`LiveBreathSessionNotifier`). Correct.

2. **`LiveSessionGrpcService.dart`** — The stub override (returning `Stream.empty()`) and its doc comment are removed. The class still satisfies the updated `ILiveSocketService` interface — `sessionStateEvents` (line 35-37) and `emitLive` (line 311-348) remain. No orphaned imports or fields introduced.

3. **`live_session_notifier_test.dart`** — `FakeLiveSocketService` drops the `syncChangedEvents` override, matching the new interface. All test methods still compile: the fake provides `sessionStateEvents` and `emitLive`, which are the only members used by test code.

### Observations (non-blocking)

- **Stale doc reference:** `docs/core/sync-engine.md` (line 76) still mentions `liveSocketService.syncChangedEvents` in the context of the deleted `SyncSocketListener`. This is pre-existing stale documentation about the old Socket.IO architecture — not introduced by this milestone, but worth noting for a future docs cleanup pass.

- **No runtime risk:** `syncChangedEvents` had zero subscribers in `lib/` — `SyncSocketListener` (the only historical consumer) was deleted in milestone 30. The getter was already dead code.

REVIEW_PASS
