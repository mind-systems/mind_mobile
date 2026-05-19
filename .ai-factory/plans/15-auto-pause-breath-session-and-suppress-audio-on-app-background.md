# Plan: Auto-pause breath session and suppress audio on app background

## Context
When the app goes to background during an active breath session, the session timer keeps running and the tick sound keeps playing. Wire `_BreathSessionScreenState` into the Flutter lifecycle so it suspends tick audio and pauses the session on `AppLifecycleState.paused`, and re-arms tick audio on `AppLifecycleState.resumed` (the user resumes the session manually). This task consumes the `suspend()` / `resume()` API added to `BreathSoundCoordinator` by plan 14.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Wire lifecycle observer

- [x] **Task 1: Add `WidgetsBindingObserver` to `_BreathSessionScreenState` mixin list**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Change the class declaration on line 33 from:
  ```dart
  class _BreathSessionScreenState extends ConsumerState<BreathSessionScreen> with TickerProviderStateMixin {
  ```
  to:
  ```dart
  class _BreathSessionScreenState extends ConsumerState<BreathSessionScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  ```
  `WidgetsBindingObserver` is exported by `package:flutter/material.dart` (already imported at line 1), so no new import is required.

- [x] **Task 2: Register and unregister the observer in `initState()` / `dispose()`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  In `initState()` (line 45), immediately after `super.initState();` (line 46) add:
  ```dart
  WidgetsBinding.instance.addObserver(this);
  ```
  In `dispose()` (line 97), insert before `super.dispose();` (line 105):
  ```dart
  WidgetsBinding.instance.removeObserver(this);
  ```
  Keep the order: `removeObserver` runs before the existing `super.dispose()` call but after all the coordinator/controller `.dispose()` calls already in the method (the observer must outlive any callbacks the coordinators could schedule synchronously during their own disposal).

### Phase 2: Handle lifecycle transitions

- [x] **Task 3: Override `didChangeAppLifecycleState` to suspend audio and pause active session on background** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Add a new override method to `_BreathSessionScreenState`. Place it after `dispose()` (after line 106) and before `_scrollToActive` (currently line 108), so lifecycle methods stay grouped at the top of the class. Implementation:
  ```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _soundCoordinator.suspend();
      final status = ref.read(breathViewModelProvider).status;
      if (status == BreathSessionStatus.breath || status == BreathSessionStatus.rest) {
        ref.read(breathViewModelProvider.notifier).pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      _soundCoordinator.resume();
    }
  }
  ```
  Behavior notes (do not deviate):
  - On `paused`: call `_soundCoordinator.suspend()` first (immediately mutes the tick channel via the API added in plan 14), then check current session status and only call `viewModel.pause()` if the session is actively running (`breath` or `rest`). Skipping `pause` / `complete` avoids redundant state churn and avoids re-triggering the paused branch when the user has already paused manually.
  - The call to `viewModel.pause()` propagates through `_onStateChanged` inside `BreathAnimationCoordinator` / `BreathSoundCoordinator`, which handles the existing `BreathSessionStatus.pause` branch and fades out the loop audio over 200ms — no extra audio plumbing is required here.
  - On `resumed`: call `_soundCoordinator.resume()` only. Do NOT call `viewModel.resume()` — the session stays paused until the user taps the play button. This matches platform UX expectations for breath/meditation sessions.
  - Ignore `AppLifecycleState.inactive` and `AppLifecycleState.detached`: `inactive` fires for transient interruptions (notification pulldown, Control Center, incoming-call peek) and must not pause the session; `detached` is irrelevant because `dispose()` will run.
  - `BreathSessionStatus` is already imported via `Models/BreathSessionState.dart` (line 6).

## Commit Plan

Single commit at the end (3 tightly-coupled tasks editing the same file).
