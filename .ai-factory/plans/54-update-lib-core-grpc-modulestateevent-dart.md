# Plan: Update `lib/Core/Grpc/ModuleStateEvent.dart`

## Context

Rename the field `liveSessionId` → `moduleSessionId` in `ModuleSessionStarted` and its constructor parameter, aligning the Dart event class with the renamed proto field (`module_session_id`).

> **Status: already implemented.** The file already uses `moduleSessionId` and a codebase-wide grep confirms zero remaining `liveSessionId` references in `lib/`. No tasks need to be executed.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename field

- [x] **Task 1: Rename `liveSessionId` → `moduleSessionId` in `ModuleSessionStarted`**
  Files: `lib/Core/Grpc/ModuleStateEvent.dart`
  Rename the field declaration (`final String? liveSessionId` → `final String? moduleSessionId`) and the constructor parameter (`{this.liveSessionId}` → `{this.moduleSessionId}`).
