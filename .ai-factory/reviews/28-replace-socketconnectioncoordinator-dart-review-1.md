## Code Review Summary

**Files Reviewed:** 8 (LiveSessionGrpcService.dart, App.dart, BreathTelemetryService.dart, GrpcClient.dart, ILiveSocketService.dart, LiveBreathSessionNotifier.dart, LiveBreathSessionService.dart, LiveBreathSessionCoordinator.dart)
**Risk Level:** 🔴 High

### Context Gates

- **ARCHITECTURE.md** — WARN: No violations. `LiveSessionGrpcService` lives in `lib/Core/Grpc/` (infrastructure), correctly implements `ILiveSocketService`, and does not leak domain types into modules. All dependencies are constructor-injected.
- **RULES.md** — WARN: No violations introduced by this milestone. `LiveSessionGrpcService` is infrastructure, not a Module Service, so the statelessness rule does not apply. All dependencies are constructor-injected per the DI rule.
- **ROADMAP.md** — WARN: Milestones 3.5 and 3.6 are marked complete. Changes align with scope.

### Critical Issues

1. **`_mapActivityType` never matches `'breath_session'` — all sessions start with `ACTIVITY_TYPE_UNSPECIFIED`**

   `LiveBreathSessionService.startSession()` (line 12) calls `_notifier.start('breath_session', 'breath_session', sessionId)`. This string propagates through `LiveBreathSessionNotifier.start()` into the `emitLive` payload as `{'activityType': 'breath_session', ...}`.

   `LiveSessionGrpcService._mapActivityType()` (line 387-390) checks `type == 'breath'`, which does NOT match `'breath_session'`:

   ```dart
   ActivityType _mapActivityType(String? type) {
     return type == 'breath'
         ? ActivityType.BREATH
         : ActivityType.ACTIVITY_TYPE_UNSPECIFIED;
   }
   ```

   Every breathing session will be sent to the server with `activity_type: ACTIVITY_TYPE_UNSPECIFIED` (the sentinel value 0) instead of `BREATH` (value 1). The server may reject the command, create a malformed session, or silently ignore it — any of these is a runtime bug.

   **Fix**: Update the match to handle the actual value being sent:
   ```dart
   ActivityType _mapActivityType(String? type) {
     switch (type) {
       case 'breath':
       case 'breath_session':
         return ActivityType.BREATH;
       default:
         return ActivityType.ACTIVITY_TYPE_UNSPECIFIED;
     }
   }
   ```

### Suggestions

None.

### Positive Notes

- **Clean coordinator absorption**: The three lifecycle signals (auth, connectivity, resume) from the deleted `SocketConnectionCoordinator` are neatly folded into `LiveSessionGrpcService`'s constructor, keeping the same behavioral semantics while eliminating a standalone coordination class.
- **Robust reconnect**: Exponential backoff with jitter (+-25%), clamped to 30s max, with auth guards on every timer callback. The `_isConnecting` flag prevents concurrent `connect()` calls from racing.
- **`LiveBreathSessionCoordinator.reset()` fix**: Adding `_liveSessionId = null` prevents stale session IDs from leaking across session restarts — good catch.
- **No stale references**: All imports pointing to `lib/Core/Socket/` have been updated to `lib/Core/Grpc/`. No orphaned references to deleted files (`LiveSocketService`, `SocketConnectionCoordinator`, `SocketDebugOverlay`). `socket_io_client` removed from `pubspec.yaml`.
- **`syncChangedEvents` handled correctly**: Returns `Stream.empty()` since sync is now handled by `SyncGrpcListener` via a separate gRPC stream. No consumers subscribe to this.
- **Proto type mapping is thorough**: `_valueFrom` covers all protobuf `Value` types with correct dispatch (null, String, int→double, double, bool, recursive Map/List) and throws `ArgumentError` for unknowns.
