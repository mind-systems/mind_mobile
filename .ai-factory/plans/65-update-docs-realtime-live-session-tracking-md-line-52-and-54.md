# Plan: Update docs/realtime/live-session-tracking.md references (lines 54 and 56)

## Context
Rename three stale symbol references in the live-session-tracking doc to match the renamed code after milestone 10.2.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename references

- [x] **Task 1: Replace stale symbol names in docs**
  Files: `docs/realtime/live-session-tracking.md`
  On line 54, replace `_handleTelemetry` with `_handleInstruction`.
  On line 54, replace `liveId` with `sessionId` (in the `sendSample(liveId, phase, durationMs)` call description).
  On line 56, replace `_pendingTelemetry` with `_pendingInstruction`.
