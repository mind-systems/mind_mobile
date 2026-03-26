# Review: 20 — Delete DeviceApi.dart

## Scope

Two staged files:
- `.ai-factory/ROADMAP.md` — checkbox flip from `[ ]` to `[x]` on milestone 2.9 "Delete DeviceApi.dart"
- `.ai-factory/plans/20-delete-deviceapi-dart.md` — new plan file (all tasks marked complete)

## Verification

| Check | Result |
|-------|--------|
| `lib/Core/Api/DeviceApi.dart` exists on disk | No — already deleted in plan 19 |
| Any `DeviceApi` import/reference in `lib/` | None (`grep` confirms zero matches) |
| `DeviceGrpcApi` wired correctly in `App.dart` (line 134) | Yes — `DeviceGrpcApi(grpcClient.deviceService)` |
| `DeviceRepository` uses `DeviceGrpcApi` type | Yes — constructor and field typed as `DeviceGrpcApi` |
| `DeviceRepository.ping()` call site unchanged (line 135) | Yes — fire-and-forget via `unawaited(...)` |
| Roadmap diff is a single-line checkbox change | Yes — only line 54 changed |

## Issues

None found. The deletion was already performed in plan 19; this changeset only updates the roadmap checkbox and adds the plan file. No runtime-affecting code changes.

REVIEW_PASS
