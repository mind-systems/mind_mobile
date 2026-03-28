# Code Review — Plan #36: Replace `emitLive` with typed methods

**Files reviewed:** 6 source files + 1 test file (all changed/new files)
**Risk level:** Low

## Verification

- **Static analysis:** `flutter analyze` — no issues on all 5 changed source files.
- **Tests:** All 23 tests pass (`flutter test test/BreathModule/live_session_notifier_test.dart`).
- **No stale references:** `emitLive` does not appear in any source file. All call sites use the new typed API.
- **All implementors updated:** `LiveSessionGrpcService` and `FakeLiveSocketService` (test fake) are the only two `ILiveSocketService` implementors — both correctly implement the five new methods.

## File-by-file notes

### `lib/Core/Grpc/ActivityType.dart` (new)
Single-variant enum. Clean and minimal.

### `lib/Core/Grpc/ILiveSocketService.dart`
Interface correctly replaces `emitLive` with five typed methods. `sessionStateEvents` unchanged. `ActivityType` import added.

### `lib/Core/Grpc/LiveSessionGrpcService.dart`
- **Import collision resolved correctly:** `live.pbgrpc.dart` imported `as proto`, all proto types prefixed throughout the file (`proto.LiveRequest`, `proto.LiveResponse`, `proto.SessionStatus`, etc.). The unprefixed `TelemetryServiceClient`/`TelemetryData`/`TelemetryResponse` imports from `telemetry.pbgrpc.dart` and `Struct`/`Value` from `struct.pb.dart` remain correct since those are separate imports.
- **`_mapActivityType` return type is correct:** Returns `proto.ActivityType`, not domain `ActivityType`.
- **Exhaustive switch:** `_mapActivityType` switches on `ActivityType.breath` without a default. Since `ActivityType` is a single-variant Dart enum, the Dart analyzer will flag any future additions as non-exhaustive — this is intentional and better than a silent fallback.
- **`_sendLiveRequest` helper:** Correctly extracts the null-check + log + sink-add pattern. No duplication across the five methods.
- **`emitTelemetry` unchanged:** Still uses the stringly-typed pattern (out of scope for this plan, per roadmap).

### `lib/BreathModule/Core/LiveBreathSessionNotifier.dart`
- `start()` signature changed from 3 positional params to named params `{required ActivityType type, required String refId}`. Dead `activityRefType` parameter removed.
- All five `emitLive` calls replaced with the corresponding typed method calls.
- Guard logic (`_isPendingStart`, `_isPendingPause`, status checks) unchanged and correct.

### `lib/BreathModule/Core/LiveBreathSessionService.dart`
- Single call site updated: `_notifier.start(type: ActivityType.breath, refId: sessionId)`.

### `test/BreathModule/live_session_notifier_test.dart`
- `FakeLiveSocketService` captures typed arguments: `activityStartCalls` stores `({ActivityType type, String? refId})` records, no-arg methods use int counters. `resetCounts()` helper clears all.
- All test assertions updated to check typed fields instead of string/map tuples.
- Assertion coverage preserved: tests verify both method invocation counts and argument values (e.g., `socket.activityStartCalls.first.type`, `socket.activityStartCalls.first.refId`).

## Issues found

None.

REVIEW_PASS
