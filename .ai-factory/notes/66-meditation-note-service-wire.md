# Meditation Note Service — Concrete Implementation and Wiring

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `IMeditationNoteService` lives in `lib/MeditationModule/` (not in the package) — the package's note screen receives a result via `Navigator.pop` and the coordinator calls the service; the package has zero knowledge of the service interface.
- `MeditationModule.buildSession()` creates the coordinator and note service with `poseName` baked in; both are wired via `ProviderScope` overrides.
- Callers of `saveNote()` use `unawaited()` — the save is fully fire-and-forget.

## Details

### IMeditationNoteService

**File:** `lib/MeditationModule/IMeditationNoteService.dart`

```dart
abstract class IMeditationNoteService {
  Future<void> saveNote(String text, {String? sessionId});
}
```

Lives in `lib/`, not in the package. The package coordinator interface (`IMeditationSessionCoordinator`) has no reference to it.

### MeditationNoteService

**File:** `lib/MeditationModule/MeditationNoteService.dart`

```dart
class MeditationNoteService implements IMeditationNoteService {
  final String _poseName;
  final MeditationNoteRepository _repository;

  MeditationNoteService(this._poseName, this._repository);

  @override
  Future<void> saveNote(String text, {String? sessionId}) =>
      _repository.save(_poseName, text, serverSessionId: sessionId);
}
```

`poseName` is baked in at session-creation time — the service doesn't need to know which pose at call time.

### MeditationSessionCoordinator

**File:** `lib/MeditationModule/MeditationSessionCoordinator.dart`

```dart
class MeditationSessionCoordinator implements IMeditationSessionCoordinator {
  final BuildContext context;
  final IMeditationNoteService noteService;

  MeditationSessionCoordinator(this.context, this.noteService);

  @override
  Future<void> onSessionStopped() async {
    final text = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const MeditationNoteScreen()),
    );
    if (text != null && text.trim().isNotEmpty) {
      unawaited(noteService.saveNote(text.trim()));
    }
  }
}
```

### MeditationModule.buildSession() wiring

**File:** `lib/MeditationModule/MeditationModule.dart`

```dart
static Widget buildSession(BuildContext context, {required String poseName}) {
  final noteService = MeditationNoteService(
    poseName,
    App.shared.meditationNoteRepository,
  );
  final coordinator = MeditationSessionCoordinator(context, noteService);

  late final MeditationModuleStateChannel stateChannel;

  return ProviderScope(
    overrides: [
      meditationSessionViewModelProvider.overrideWith((_) {
        final vm = MeditationSessionViewModel().._poseName = poseName;
        stateChannel = MeditationModuleStateChannel(
          channel: App.shared.moduleStateChannel,
          stateStream: vm.stream,
          poseName: poseName,
        );
        return vm;
      }),
      meditationSessionCoordinatorProvider.overrideWithValue(coordinator),
    ],
    child: MeditationSessionScreen(
      onDispose: () => stateChannel.dispose(),
    ),
  );
}
```

### App.dart

Field already added in note 65. No additional changes in `App.dart` needed here.

### Verify

1. Open a meditation session, press Stop.
2. Note screen appears.
3. Type text, press OK → screen pops back to idle session screen.
4. Check Drift DB: a row with the typed text and correct `poseName` is present.
5. Press Cancel → screen pops, no row inserted.
6. Empty text + OK → no row inserted (trimmed text is empty).
