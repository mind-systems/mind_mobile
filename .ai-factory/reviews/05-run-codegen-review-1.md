# Review: 05-run-codegen

## Scope

Commit `8bc5299` — "Add generated Dart gRPC stubs from proto files". 32 generated files in `lib/Core/Grpc/generated/` from 8 proto sources.

## Verification

**Proto-to-stub completeness** — all 8 services and 23 RPCs match their proto definitions:

| Proto | Service | RPCs | Type | Match |
|-------|---------|------|------|-------|
| auth | AuthService | 7 (SendCode, VerifyCode, GoogleAuth, Logout, CreateToken, ListTokens, DeleteToken) | Unary | OK |
| breath_sessions | BreathSessionService | 9 (CreateSession, ListSessions, GetSuggestions, BatchGetSessions, GetSession, UpdateSession, ReplaceSession, UpdateSessionSettings, DeleteSession) | Unary | OK |
| device | DeviceService | 1 (Ping) | Unary | OK |
| live | LiveService | 1 (LiveSession) | Bidi streaming | OK |
| stats | StatsService | 1 (GetStats) | Unary | OK |
| sync | SyncService | 2 (GetChanges, WatchChanges) | Unary + server-streaming | OK |
| telemetry | TelemetryService | 1 (StreamTelemetry) | Bidi streaming | OK |
| users | UserService | 1 (UpdateProfile) | Unary | OK |

**Cross-file imports resolved correctly:**
- `users.pbgrpc.dart` imports `auth.pb.dart` for `UserDto` — correct
- `telemetry.pb.dart` imports `live.pb.dart` for `SessionErrorEvent` and `google/protobuf/struct.pb.dart` for `Struct` — correct

**File count:** 4 files per proto (`.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`, `.pbjson.dart`) x 8 protos = 32 files — correct.

**Not in `.gitignore`:** confirmed — generated files are tracked intentionally.

## Findings

### Low: Missing direct `fixnum` dependency

`flutter analyze` reports 3 info-level diagnostics:

```
info • The imported package 'fixnum' isn't a dependency of the importing package
  • lib/Core/Grpc/generated/live.pb.dart:15:8
  • lib/Core/Grpc/generated/sync.pb.dart:15:8
  • lib/Core/Grpc/generated/telemetry.pb.dart:15:8
```

`fixnum` is a transitive dependency via `protobuf`, so the code compiles and runs fine. But the analyzer flags it because it's not listed as a direct dependency in `pubspec.yaml`. Fix: `flutter pub add fixnum`.

Not blocking — this is an info-level lint, not an error. Can be addressed in the next milestone.

## Verdict

No bugs, no security issues, no correctness problems. Generated stubs match proto definitions exactly. One minor lint issue (missing direct `fixnum` dep) that does not affect runtime behavior.

REVIEW_PASS
