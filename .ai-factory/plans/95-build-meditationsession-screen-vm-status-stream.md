# Plan: Build `MeditationSession` (screen + VM + status stream)

## Context
Add the `MeditationSession` presentation layer inside `packages/meditation_module/` — a status state, a stream-exposing ViewModel, a coordinator interface, and a single-button toggle screen. This mirrors `BreathSession` stripped down to lifecycle-only (no ticks/shape/timeline/audio/animation). Backend/channel wiring is intentionally out of scope (handled later in §C/§D). Full reference code: `.ai-factory/notes/34-meditation-module-impl-specs.md` §B.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Model & ViewModel

- [x] **Task 1: Add `MeditationSessionState` + status enum**
  Files: `packages/meditation_module/lib/src/MeditationSession/Models/MeditationSessionState.dart`
  Create `enum MeditationSessionStatus { idle, active }` and an immutable `MeditationSessionState` class with a `final MeditationSessionStatus status`, a `const MeditationSessionState({required this.status})` constructor, a `const MeditationSessionState.initial()` named constructor defaulting `status` to `idle`, and a `copyWith({MeditationSessionStatus? status})`. Use the exact shape in spec §B.

- [x] **Task 2: Add `MeditationSessionViewModel` + provider** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  Declare `meditationSessionViewModelProvider` as a `NotifierProvider<MeditationSessionViewModel, MeditationSessionState>` that throws `UnimplementedError('must be overridden via ProviderScope')` by default (mirrors `meditationListViewModelProvider` and breath's throw-by-default pattern). `MeditationSessionViewModel extends Notifier<MeditationSessionState>` with:
  - a private `final _stateController = StreamController<MeditationSessionState>.broadcast();` and `Stream<MeditationSessionState> get stream => _stateController.stream;`
  - `build()` registers `ref.onDispose(() => _stateController.close());` and returns `const MeditationSessionState.initial()` (initial state is NOT pushed to the stream — adapter treats pre-stream state as `idle`)
  - an `@override set state(MeditationSessionState value)` that calls `super.state = value;` then `_stateController.add(value);` — copied from `BreathSessionViewModel.dart:46-49,95-...` **minus the tick-cadence filtering** (`meditation has no ticks`). Guard the add with `if (!_stateController.isClosed)` as breath does.
  - `void start() => state = state.copyWith(status: MeditationSessionStatus.active);`
  - `void stop() => state = state.copyWith(status: MeditationSessionStatus.idle);`
  Import `dart:async` and `package:flutter_riverpod/flutter_riverpod.dart`. No constructor dependencies (VM is created bare; channel wiring happens in §D).

### Phase 2: Coordinator interface & Screen

- [x] **Task 3: Add `IMeditationSessionCoordinator` interface** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationSession/IMeditationSessionCoordinator.dart`
  `abstract class IMeditationSessionCoordinator { void close(); }`. Minimal, for boundary parity with breath's session coordinator; concrete impl lives in `lib/` (§D, out of scope here).

- [x] **Task 4: Add `MeditationSessionScreen`** (depends on Task 2)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`
  `ConsumerStatefulWidget` (needs `dispose()` to fire `onDispose`), mirroring `MeditationListScreen` static-field style:
  - Constructor `const MeditationSessionScreen({this.onDispose, super.key});` with `final VoidCallback? onDispose;`. **Does NOT take `poseId`** (poseId flows route → buildSession → adapter only).
  - `static String name = 'meditation_session';` and `static String path = '/$name';`
  - `dispose()` calls `widget.onDispose?.call();` then `super.dispose();`
  - Body: `Scaffold` → `Center` → watch `meditationSessionViewModelProvider` status; compute `final isActive = status == MeditationSessionStatus.active;` and render a **size-wrapped** button:
    ```dart
    SizedBox(
      width: 80,
      height: 80,
      child: ControlButton(
        icon: isActive ? Icons.stop : Icons.play_arrow,
        onPressed: () => isActive
            ? ref.read(meditationSessionViewModelProvider.notifier).stop()
            : ref.read(meditationSessionViewModelProvider.notifier).start(),
        iconSize: 40,
      ),
    )
    ```
  The `SizedBox(80/80)` + `iconSize: 40` wrapper is **mandatory** — `ControlButton` (from `package:mind_ui/mind_ui.dart`) has no intrinsic size and would otherwise fill the screen. The button is local state only — no backend/channel here. No bottom bar, no shape, no timeline, no audio, no tick service, no animation coordinators, and deliberately no `WidgetsBindingObserver` (meditation keeps recording in background — no app-lifecycle pause).

- [x] **Task 5: Export the new symbols from the barrel** (depends on Tasks 1-4)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Append exports for `src/MeditationSession/Models/MeditationSessionState.dart` (re-exports `MeditationSessionState` + `MeditationSessionStatus`), `src/MeditationSession/MeditationSessionViewModel.dart`, `src/MeditationSession/IMeditationSessionCoordinator.dart`, and `src/MeditationSession/MeditationSessionScreen.dart`, following the existing `MeditationList` export ordering.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add meditation session state and view model with status stream"
- **Commit 2** (after tasks 3-5): "Add meditation session screen, coordinator interface, and barrel exports"
