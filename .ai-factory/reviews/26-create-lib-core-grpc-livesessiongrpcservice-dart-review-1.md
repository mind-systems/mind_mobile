# Code Review: `lib/Core/Grpc/LiveSessionGrpcService.dart`

**Plan:** `26-create-lib-core-grpc-livesessiongrpcservice-dart.md`
**Risk Level:** Low

## Verification Summary

Cross-referenced the implementation against:
- Proto generated types: `live.pb.dart`, `live.pbgrpc.dart`, `telemetry.pb.dart`, `telemetry.pbgrpc.dart`
- Protobuf well-known types: `struct.pb.dart` (protobuf 6.0.0) — `Struct`, `Value`, `ListValue`, `NullValue`
- Interface: `ILiveSocketService.dart`
- Consumers: `LiveBreathSessionNotifier.dart`, `BreathTelemetryService.dart`
- Predecessor: `LiveSocketService.dart`
- Auth pattern reference: `SyncGrpcListener.dart`

All proto constructor parameters, field names, enum values, and switch discriminators match the generated code.

## No Critical Issues

## Suggestions

### 1. `_isAuthenticated` double-check after `Future.wait` — latent race risk

`SyncGrpcListener._startWatching()` checks `_isAuthenticated` twice — once before and once after its real `await` — to guard against auth state changing during the async gap. `connect()` has no equivalent check after `Future.wait`. This is safe today because `_openLiveStream()` and `_openTelemetryStream()` complete synchronously (no `await` inside either), so `Future.wait` resolves in the same microtask with no yield point for `disconnect()` to interleave.

However, if either open method later gains a real `await` (e.g., fetching auth metadata), the race becomes exploitable: `disconnect()` from the auth handler could fire mid-`Future.wait`, nulling handles, and then the `try` block would emit `connected` with stale state.

Add a guard after `Future.wait` for robustness:
```dart
await Future.wait([_openLiveStream(), _openTelemetryStream()]);
if (!_isAuthenticated) { disconnect(); return; }
_resetBackoff();
```

### 2. `math.Random()` instantiated on every `_nextDelay()` call

Line 164 creates `math.Random()` each invocation. Promote to a class field:
```dart
final math.Random _random = math.Random();
```

### 3. Duration overflow for extreme reconnect counts

`_initialDelay * math.pow(2, _reconnectAttempt)` (line 160) overflows `int` when `_reconnectAttempt >= 44` (1s * 2^44 = ~1.76e13 seconds, which overflows `Duration`'s internal microsecond `int`). The downstream `.clamp(0, ...)` catches the negative result but produces a 0ms delay instead of max delay.

In practice, 44 consecutive failures without a single success is unlikely, and `_resetBackoff()` resets the counter on success. But a simple guard makes it bulletproof:
```dart
Duration _nextDelay() {
  final exp = _reconnectAttempt.clamp(0, 20);
  final base = _initialDelay * math.pow(2, exp);
  // ...
}
```

### 4. `BreathTelemetryService` takes `LiveSocketService` (concrete type)

`BreathTelemetryService`'s constructor parameter is typed as `LiveSocketService`, not `ILiveSocketService`. Swapping in `LiveSessionGrpcService` will require either updating `BreathTelemetryService`'s constructor type or creating a shared interface that includes the telemetry surface (`telemetryStateEvents`, `dataAckEvents`, `emitTelemetry()`, `isConnected`). Same applies to `SocketDebugOverlay` which reads `lastSentMessage`/`lastReceivedMessage`. This is a wiring concern for a future task, not a bug in this file.

## Positive Notes

- Proto mapping is correct: all `LiveRequest` constructor parameter names, `LiveResponse_Event`/`TelemetryResponse_Event` enum variants, and `SessionStateEvent`/`TelemetryAck` field names match the generated code exactly.
- `Struct(fields: Iterable<MapEntry>)` matches the protobuf 6.0.0 factory signature (which takes `Iterable<MapEntry<String, Value>>?`, not `Map`). `Value` named constructors (`stringValue:`, `numberValue:`, etc.) also match the generated factories.
- `DISCONNECTED` status is correctly filtered before reaching `_sessionStateController`, avoiding noise in `LiveBreathSessionNotifier._onSessionState()`.
- `WidgetsBinding.schedulerPhase == SchedulerPhase.idle` guard is applied consistently to all `lastSentMessage.value` and `lastReceivedMessage.value` updates, matching `LiveSocketService`'s pattern.
- `_mapActivityType()` reads from `data['activityType']` instead of hardcoding `BREATH`.
- `_valueFrom()` type-dispatch covers all protobuf `Value` kinds with correct `int→double` conversion.
- `ILiveSocketService` interface is fully satisfied: `sessionStateEvents`, `syncChangedEvents` (empty stream), `emitLive()`.
- `_telemetryStateController.add(null)` after subscribing matches `LiveSocketService`'s `onConnect` signal to trigger `BreathTelemetryService.flushBuffer()`.
- Error/done handlers on both streams follow the "tear down both, reconnect" strategy per plan.

REVIEW_PASS
