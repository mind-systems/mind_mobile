# Review: Rename `TelemetryBuffer` → `InstructionBuffer`

Plan: `.ai-factory/plans/43-rename-telemetrybuffer-instructionbuffer.md`

## Changed files

| File | Status |
|------|--------|
| `lib/Core/Grpc/TelemetryBuffer.dart` | Deleted — OK |
| `test/Core/Grpc/telemetry_buffer_test.dart` → `test/Core/Grpc/instruction_buffer_test.dart` | Renamed — OK |
| `docs/core/testing.md` | Modified — OK |
| `docs/socket/live-session-tracking.md` | Modified — OK |
| `.ai-factory/plans/43-rename-telemetrybuffer-instructionbuffer.md` | New — OK |

## Verification

- **No remaining `TelemetryBuffer` references in source code.** Grep across `lib/`, `test/`, `packages/` returns zero matches.
- **`InstructionBuffer.dart` exists and is identical in logic** to the deleted `TelemetryBuffer.dart` (class name updated, everything else the same).
- **Test import path is correct.** `instruction_buffer_test.dart` imports `package:mind/Core/Grpc/InstructionBuffer.dart`.
- **All 7 tests pass** (`flutter test test/Core/Grpc/instruction_buffer_test.dart` — 7/7).
- **Doc changes are minimal and correct.** Only the class name was changed in each doc; surrounding text (including Russian language in `live-session-tracking.md`) is preserved.

## Remaining `TelemetryBuffer` references (non-source)

Historical `.ai-factory/` files (plans 30, 42; reviews 30, 42; notes 01) and `ROADMAP.md` line 136 still mention `TelemetryBuffer`. These are records of past work and the milestone definition — correct to leave as-is.

## Issues found

None.

REVIEW_PASS
