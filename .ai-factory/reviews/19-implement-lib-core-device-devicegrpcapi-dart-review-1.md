# Review: 19 — Implement DeviceGrpcApi

## Files Changed

| File | Action |
|---|---|
| `lib/Device/DeviceGrpcApi.dart` | New |
| `lib/Device/DeviceRepository.dart` | Modified |
| `lib/Core/App.dart` | Modified |
| `lib/Core/Api/DeviceApi.dart` | Deleted |

## Checklist

- **Proto field mapping:** All 11 fields on `DevicePingRequest` map 1:1 to `proto.PingRequest`. Types match — `screenWidth`/`screenHeight` are `int` on both sides (`aI` = int32 in proto). No field is missed or misspelled.
- **PingResponse is empty:** Confirmed — no fields in the generated class. `void` return type is correct.
- **No dangling imports:** `grep` for `package:mind/Core/Api/DeviceApi.dart` across `lib/` returns zero matches. Clean deletion.
- **GrpcClient.deviceService exists:** Confirmed at `GrpcClient.dart:32` — `late final deviceService = DeviceServiceClient(...)`.
- **DeviceRepository contract preserved:** Constructor accepts `DeviceGrpcApi` via named `api:` parameter. Only method called is `.ping(request)` — signature matches. The `catch (_) {}` in `DeviceRepository.ping()` still guards gRPC errors.
- **App.dart wiring:** Single-line, no trailing comma — matches the style rule. Import swapped from `DeviceApi` to `DeviceGrpcApi`. No other changes to initialization order.
- **File placement:** `lib/Device/DeviceGrpcApi.dart` is next to `lib/Device/DeviceRepository.dart` — consistent with `AuthGrpcApi` in `lib/User/`, `SyncGrpcApi` in `lib/Core/Sync/`, `BreathSessionGrpcApi` in `lib/BreathModule/Core/`.
- **Pattern consistency:** No try/catch in API class (errors propagate to caller) — matches `SyncGrpcApi`, `BreathSessionGrpcApi`, `AuthGrpcApi`.
- **Auth on ping:** The device ping fires at App.dart:135, before user auth is loaded (line 140). This was also true with the REST `DeviceApi` — `AuthInterceptor`/`GrpcAuthInterceptor` both read from `FlutterSecureStorage` and attach a token if present. Behavior is preserved; any auth failure is caught by the repository's `catch (_) {}`.

## Issues

None.

REVIEW_PASS
