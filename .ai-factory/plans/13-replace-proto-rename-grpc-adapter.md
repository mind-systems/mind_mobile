# Plan: Replace proto + rename gRPC adapter

## Context
Swap the meditation-notes proto contract for the renamed `module_session_notes` contract from the API source of truth, regenerate Dart stubs, and propagate the rename (and the removal of the obsolete `poseId` parameter) through the gRPC adapter, `GrpcClient`, `App` DI wiring, and the note sync path.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Proto contract + codegen

- [x] **Task 1: Replace the proto file**
  Files: `proto/meditation_notes.proto` (delete), `proto/module_session_notes.proto` (new)
  Delete `proto/meditation_notes.proto`. Copy `mind_api/proto/module_session_notes.proto` verbatim into `proto/module_session_notes.proto` (it is the source of truth — do not edit it). The new contract renames `MeditationNote` → `ModuleSessionNote`, `MeditationNotesService` → `ModuleSessionNotesService`, and uses `reserved 3` / `reserved "pose_id"` in `ModuleSessionNote` and `reserved 2` / `reserved "pose_id"` in `CreateNoteRequest` — so `note_text` stays at field 4 in `ModuleSessionNote` and field 3 in `CreateNoteRequest`. Never renumber the reserved gaps.

- [x] **Task 2: Regenerate Dart stubs** (depends on Task 1)
  Files: `lib/Core/Grpc/generated/*` (regenerated)
  Run `./scripts/gen_proto.sh`. The script does `rm -rf` on `lib/Core/Grpc/generated` before regenerating, so the old `meditation_notes.pb*.dart` files are removed automatically and the new `module_session_notes.pb*.dart` files are produced — no manual deletion of generated files is needed. Confirm `lib/Core/Grpc/generated/module_session_notes.pbgrpc.dart` exists afterward and that no `meditation_notes.*` files remain.

### Phase 2: Adapter + wiring rename

- [x] **Task 3: Rename the gRPC adapter class** (depends on Task 2)
  Files: `lib/MeditationModule/MeditationNotesGrpcApi.dart` (delete), `lib/MeditationModule/ModuleSessionNotesGrpcApi.dart` (new)
  Rename the file and the class `MeditationNotesGrpcApi` → `ModuleSessionNotesGrpcApi`. Change the import to `package:mind/Core/Grpc/generated/module_session_notes.pbgrpc.dart`. Change the client field type to `ModuleSessionNotesServiceClient`. In `createNote(...)`, remove the `required String poseId` parameter and remove `poseId: poseId` from the `CreateNoteRequest(...)` constructor — leave only `sessionId` and `noteText`.

- [x] **Task 4: Update GrpcClient** (depends on Task 3)
  Files: `lib/Core/Grpc/GrpcClient.dart`
  Change the import on line 10 to `package:mind/Core/Grpc/generated/module_session_notes.pbgrpc.dart`. Rename the late field (line 53) `meditationNotesService` → `moduleSessionNotesService` and its type `MeditationNotesServiceClient` → `ModuleSessionNotesServiceClient`.

- [x] **Task 5: Update App DI wiring** (depends on Task 3, Task 4)
  Files: `lib/Core/App.dart`
  Update the import (line ~59) `MeditationNotesGrpcApi.dart` → `ModuleSessionNotesGrpcApi.dart`. Rename the field (line ~114) `meditationNotesGrpcApi` → `moduleSessionNotesGrpcApi` with type `ModuleSessionNotesGrpcApi`. Update the wiring line (line ~272) to `shared.moduleSessionNotesGrpcApi = ModuleSessionNotesGrpcApi(grpcClient.moduleSessionNotesService)`.

- [x] **Task 6: Remove the poseId bridge from the note sync path** (depends on Task 3, Task 5)
  Files: `lib/MeditationModule/ModuleSessionNoteService.dart`
  In `_syncToServer`, change the call to `App.shared.moduleSessionNotesGrpcApi.createNote(...)` and remove the `poseId: ''` argument — pass only `sessionId` and `noteText`. Keep the existing `GrpcError` / `StatusCode.alreadyExists` handling unchanged.

## Commit Plan
- **Commit 1** (after tasks 1-6): "Replace meditation notes proto with module session notes and rename gRPC adapter"

> Single commit: the rename does not compile until all references are updated, so there is no safe intermediate checkpoint.
