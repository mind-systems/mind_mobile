# Review: Rename `ILiveSocketService` → `ILiveSessionService` and all `liveSocket*` variables

**Files Changed:** 6 (`ILiveSocketService.dart` → `ILiveSessionService.dart`, `LiveSessionGrpcService.dart`, `LiveBreathSessionNotifier.dart`, `BreathTelemetryService.dart`, `App.dart`, `live_session_notifier_test.dart`)

**Plan:** `.ai-factory/plans/38-rename-ilivesocketservice-ilivesessionservice-and-all-livesocket-variables.md`

## Summary

Pure rename refactor — no behavioral changes. The interface `ILiveSocketService` → `ILiveSessionService`, all `_liveSocketService` fields → `_liveSessionService`, constructor parameters updated, and the test fake class renamed `FakeLiveSocketService` → `FakeLiveSessionService`.

## File-by-file review

1. **`lib/Core/Grpc/ILiveSessionService.dart`** (renamed from `ILiveSocketService.dart`) — File renamed via `git mv`. Class name updated to `ILiveSessionService`. Interface contract unchanged (same 6 members). Correct.

2. **`lib/Core/Grpc/LiveSessionGrpcService.dart`** — Import path updated to `ILiveSessionService.dart`. `implements` clause updated to `ILiveSessionService`. No other changes. Correct.

3. **`lib/BreathModule/Core/LiveBreathSessionNotifier.dart`** — Import updated. Field type `ILiveSocketService` → `ILiveSessionService`, field name `_liveSocketService` → `_liveSessionService`, constructor parameter `liveSocketService` → `liveSessionService`. All 6 call sites in method bodies updated. Correct.

4. **`lib/BreathModule/Core/BreathTelemetryService.dart`** — No import change needed (uses concrete `LiveSessionGrpcService`). Field `_liveSocketService` → `_liveSessionService`, constructor parameter `liveSocketService` → `liveSessionService`. All 5 usages updated. Correct.

5. **`lib/Core/App.dart`** — Field, constructor param, local variable, and 3 call sites all renamed. **Deviation from plan:** the plan specified `liveSocketService` → `liveSessionService`, but the implementation used `liveGrpcService` instead. This is the correct call — `App` already has a field `final LiveBreathSessionService liveSessionService`, so naming the `LiveSessionGrpcService` field `liveSessionService` would be a compile-time name collision. `liveGrpcService` avoids ambiguity and accurately describes the concrete type. No issues.

6. **`test/BreathModule/live_session_notifier_test.dart`** — Import updated. `FakeLiveSocketService` → `FakeLiveSessionService` (class declaration + `implements` clause). Factory return type and instantiation updated. Constructor call updated to `liveSessionService: socket`. All test bodies reference `socket` (local variable), so no further changes needed. Correct.

## Completeness check

- Grep for `ILiveSocketService`, `liveSocketService`, `_liveSocketService`, `FakeLiveSocketService` across `lib/` and `test/` returns zero matches — no stale references in live code.
- The `App.shared.liveGrpcService` field is not accessed externally (only used within `initialize()` to wire dependencies) — no downstream breakage.
- `docs/core/sync-engine.md` still mentions `liveSocketService.syncChangedEvents` (line 76) — this is pre-existing stale documentation about the deleted Socket.io architecture, not introduced by this milestone.

## Verdict

No bugs, no type mismatches, no missing updates, no security issues. The single plan deviation (`liveGrpcService` instead of `liveSessionService` in `App.dart`) is a correct fix for a name collision the plan didn't account for.

REVIEW_PASS
