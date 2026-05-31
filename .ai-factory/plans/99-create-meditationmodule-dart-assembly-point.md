# Plan: Create `MeditationModule.dart` assembly point

## Context
Add the meditation feature's app-layer assembly point that wires the existing package screens/ViewModels to concrete services, coordinators, and the module state channel — mirroring `lib/BreathModule/BreathModule.dart` minus tick services, instruction stream, and constructor.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Verified prerequisites (already present)
- `packages/meditation_module/` — `MeditationListScreen`, `MeditationListViewModel` + `meditationListViewModelProvider`, `IMeditationListService`, `IMeditationListCoordinator`, `MeditationSessionScreen` (`onDispose`), `MeditationSessionViewModel` + `meditationSessionViewModelProvider` (`.stream`), `IMeditationSessionCoordinator` (`void close()`), state types, `kMeditationPoses`. All exported from `package:meditation_module/meditation_module.dart`.
- `lib/MeditationModule/MeditationListService.dart` — concrete `MeditationListService`.
- `lib/MeditationModule/Core/MeditationModuleStateChannel.dart` — adapter with `{channel, stateStream, poseId}` constructor and `dispose()`.
- `App.shared.moduleStateChannel` (`ModuleStateChannel`) and `ActivityType.meditation` exist. No new `App.dart` fields needed.

## Scope note
This milestone covers §D only. Router registration of the meditation routes is out of scope here (the coordinators reference `MeditationSessionScreen.path` but route wiring is a separate roadmap item). Source of truth for all code shapes: `.ai-factory/notes/34-meditation-module-impl-specs.md` §D.

## Tasks

### Phase 1: Concrete coordinators

- [x] **Task 1: Add `MeditationListCoordinator`**
  Files: `lib/MeditationModule/MeditationListCoordinator.dart`
  Concrete class implementing `IMeditationListCoordinator` (from `package:meditation_module/meditation_module.dart`). Constructor takes `BuildContext context`. Implement `openSession(String poseId)` → `context.push(MeditationSessionScreen.path, extra: poseId)` using GoRouter's `context.push` (import `package:go_router/go_router.dart`). Follow the pattern in `lib/BreathModule/BreathSessionListCoordinator.dart`.

- [x] **Task 2: Add `MeditationSessionCoordinator`**
  Files: `lib/MeditationModule/MeditationSessionCoordinator.dart`
  Concrete class implementing `IMeditationSessionCoordinator`. Constructor takes `BuildContext context`. Implement `close()` → `context.pop()` (GoRouter). Follow `lib/BreathModule/BreathSessionCoordinator.dart`. May be unused initially — kept for boundary symmetry per §D.

### Phase 2: Assembly point

- [x] **Task 3: Add `MeditationModule.dart` assembly point** (depends on Task 1, Task 2)
  Files: `lib/MeditationModule/MeditationModule.dart`
  Create class `MeditationModule` with two static builders, exactly as §D:
  - `buildSessionList(BuildContext context)` — construct `MeditationListService()` and `MeditationListCoordinator(context)`; return a `ProviderScope` overriding `meditationListViewModelProvider` with `MeditationListViewModel(service:, coordinator:)`, child `const MeditationListScreen()`.
  - `buildSession(BuildContext context, {required String poseId})` — declare `late final MeditationModuleStateChannel stateChannel;`. Return a `ProviderScope` overriding `meditationSessionViewModelProvider` via `overrideWith(() { final vm = MeditationSessionViewModel(); stateChannel = MeditationModuleStateChannel(channel: App.shared.moduleStateChannel, stateStream: vm.stream, poseId: poseId); return vm; })`, child `MeditationSessionScreen(onDispose: () => stateChannel.dispose())`.
  Imports: `package:flutter/widgets.dart`, `package:flutter_riverpod/flutter_riverpod.dart`, `package:meditation_module/meditation_module.dart`, `package:mind/Core/App.dart`, the two coordinators (Tasks 1–2), `MeditationListService`, and `Core/MeditationModuleStateChannel.dart`. No new `App.dart` fields; reference only `App.shared.moduleStateChannel`.
