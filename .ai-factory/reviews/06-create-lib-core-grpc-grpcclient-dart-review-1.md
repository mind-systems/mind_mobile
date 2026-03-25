# Code Review: 06 — Create `lib/Core/Grpc/GrpcClient.dart`

**Files reviewed:** `GrpcClient.dart` (new), `AppLifecycleService.dart`, `App.dart`, `Environment.dart`, `Environment.example.dart`

---

## Plan compliance

All four tasks implemented correctly. The original plan review issues are resolved:
- No logout shutdown — idle channel stays alive across re-login.
- Constructor injection for `detachStream` — `GrpcClient` manages its own subscription (RULES.md compliant).
- TLS toggle via `isSecure` parameter backed by `Environment.grpcSecure`.
- `onDetach` uses the named callback pattern consistent with existing `onResume`.

## File-by-file review

### `lib/Core/Grpc/GrpcClient.dart` (new)

- `ClientChannel` construction in initializer list with correct `ChannelOptions(credentials:)` API.
- All 8 `late final` stub getters match the generated `.pbgrpc.dart` class names exactly: `AuthServiceClient`, `BreathSessionServiceClient`, `DeviceServiceClient`, `LiveServiceClient`, `StatsServiceClient`, `SyncServiceClient`, `TelemetryServiceClient`, `UserServiceClient`.
- `shutdown()` cancels the detach subscription *before* shutting down the channel — prevents the listener from re-firing.
- If `shutdown()` is called externally first, the subscription is cancelled so detach won't double-fire. If detach fires first, same story. The ordering is safe.
- `shutdown()` is called without `await` from the detach listener. The unawaited future is fine — this is a best-effort path during app termination where the process may die at any moment.

### `lib/Core/AppLifecycleService.dart`

- `_detachController` follows the exact same pattern as `_resumeController`: broadcast `StreamController<void>`, matching getter, matching private callback with log line, closed in `dispose()`.
- `AppLifecycleListener(onResume: _onResume, onDetach: _onDetach)` — `onDetach` is a valid named parameter on `AppLifecycleListener`.

### `lib/Core/App.dart`

- Import added at the correct position (alphabetically within the `Core/` block).
- Field declared after `httpClient`, before API clients — logical grouping.
- Constructor line at line 165 placed after `appLifecycleService` (dependency) and before `socketConnectionCoordinator` — correct dependency order.
- Single-line style, no trailing commas — follows the file's style rule.
- Passed to `App._({...})` constructor — correct.

### `lib/Core/Environment.dart` + `lib/Core/Environment.example.dart`

- Three new `final` fields (`grpcHost`, `grpcPort`, `grpcSecure`) added at end of field list and constructor — matches existing pattern.
- Dev: `localhost:50051`, insecure. Prod: `grpc.mind-awake.life:443`, secure. Correct.
- Example uses `YOUR_DEV_GRPC_HOST` / `YOUR_PROD_GRPC_HOST` placeholders — consistent with existing placeholder style.
- `Environment.dart` is gitignored and won't be committed — only the example is tracked. Correct.

## No issues found

The implementation is clean, minimal, and follows all project conventions (constructor injection, single-line App.dart style, AppLifecycleService named callbacks, Environment pattern).

REVIEW_PASS
