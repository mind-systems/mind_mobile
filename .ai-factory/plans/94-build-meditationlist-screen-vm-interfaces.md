# Plan: Build `MeditationList` (screen + VM + interfaces)

## Context
Build the meditation pose list as a standalone module screen (interfaces, state, ViewModel, screen) inside `packages/meditation_module`, plus the concrete `MeditationListService` in `lib/`, mirroring the breath session list minus pagination/starred/grouping/skeletons/errors/FAB. The list is static — sourced from `kMeditationPoses`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Reference
- Full code + signatures: `.ai-factory/notes/34-meditation-module-impl-specs.md` §A and the "Resolved decisions" section.
- Patterns to mirror: `packages/breath_module/lib/src/BreathSessionsList/` (VM provider throw-by-default, screen layout). Drop everything not needed (no events/observeChanges, no pagination, no sections, no skeletons, no error listener, no FAB).
- Existing pieces (already done in Task 2): `MeditationPoseDTO`, `kMeditationPoses`, `meditationPoseTitle(l10n, id)` in `packages/meditation_module/lib/src/Models/MeditationPoses.dart`.

## Tasks

### Phase 1: Module-side contracts and state

- [x] **Task 1: Define the service and coordinator interfaces**
  Files: `packages/meditation_module/lib/src/MeditationList/IMeditationListService.dart`, `packages/meditation_module/lib/src/MeditationList/IMeditationListCoordinator.dart`
  Create `abstract class IMeditationListService { List<MeditationPoseDTO> poses(); }` — synchronous, no `observeChanges`, no events, no async (the list is static). Import `MeditationPoseDTO` from `../Models/MeditationPoses.dart`.
  Create `abstract class IMeditationListCoordinator { void openSession(String poseId); }` (no `openConstructor` — meditation has no constructor).

- [x] **Task 2: Define `MeditationListState`**
  Files: `packages/meditation_module/lib/src/MeditationList/Models/MeditationListState.dart`
  Create `class MeditationListState { final List<MeditationPoseDTO> poses; const MeditationListState({required this.poses}); }`. No `mode`/`hasMore` (static list has no loading states). Import `MeditationPoseDTO` from `../../Models/MeditationPoses.dart`.

### Phase 2: ViewModel and screen

- [x] **Task 3: Build `MeditationListViewModel` + provider** (depends on Tasks 1, 2)
  Files: `packages/meditation_module/lib/src/MeditationList/MeditationListViewModel.dart`
  Mirror `BreathSessionListViewModel`'s provider shape: `final meditationListViewModelProvider = NotifierProvider<MeditationListViewModel, MeditationListState>(() { throw UnimplementedError('MeditationListViewModel must be overridden via ProviderScope'); });`. Class `MeditationListViewModel extends Notifier<MeditationListState>` with `final IMeditationListService service;` and `final IMeditationListCoordinator coordinator;` constructor params. `build()` returns `MeditationListState(poses: service.poses())`. `void onPoseTap(String id) => coordinator.openSession(id);`. Import `flutter_riverpod`, the two interfaces, the state, and `MeditationPoseDTO`.

- [x] **Task 4: Build `MeditationListScreen`** (depends on Task 3)
  Files: `packages/meditation_module/lib/src/MeditationList/MeditationListScreen.dart`
  `class MeditationListScreen extends ConsumerWidget` (stateless — no scroll controller/pagination, unlike breath's `ConsumerStatefulWidget`). `static String name = 'meditation_list';` and `static String path = '/$name';`. In `build`, watch `meditationListViewModelProvider` for state and read `.notifier` for taps. Body: `Scaffold` → `SafeArea` → `ListView.builder` over `state.poses`; each row `ListTile(title: Text(meditationPoseTitle(AppLocalizations.of(context)!, pose.id)), onTap: () => ref.read(meditationListViewModelProvider.notifier).onPoseTap(pose.id))`. No `FloatingActionButton`. Import `flutter/material`, `flutter_riverpod`, `package:mind_l10n/mind_l10n.dart`, the VM, the state, and `MeditationPoseDTO`/`meditationPoseTitle` from `../Models/MeditationPoses.dart`.

### Phase 3: Concrete service and exports

- [x] **Task 5: Add concrete `MeditationListService` in `lib/`** (depends on Task 1)
  Files: `lib/MeditationModule/MeditationListService.dart`
  Per architecture (concrete service lives outside the package): `class MeditationListService implements IMeditationListService { @override List<MeditationPoseDTO> poses() => kMeditationPoses; }`. Import `package:meditation_module/meditation_module.dart` (interface + `MeditationPoseDTO` + `kMeditationPoses` must be exported by the barrel — see Task 6).

- [x] **Task 6: Export the new public symbols from the package barrel** (depends on Tasks 1, 2, 3, 4)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Add exports alongside the existing `Models/MeditationPoses.dart` export: `MeditationListScreen`, `MeditationListViewModel` (+ `meditationListViewModelProvider`), `IMeditationListService`, `IMeditationListCoordinator`, `MeditationListState`. Confirm the package compiles (`flutter analyze` / `flutter pub get` in the package).

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add meditation list module screen, view model, and interfaces"
- **Commit 2** (after tasks 5-6): "Add concrete meditation list service and export module symbols"
