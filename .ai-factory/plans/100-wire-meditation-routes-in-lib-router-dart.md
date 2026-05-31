# Plan: Wire meditation routes in `lib/router.dart`

## Context
Registers the two meditation screens (list + session) in the app's GoRouter so the meditation module is reachable via navigation, mirroring the existing breath routes.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Routing

- [x] **Task 1: Add meditation imports**
  Files: `lib/router.dart`
  At the top of the file add the assembly-point import `import 'package:mind/MeditationModule/MeditationModule.dart';` (place it near the other `MeditationModule`/module imports, e.g. after the `BreathModule` import on line 2). Add a `show` import for the two screens: `import 'package:meditation_module/meditation_module.dart' show MeditationListScreen, MeditationSessionScreen;` (mirror the existing `breath_module` `show` import on line 4). Both `MeditationModule.buildSessionList`/`buildSession` and the screens' static `path`/`name` getters already exist and are exported from the `meditation_module` barrel.

- [x] **Task 2: Register the two `GoRoute`s** (depends on Task 1)
  Files: `lib/router.dart`
  In the `routes:` list of `appRouter`, add two `GoRoute`s mirroring the breath routes (lines 32–44). Place them after the existing breath routes for grouping:
  - List route — `path: MeditationListScreen.path`, `name: MeditationListScreen.name`, `builder: (context, state) => MeditationModule.buildSessionList(context)`.
  - Session route — `path: MeditationSessionScreen.path`, `name: MeditationSessionScreen.name`, `builder` reads `final poseId = state.extra as String;` then returns `MeditationModule.buildSession(context, poseId: poseId)` (mirrors `BreathSessionScreen`'s `sessionId` extraction on lines 37–43).
  Task ends when the project compiles and both routes resolve.
