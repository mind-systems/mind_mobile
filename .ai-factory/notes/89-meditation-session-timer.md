# Session Timer on MeditationSessionScreen

**Date:** 2026-06-03
**Source:** conversation context

## Key Findings

- `MeditationSessionViewModel` gets a `ValueNotifier<int> elapsedSeconds` driven by `Timer.periodic(1s)` — resets to 0 on `start()`, cancelled on `stop()`.
- Screen uses `ValueListenableBuilder<int>` to display `HH:MM:SS` — no Riverpod state emissions per second, no full-screen rebuilds on each tick.
- Color: `AppColors.warmAccentDark` (gold) — same token used for the orb on `BreathSessionScreen`.
- Position: anchored at the bottom of the screen body, below the pose image + ControlButton.

## Details

### `MeditationSessionViewModel` (`packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`)

```dart
final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);
Timer? _timer;

@override
void start() {
  elapsedSeconds.value = 0;
  _timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++);
  state = state.copyWith(status: MeditationSessionStatus.active);
}

@override
void stop() {
  _timer?.cancel();
  _timer = null;
  state = state.copyWith(status: MeditationSessionStatus.idle);
}
```

In `build()`, extend the existing `ref.onDispose` block:
```dart
ref.onDispose(() {
  _timer?.cancel();
  elapsedSeconds.dispose();
});
```

### `MeditationSessionScreen` layout

Access via `ref.read(meditationSessionViewModelProvider.notifier).elapsedSeconds` — `ref.read`, not `ref.watch`, so Riverpod doesn't own the update cycle.

Wrap the existing body `Column` in an outer `Column` that pushes the timer to the bottom:

```dart
Column(
  children: [
    Expanded(
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // existing: pose image, SizedBox(h:40), ControlButton
        ]),
      ),
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: ValueListenableBuilder<int>(
        valueListenable:
            ref.read(meditationSessionViewModelProvider.notifier).elapsedSeconds,
        builder: (context, seconds, _) => Text(
          _formatDuration(seconds),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: AppColors.warmAccentDark,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  ],
)
```

Helper function (top-level or private):
```dart
String _formatDuration(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}
```

`AppColors` is in `packages/mind_ui/lib/src/AppTheme.dart` — already a dep of `meditation_module`.
