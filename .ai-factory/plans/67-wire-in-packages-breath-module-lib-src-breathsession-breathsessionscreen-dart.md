# Plan: Wire BreathSoundCoordinator into BreathSessionScreen

## Context
Connect the existing `BreathSoundCoordinator` to `BreathSessionScreen` so that audio cues track the session lifecycle (initialize, dispose, restart) alongside the existing animation/orb coordinators.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Integration

- [x] **Task 1: Wire BreathSoundCoordinator into BreathSessionScreen**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Apply the following edits, preserving existing style (no trailing commas added beyond what already exists, comments may remain in original language):
  1. Add import alongside the existing Animation imports (after line 11 `import 'Animation/OrbAnimationCoordinator.dart';`):
     ```dart
     import 'Audio/BreathSoundCoordinator.dart';
     ```
  2. In `_BreathSessionScreenState` (after `late final OrbAnimationCoordinator _orbCoordinator;` at line 35), declare:
     ```dart
     late final BreathSoundCoordinator _soundCoordinator;
     ```
  3. In `initState()` immediately after the line `_orbCoordinator = OrbAnimationCoordinator(viewModel: viewModel, vsync: this);` (line 61), add:
     ```dart
     _soundCoordinator = BreathSoundCoordinator(viewModel: viewModel);
     ```
  4. Inside the existing `WidgetsBinding.instance.addPostFrameCallback` block, after `_orbCoordinator.initialize(initialState);` (line 69) and **before** `viewModel.initState();` (line 72), add:
     ```dart
     _soundCoordinator.initialize(initialState);
     ```
  5. In `dispose()` after `_orbCoordinator.dispose();` (line 95), add:
     ```dart
     _soundCoordinator.dispose();
     ```
  6. In `_buildControlButton` inside the restart button's `onPressed` callback (around lines 251-253), after `_orbCoordinator.reset();` add:
     ```dart
     _soundCoordinator.reset();
     ```

  Verification: run `/usr/local/bin/flutter analyze packages/breath_module` to confirm no analyzer errors after the changes.
