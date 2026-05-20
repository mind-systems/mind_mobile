# Plan: Expose `remainingTicksNotifier: ValueListenable<int>` on `BreathViewModel`

## Context
Add an additive, sibling per-tick channel on `BreathViewModel` so a future `_TimelineItem`-scoped `ValueListenableBuilder` can subscribe to the 1 Hz countdown without forcing a screen rebuild. This milestone introduces the API only — no consumers, no removal of `remainingTicks` from `BreathSessionState`. Background and rationale: `.ai-factory/notes/11-breath-session-tick-render-scope.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Add `remainingTicksNotifier` to `BreathViewModel`

- [x] **Task 1: Import `flutter/foundation.dart` for `ValueNotifier` / `ValueListenable`**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  At the top of the file, add `import 'package:flutter/foundation.dart';` alongside the existing imports. This brings `ValueNotifier<int>` and `ValueListenable<int>` into scope. Keep the existing imports order; place the Flutter foundation import after the `dart:async` import and before the `flutter_riverpod` import (alphabetical-ish — match the surrounding style if neighboring files differ).

- [x] **Task 2: Declare the private `ValueNotifier<int>` field and public `ValueListenable<int>` getter** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Inside the `BreathViewModel` class, alongside the other private fields (e.g. near `_sessionDTO` and `_stateController`), add:
  ```dart
  final ValueNotifier<int> _remainingTicks = ValueNotifier<int>(0);

  /// Per-tick countdown channel for narrow-scope UI consumers (e.g. the active
  /// timeline row). Sibling to `BreathSessionState.remainingTicks` — both stay
  /// in sync but this notifier lets a single widget subscribe without
  /// triggering screen-wide rebuilds. See
  /// `.ai-factory/notes/11-breath-session-tick-render-scope.md`.
  ValueListenable<int> get remainingTicksNotifier => _remainingTicks;
  ```
  Do NOT remove or modify `remainingTicks` on `BreathSessionState`. This channel is purely additive.

- [x] **Task 3: Update `_remainingTicks` from `_setupEngine` and `_onEngineState`** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  - In `_setupEngine(BreathSessionDTO dto)`, after `final initialEngineState = _stateMachine!.currentState;` (and before the `state = BreathSessionState(...)` assignment), set:
    ```dart
    _remainingTicks.value = initialEngineState.remainingTicks;
    ```
  - In `_onEngineState(BreathSessionStateMachineState engineState)`, near the top after reading `final remaining = engineState.remainingTicks;`, push the value to the notifier:
    ```dart
    _remainingTicks.value = remaining;
    ```
    Place the assignment before the `state = BreathSessionState(...)` publication so any future early-return optimizations on the Riverpod publication still update the tick channel.
  - `ValueNotifier` already short-circuits assignments where the new value equals the old one, so no manual guard is needed.

- [x] **Task 4: Dispose `_remainingTicks` in the existing `ref.onDispose(...)` block** (depends on Task 2)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  In `build()`'s `ref.onDispose(...)` callback, add `_remainingTicks.dispose();` to the cleanup list. Place it near the other in-class teardown calls (e.g. after `_stateController.close();`) so the disposal order mirrors construction order. Do not introduce a separate `ref.onDispose` block — reuse the existing one.

## Verification (no new tests)
- [x] Run `/usr/local/bin/flutter analyze` from `packages/breath_module/` (or repo root) — must report no new warnings/errors.
- [x] Confirm no existing consumer of `BreathSessionState.remainingTicks` was modified; the field remains on `BreathSessionState` and continues to be set in both `_setupEngine` and `_onEngineState`.
