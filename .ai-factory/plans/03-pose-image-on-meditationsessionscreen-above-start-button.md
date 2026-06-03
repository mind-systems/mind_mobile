# Plan: Pose image on MeditationSessionScreen above start button

## Context
Display the selected meditation pose image (240×240) above the start/stop `ControlButton` on `MeditationSessionScreen` by threading `poseId` through the session state, ViewModel (constructor injection), and module wiring.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Notes
- Pose ids (`packages/meditation_module/lib/src/Models/MeditationPoses.dart`) use **underscores**: `easy`, `lotus`, `half_lotus`, `seiza`, `chair`, `savasana`. The asset files use **hyphens** (`meditation-pose-half-lotus.png`). The path must normalize `_` → `-`, matching the sibling `MeditationListCell.dart:17`.
- `poseId` is always supplied by the route (`lib/router.dart:64` does `state.extra as String`), so no empty-string fallback is needed.
- Injection is via the **Notifier constructor**, matching `BreathModule.buildSession` and RULES.md line 9 (dependencies injected via constructor, never wired by external field mutation).

## Tasks

### Phase 1: State & ViewModel

- [x] **Task 1: Add `poseId` to `MeditationSessionState`**
  Files: `packages/meditation_module/lib/src/MeditationSession/Models/MeditationSessionState.dart`
  Add `final String poseId` to the class. Update the main constructor to `const MeditationSessionState({required this.status, required this.poseId})`. Replace the const `.initial()` constructor with a parameterized one: `const MeditationSessionState.initial({required String poseId}) : status = MeditationSessionStatus.idle, poseId = poseId;`. Extend `copyWith` to accept `String? poseId` and fall back to `poseId ?? this.poseId` (preserves `poseId` across `start()`/`stop()` transitions).

- [x] **Task 2: Inject `poseId` via `MeditationSessionViewModel` constructor** (depends on Task 1)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`
  Add a constructor `MeditationSessionViewModel({required this.poseId});` with `final String poseId;`. Change `build()` to return `MeditationSessionState.initial(poseId: poseId)` instead of `const MeditationSessionState.initial()`. Do **not** add a private `_poseId` field — a library-private member would not be assignable from the host-app wiring file and would not compile. Leave `start()`/`stop()` and the stream/state override untouched.

### Phase 2: Wiring & UI

- [x] **Task 3: Pass `poseId` into the VM in `MeditationModule.buildSession`** (depends on Task 2)
  Files: `lib/MeditationModule/MeditationModule.dart`
  Inside the `meditationSessionViewModelProvider.overrideWith(() { ... })` factory, construct the VM with the param: `final vm = MeditationSessionViewModel(poseId: poseId);`. The existing `MeditationModuleStateChannel` wiring (which also receives `poseId`) and `return vm;` stay unchanged.

- [x] **Task 4: Render pose image above the control button** (depends on Task 3)
  Files: `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`
  In `build()`, add a narrow select alongside the existing `status` watch: `final poseId = ref.watch(meditationSessionViewModelProvider.select((s) => s.poseId));`. Replace the `Center(child: SizedBox(80×80, ControlButton))` body with `Center(child: Column(mainAxisSize: MainAxisSize.min, children: [...]))` containing:
  1. `SizedBox(width: 240, height: 240, child: Image.asset('assets/images/modules/meditation/meditation-pose-${poseId.replaceAll('_', '-')}.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()))` — the `replaceAll('_', '-')` is required so `half_lotus` resolves to the on-disk `meditation-pose-half-lotus.png`; the `errorBuilder` stays only as a safety net for genuinely unknown ids.
  2. `const SizedBox(height: 40)`
  3. the existing `SizedBox(width: 80, height: 80, child: ControlButton(...))` (icon/onPressed/iconSize logic unchanged).
  The asset path has no `package:` prefix so it resolves against the host app bundle where `assets/images/modules/meditation/` is declared in `pubspec.yaml`.
