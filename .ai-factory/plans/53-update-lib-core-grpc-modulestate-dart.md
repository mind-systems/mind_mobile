# Plan: Update `lib/Core/Grpc/ModuleState.dart`

## Context

Rename the field `liveSessionId` → `moduleSessionId` in `ModuleState`, its constructor, factory, and all call sites in `ModuleStateChannel` and `ModuleStateEvent` — aligning the Dart domain model with the renamed proto field (`module_session_id`).

> **Status: already implemented.** A codebase-wide grep confirms zero remaining `liveSessionId` references in `lib/`. All tasks below are complete.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename field in model classes

- [x] **Task 1: Rename field in `ModuleState`**
  Files: `lib/Core/Grpc/ModuleState.dart`
  Rename `liveSessionId` → `moduleSessionId` in three places: the field declaration (line 4), the required constructor parameter (line 8), and the `ModuleState.initial()` factory (line 11 — `liveSessionId: null` → `moduleSessionId: null`).

- [x] **Task 2: Rename field in `ModuleSessionStarted`**
  Files: `lib/Core/Grpc/ModuleStateEvent.dart`
  Rename `liveSessionId` → `moduleSessionId` in the field declaration (line 4) and the constructor parameter (line 5).

### Phase 2: Update call sites

- [x] **Task 3: Update `ModuleStateChannel._processProtoEvent`**
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  Replace `event.liveSessionId` → `event.moduleSessionId` (the proto accessor). Update the local variable name and the named arguments in the `ModuleState(...)` and `ModuleSessionStarted(...)` constructor calls to use `moduleSessionId:`.
