# Meditation Post-Session Note Screen — UI and Coordinator Interface

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- No ViewModel needed for the note screen — a local `TextEditingController` is enough; the screen returns the typed text via `Navigator.pop(text)` and the coordinator decides what to do with it.
- `IMeditationSessionCoordinator` is new (doesn't exist yet); it lives in the package alongside the screen and carries a single `Future<void> onSessionStopped()` method.
- The session screen triggers the coordinator via `ref.listen` on status transition `active → idle`, called with `unawaited()` — the stop action is non-blocking.

## Details

### IMeditationSessionCoordinator

**File:** `packages/meditation_module/lib/src/MeditationSession/IMeditationSessionCoordinator.dart`

```dart
abstract class IMeditationSessionCoordinator {
  Future<void> onSessionStopped();
}

final meditationSessionCoordinatorProvider =
    Provider<IMeditationSessionCoordinator>((_) {
  throw UnimplementedError('must be overridden via ProviderScope');
});
```

### MeditationNoteScreen

**File:** `packages/meditation_module/lib/src/MeditationSession/MeditationNoteScreen.dart`

```dart
class MeditationNoteScreen extends StatefulWidget {
  const MeditationNoteScreen({super.key});

  @override
  State<MeditationNoteScreen> createState() => _MeditationNoteScreenState();
}

class _MeditationNoteScreenState extends State<MeditationNoteScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l10n.meditationNotePrompt,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_controller.text),
                    child: Text(AppLocalizations.of(context)!.ok),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Cancel → `pop(null)`, OK → `pop(text)`. Coordinator receives the result and decides whether to save.

### MeditationSessionScreen changes

**File:** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`

Add a `ref.listen` that fires on the `active → idle` transition:

```dart
ref.listen<MeditationSessionStatus>(
  meditationSessionViewModelProvider.select((s) => s.status),
  (previous, next) {
    if (previous == MeditationSessionStatus.active &&
        next == MeditationSessionStatus.idle) {
      unawaited(
        ref.read(meditationSessionCoordinatorProvider).onSessionStopped(),
      );
    }
  },
);
```

The stop button continues to call `vm.stop()` as before — no change to the button handler itself.

### Exports (add to barrel)

```dart
export 'src/MeditationSession/IMeditationSessionCoordinator.dart';
export 'src/MeditationSession/MeditationNoteScreen.dart';
```

### L10n keys needed

Reuse existing `cancel` and `ok` keys if they exist in `mind_l10n`. If not, add:
- `cancel` → EN: "Cancel" / RU: "Отмена"
- `ok` → EN: "OK" / RU: "ОК"

Add prompt key:
- `meditationNotePrompt` → EN: "Write what you felt during the session — how you felt at the start, and how it changed towards the end. This will help the AI better understand your body." / RU: "Запишите что чувствовали на протяжении сессии — что в начале, и как это изменилось к концу. Это поможет нейросети лучше понимать ваше тело."

### Scope boundary

This task ends after the exports above. The concrete `MeditationSessionCoordinator` in `lib/MeditationModule/MeditationSessionCoordinator.dart` is created in the wiring task (note 66), which runs after `IMeditationNoteService` exists. Implementing it here is impossible — the dependency doesn't exist yet.

## Open Questions

- Should the note screen have an AppBar with a title (e.g. "How was your session?")? Currently none — full-screen text field with just Cancel/OK at the bottom.
- Whether to reuse existing `cancel`/`ok` l10n keys or add meditation-specific ones (e.g. "Discard").
