# Plan: Wire gRPC note sync — MeditationNotesGrpcApi + service update + buildSession

## Context
Add server-side sync for meditation notes: a thin gRPC API wrapper, DI registration, and a fire-and-forget `CreateNote` call from `MeditationNoteService.saveNote` after the local Drift save, gated on an available `sessionId`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Notes for implementer
Reconnaissance shows part of this milestone is already in place — implement only what is missing and verify the rest:
- `MeditationSessionCoordinator` already declares `final String? Function() getSessionId` and calls `noteService.saveNote(trimmed, sessionId: getSessionId())`. No change needed — verify only.
- `MeditationModule.buildSession()` already passes `getSessionId: () => stateChannel.moduleSessionId` (lazy closure over `stateChannel.moduleSessionId`). No change needed — verify only.
- `GrpcClient` already exposes `meditationNotesService` (a `MeditationNotesServiceClient`). Generated stubs (`CreateNoteRequest { sessionId, poseId, noteText }`, `MeditationNotesServiceClient.createNote`) already exist.
- `MeditationNoteService` already resolves the slug → UUID via `App.shared.meditationPoseUuids[_poseSlug] ?? _poseSlug` and saves locally via `_repository.save(...)`. Only the gRPC fire-and-forget step is missing.

Pattern reference for gRPC error handling: `lib/User/AuthApi.dart` uses `} on GrpcError catch (e) { if (e.code == StatusCode.<x>) ... }` with imports from `package:grpc/grpc.dart`. `ALREADY_EXISTS` maps to `StatusCode.alreadyExists`.

## Tasks

### Phase 1: gRPC API wrapper

- [x] **Task 1: Create `MeditationNotesGrpcApi`**
  Files: `lib/MeditationModule/MeditationNotesGrpcApi.dart`
  Create a thin wrapper around `MeditationNotesServiceClient`, following the style of `lib/MeditationModule/MeditationPosesGrpcApi.dart`. Constructor takes the client: `MeditationNotesGrpcApi(this._client)`. Add a method:
  ```dart
  Future<void> createNote({
    required String sessionId,
    required String poseId,   // UUID
    required String noteText,
  }) async {
    await _client.createNote(CreateNoteRequest(
      sessionId: sessionId,
      poseId: poseId,
      noteText: noteText,
    ));
  }
  ```
  Import `package:mind/Core/Grpc/generated/meditation_notes.pbgrpc.dart` (it re-exports `meditation_notes.pb.dart`, so `CreateNoteRequest` is available). Do not catch errors here — error handling lives in the service (Task 3).

### Phase 2: DI wiring

- [x] **Task 2: Register `meditationNotesGrpcApi` in `App`** (depends on Task 1)
  Files: `lib/Core/App.dart`
  Add the field next to the existing `meditationPosesApi` declaration: `late final MeditationNotesGrpcApi meditationNotesGrpcApi;`. In the initializer (alongside `shared.meditationPosesApi = MeditationPosesGrpcApi(grpcClient.meditationPosesService);`), add `shared.meditationNotesGrpcApi = MeditationNotesGrpcApi(grpcClient.meditationNotesService);`. Add the import for `package:mind/MeditationModule/MeditationNotesGrpcApi.dart`. Follow the existing no-trailing-comma convention for single-line initializer calls inside `initialize()`.

### Phase 3: Service sync

- [x] **Task 3: Fire-and-forget server sync in `MeditationNoteService.saveNote`** (depends on Task 2)
  Files: `lib/MeditationModule/MeditationNoteService.dart`
  After the existing local `await _repository.save(poseId, text, serverSessionId: sessionId);`, add a fire-and-forget server sync that runs only when `sessionId != null`:
  ```dart
  if (sessionId != null) {
    unawaited(_syncToServer(sessionId, poseId, text.trim()));
  }
  ```
  Implement a private helper that calls `App.shared.meditationNotesGrpcApi.createNote(sessionId: sessionId, poseId: poseId, noteText: noteText)` inside a `try`. Catch errors so a failed sync never surfaces to the caller (this is fire-and-forget): use `} on GrpcError catch (e) { if (e.code == StatusCode.alreadyExists) return; /* minimal log, non-fatal */ }` and a trailing `} catch (_) { /* minimal log, non-fatal */ }`. `ALREADY_EXISTS` must be treated as a benign no-op. Add imports: `dart:async` (for `unawaited`) and `package:grpc/grpc.dart` (for `GrpcError` / `StatusCode`). Reuse the resolved UUID `poseId` variable already computed at the top of `saveNote`.

- [x] **Task 4: Verify already-wired pieces** (depends on Task 3)
  Files: `lib/MeditationModule/MeditationSessionCoordinator.dart`, `lib/MeditationModule/MeditationModule.dart`
  Confirm (no edit expected) that `MeditationSessionCoordinator` exposes `getSessionId` and forwards it into `saveNote`, and that `buildSession()` passes `getSessionId: () => stateChannel.moduleSessionId`. If either is missing, add it per the milestone description. Run `flutter analyze` to confirm the new imports and API compile cleanly.
