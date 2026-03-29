# Plan: Update BreathModuleStateChannel — rename liveSessionId to moduleSessionId

## Context
Rename all `liveSessionId` / `_liveSessionId` / `liveId` references in `BreathModuleStateChannel.dart` to use the `moduleSessionId` naming that was adopted in the upstream `ModuleState` and `ModuleStateEvent` classes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename

- [x] **Task 1: Rename private field and getter**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  Rename the private field `_liveSessionId` to `_moduleSessionId`. Rename its public getter from `liveSessionId` to `moduleSessionId`. Update the `reset()` method which nulls `_liveSessionId` to use `_moduleSessionId`.

- [x] **Task 2: Update `_channelSub` listener**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In the constructor's `_channelSub` listener, change `moduleState.liveSessionId` to `moduleState.moduleSessionId` (aligning with the already-renamed field in `ModuleState`).

- [x] **Task 3: Update `_handleTelemetry` and `_flushPending` call sites**
  Files: `lib/BreathModule/Core/BreathModuleStateChannel.dart`
  In `_handleTelemetry`, rename the local variable `liveId` (which reads from `_liveSessionId`) to `sessionId` (reading from `_moduleSessionId`). In `_flushPending`, update its parameter or local reference if it was derived from `liveId`. Ensure `_instructionStream.sendSample(...)` receives the correctly named variable.
