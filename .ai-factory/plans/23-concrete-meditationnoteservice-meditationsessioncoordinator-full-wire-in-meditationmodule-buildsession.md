# Plan: Concrete `MeditationNoteService` + `MeditationSessionCoordinator` + full wire in `MeditationModule.buildSession()`

## Context
Wire up persistence of the post-session meditation note: a service that resolves the pose slug → UUID and delegates to the existing `MeditationNoteRepository`, plus a coordinator that pushes `MeditationNoteScreen` on session stop and saves non-empty notes. The note screen, Drift table, repository, and coordinator interface already exist — only the concrete service and the real coordinator body are missing.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Note service

- [x] **Task 1: Add `IMeditationNoteService` interface**
  Files: `lib/MeditationModule/IMeditationNoteService.dart`
  Declare a minimal abstract interface for the note service so the coordinator depends on a contract, not the concrete class:
  ```dart
  abstract class IMeditationNoteService {
    Future<void> saveNote(String text, {String? sessionId});
  }
  ```
  Pure Dart, no Flutter/Riverpod imports.

- [x] **Task 2: Implement `MeditationNoteService`** (depends on Task 1)
  Files: `lib/MeditationModule/MeditationNoteService.dart`
  Concrete service implementing `IMeditationNoteService`. Constructor takes the pose **slug** and the repository: `MeditationNoteService(String poseSlug, MeditationNoteRepository repository)`. Keep both as private fields.
  `saveNote` resolves slug → UUID and delegates (per spec `.ai-factory/notes/88-meditation-notes-pose-id-rename.md`):
  ```dart
  Future<void> saveNote(String text, {String? sessionId}) async {
    final poseId = App.shared.meditationPoseUuids[poseSlug] ?? poseSlug;
    await _repository.save(poseId, text, serverSessionId: sessionId);
  }
  ```
  Import `App` from `package:mind/Core/App.dart` and `MeditationNoteRepository` from `package:mind/MeditationModule/MeditationNoteRepository.dart`. The existing `MeditationNoteRepository.save(poseId, text, {serverSessionId})` is the delegation target — do not change its signature.

### Phase 2: Coordinator

- [x] **Task 3: Implement `MeditationSessionCoordinator.onSessionStopped`** (depends on Task 2)
  Files: `lib/MeditationModule/MeditationSessionCoordinator.dart`
  Replace the placeholder body. The screen calls `onSessionStopped()` with no arguments (`MeditationSessionScreen` build → `ref.listen` on status `active → idle`), so the coordinator must already hold the note service and a way to obtain the current server session id. Update the constructor to:
  ```dart
  MeditationSessionCoordinator(
    this.context, {
    required this.noteService,
    required this.getSessionId,
  });

  final BuildContext context;
  final IMeditationNoteService noteService;
  final String? Function() getSessionId;
  ```
  Implement `onSessionStopped`:
  - Guard `if (!context.mounted) return;` before navigating (the placeholder review flagged the captured route-builder `context` — add the guard).
  - `final text = await Navigator.of(context).push<String?>(MaterialPageRoute(builder: (_) => const MeditationNoteScreen()));`
  - On return: `final trimmed = text?.trim() ?? '';` — if empty (Cancel returns `null`, empty OK returns `''`), do nothing.
  - Otherwise fire-and-forget: `unawaited(noteService.saveNote(trimmed, sessionId: getSessionId()));`
  Imports: `dart:async` (for `unawaited`), `package:flutter/material.dart` (for `MaterialPageRoute`/`Navigator`), `MeditationNoteScreen` + `IMeditationSessionCoordinator` from `package:meditation_module/meditation_module.dart`, and `IMeditationNoteService` from `package:mind/MeditationModule/IMeditationNoteService.dart`. Confirm `MeditationNoteScreen` is exported by `meditation_module.dart`; if not, import it via the package's `src` path consistent with how the screen is referenced elsewhere.

### Phase 3: Wiring

- [x] **Task 4: Wire service + coordinator in `MeditationModule.buildSession()`** (depends on Task 3)
  Files: `lib/MeditationModule/MeditationModule.dart`
  Inside `buildSession(context, {required poseId})`:
  - Create the service from the slug and the app-level repository: `final noteService = MeditationNoteService(poseId, App.shared.meditationNoteRepository);` (`poseId` here is the slug, consistent with how it is passed to `MeditationSessionViewModel` and used for the asset path).
  - Build the coordinator, passing a session-id getter that reads from the lazily-created `stateChannel`:
    ```dart
    final coordinator = MeditationSessionCoordinator(
      context,
      noteService: noteService,
      getSessionId: () => stateChannel.moduleSessionId,
    );
    ```
    `stateChannel` is the existing `late final MeditationModuleStateChannel` assigned inside the `meditationSessionViewModelProvider` override; the closure resolves it at stop time (after the VM is built), so capturing it before assignment is safe. `MeditationModuleStateChannel` already exposes `String? get moduleSessionId`.
  - Replace the inline `meditationSessionCoordinatorProvider.overrideWithValue(MeditationSessionCoordinator(context))` with `meditationSessionCoordinatorProvider.overrideWithValue(coordinator)`.
  - Add the import for `MeditationNoteService`. `App` is already imported.

  Verify manually: stop session → note screen appears → type text → OK ⇒ one new row in `meditation_notes` (poseId = resolved UUID, serverSessionId = current module session id). Cancel, or OK with empty/whitespace text ⇒ no row written.
