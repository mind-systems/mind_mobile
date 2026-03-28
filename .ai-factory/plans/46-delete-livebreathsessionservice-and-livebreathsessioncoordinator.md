# Plan: Delete LiveBreathSessionService and LiveBreathSessionCoordinator

## Context

The source-code deletions and wiring updates for this milestone were already carried out during milestone 45 (Create `BreathModuleStateChannel`). All three files — `LiveBreathSessionService`, `LiveBreathSessionCoordinator`, and the `ILiveBreathSessionService` interface (including `LiveBreathSessionDto`) — are gone from `lib/` and `packages/`. `BreathModule.dart` already wires `BreathModuleStateChannel` directly. The remaining work is cleaning up stale references in project instructions and metadata files.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Cleanup

- [x] **Task 1: Fix stale comment in BreathSessionViewModel**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart`
  Line 37 has the comment `/// Stream of state updates — used by LiveSessionCoordinator.` — update it to reference `BreathModuleStateChannel` instead, since that is the current consumer of `vm.stream`.

- [x] **Task 2: Fix stale CLAUDE.md reference to LiveSessionCoordinator**
  Files: `CLAUDE.md`
  Line 94 lists `LiveSessionCoordinator` as one of the 5 active components of the BreathSession presentation package. This component was deleted and its responsibilities moved to `BreathModuleStateChannel` in `lib/BreathModule/Core/`. Since `BreathModuleStateChannel` lives in the domain layer (`lib/`), not in `packages/breath_module`, remove the `LiveSessionCoordinator` bullet from the 5-component list and reduce the count from 5 to 4. The BreathSession system in `packages/breath_module/` now has 4 components: `BreathSessionStateMachine`, `BreathMotionEngine`, `BreathShapeShifter`, `BreathAnimationCoordinator`.

- [x] **Task 3: Mark ROADMAP milestone 7.7 as completed**
  Files: `.ai-factory/ROADMAP.md`
  Milestone 7.7 ("Update `ILiveBreathSessionService` → remove or replace") is already done — `ILiveBreathSessionService` was deleted in milestone 45 and `BreathModuleStateChannel` owns the channel directly. Check off the task in 7.7 or remove it, and move 7.7 to the Completed table.
