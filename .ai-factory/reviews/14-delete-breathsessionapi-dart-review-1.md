# Review: Delete BreathSessionApi.dart

## Changes reviewed

| File | Change |
|------|--------|
| `lib/Core/Api/BreathSessionApi.dart` | Deleted (47 lines) |
| `.ai-factory/plans/14-delete-breathsessionapi-dart.md` | New plan file |

## Verification

### No dangling imports

Grep for `BreathSessionApi` across `lib/` and `test/` confirms zero references to the deleted concrete class. All remaining matches reference either:
- `IBreathSessionApi` (the interface) — used by `BreathSessionGrpcApi`, `BreathSessionRepository`, and the test fake
- `BreathSessionGrpcApi` (the replacement) — wired in `App.dart:131`
- `FakeBreathSessionApi` (test double) — implements the interface directly

### DI wiring is correct

`App.dart:131` constructs `BreathSessionGrpcApi(grpcClient.breathSessionService)` and passes it to `BreathSessionRepository` at line 138 via the `IBreathSessionApi` interface. The deleted class was not instantiated anywhere.

### Shared DTOs unaffected

`SaveBreathSessionRequest` and `StarSessionRequest` (in `lib/Core/Api/Models/`) are still imported by `BreathSessionGrpcApi`, `BreathSessionRepository`, `IBreathSessionApi`, and the test fake. No orphaned files.

### No runtime risk

The deleted file was dead code — not imported, not instantiated, not referenced by any route, DI, or test. Deletion cannot cause a runtime regression.

## Issues found

None.

REVIEW_PASS
