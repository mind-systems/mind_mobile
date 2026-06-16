# Plan: Session timer on MeditationSessionScreen

## Context
Add an elapsed-time display to the meditation session screen that counts up while a session is active and resets on each start, without triggering per-second Riverpod rebuilds.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Timer state in the ViewModel

- [x] **Task 1: Add elapsed-seconds timer to `MeditationSessionViewModel`**
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  Add `final ValueNotifier<int> elapsedSeconds = ValueNotifier(0);` and `Timer? _timer;` fields (the file already imports `dart:async`; add `import 'package:flutter/foundation.dart';` for `ValueNotifier`).
  In `start()`: reset `elapsedSeconds.value = 0`, start `_timer = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++)`, then set `state = state.copyWith(status: MeditationSessionStatus.active)`. Convert the current single-expression `start()` into a block body.
  In `stop()`: call `_timer?.cancel()`, set `_timer = null`, then set `state = state.copyWith(status: MeditationSessionStatus.idle)`. Convert the current single-expression `stop()` into a block body.
  Extend the existing `ref.onDispose` callback in `build()` so it also calls `_timer?.cancel()` and `elapsedSeconds.dispose()` alongside the current `_stateController.close()`.

### Phase 2: Timer display on the screen

- [x] **Task 2: Render the timer at the bottom of `MeditationSessionScreen`** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`
  Wrap the existing body in an outer `Column` so the pose image + `ControlButton` stay centered and the timer is anchored at the bottom:
  - `Expanded(child: Center(child: <existing Column with pose image, SizedBox(height:40), ControlButton>))`
  - `Padding(padding: const EdgeInsets.only(bottom: 40), child: ValueListenableBuilder<int>(...))`
  The `ValueListenableBuilder<int>` uses `valueListenable: ref.read(meditationSessionViewModelProvider.notifier).elapsedSeconds` (use `ref.read`, not `ref.watch`, so the `ValueListenable` drives updates with no Riverpod rebuild per tick). Its builder renders `Text(_formatDuration(seconds), style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AppColors.warmAccentDark, fontFeatures: [const FontFeature.tabularFigures()]))`.
  `AppColors` comes from the already-imported `package:mind_ui/mind_ui.dart`; `FontFeature` comes from `dart:ui` (add `import 'dart:ui' show FontFeature;` if not already resolvable via the material import).
  Add a private top-level helper `String _formatDuration(int totalSeconds)` that formats `HH:MM:SS` with zero-padding (`h ~/ 3600`, `(s % 3600) ~/ 60`, `s % 60`, each `padLeft(2, '0')`).
