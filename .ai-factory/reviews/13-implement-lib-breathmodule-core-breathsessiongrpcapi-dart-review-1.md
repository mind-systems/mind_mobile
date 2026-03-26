# Review: BreathSessionGrpcApi

## Files reviewed

- `lib/BreathModule/Core/BreathSessionGrpcApi.dart` (new — 119 lines)
- `lib/Core/App.dart` (import swap + 1-line wiring change)

## RPC signature verification

All 6 interface methods map correctly to the generated `BreathSessionServiceClient` stubs:

| Method | Stub called | Stub return type | Mapping | Verdict |
|---|---|---|---|---|
| `create` | `createSession` | `BreathSessionDto` | `_mapSession` | OK |
| `update` | `replaceSession` | `BreathSessionDto` | `_mapSession` | OK |
| `delete` | `deleteSession` | `DeleteSessionResponse` | discarded | OK |
| `fetchById` | `getSession` | `BreathSessionWithStarredDto` | `_mapSessionWithStarred` | OK |
| `fetchAll` | `listSessions` | `ListSessionsResponse` | `_mapSessionWithStarred` per item | OK |
| `starSession` | `updateSessionSettings` | `UpdateSessionSettingsResponse` | discarded | OK |

## Type mapping audit

**Proto to domain (response path):**
- `proto.StepType.INHALE/EXHALE/HOLD` to `StepType.inhale/exhale/hold` — all 3 values handled, default falls to `inhale` (matches proto default 0). Correct.
- `StepDto.duration` (`double`) to `ExerciseStep.duration` (`int`) via `.round()`. Correct.
- `ExerciseDto.restDuration` (`double`) to `ExerciseSet.restDuration` (`int`) via `.round()`. Correct.
- `ExerciseDto.repeatCount` (`int32`) to `ExerciseSet.repeatCount` (`int`). Direct. Correct.
- `BreathSessionDto.complexity` (`double`) to `BreathSession.complexity` (`double`). Direct. Correct.
- `BreathSessionDto.createdAt` (`string`) to `DateTime` via `DateTime.parse(...)`. Correct.
- `BreathSessionWithStarredDto` unwrapped via `dto.session` + `dto.isStarred`. Correct.

**Domain to proto (request path):**
- `StepType` reverse mapping — exhaustive Dart `switch` expression on sealed enum. Correct.
- `ExerciseStep.duration` (`int`) to `.toDouble()`. Correct.
- `ExerciseSet.restDuration` (`int`) to `.toDouble()`. Correct.
- `ExerciseSet.repeatCount` (`int`) passed directly. Correct.

## Wiring (App.dart)

Line 131 swaps `BreathSessionApi(httpClient)` for `BreathSessionGrpcApi(grpcClient.breathSessionService)`. The variable name and downstream usage (`BreathSessionRepository(dao:, api: breathSessionApi)` on line 138) are unchanged. Import updated correctly. `GrpcClient.breathSessionService` confirmed as `BreathSessionServiceClient` (GrpcClient.dart:31).

## Pattern consistency

Follows the established `AuthGrpcApi` pattern: `as proto` import alias, constructor takes service client, no try/catch (interceptor handles errors), private mapping helpers.

## Dead code

`lib/Core/Api/BreathSessionApi.dart` (REST implementation) is now unreferenced — no file imports it after the `App.dart` change. It can be deleted in a follow-up but is harmless.

## Issues found

None.

## Observations (non-blocking)

- `DateTime.parse(dto.createdAt)` throws `FormatException` on empty string (proto3 default for unset strings). This is consistent with the REST implementation (`DateTime.parse(json['createdAt'] as String)`) and acceptable — the server always populates `createdAt`.
- `_mapSessionWithStarred` accesses `dto.session` without a `hasSession()` guard. In proto3, accessing an unset message field returns a default (empty) instance rather than null, so this won't crash — but could produce a `BreathSession` with empty fields if the server sends a malformed response. Same trust boundary as the REST path.

REVIEW_PASS
