# Meditation Module — Skeleton Copied from Breath

**Date:** 2026-05-30
**Source:** conversation context

> Per-task copy-from code specs for the larger Phase 25 tasks live in `.ai-factory/notes/34-meditation-module-impl-specs.md` (§A list, §B session, §C adapter, §D assembly). This note holds the high-level design and the reuse-vs-copy decisions.

## Key Findings

- The meditation module is a **skeleton copy** of the breath module: a pose list + a session screen. It deliberately reuses shared infrastructure instead of duplicating it where the infra is already module-agnostic.
- **Biometrics come for free.** The global biometric pipeline (`lib/Biometrics/` → `BiometricStreamClient`) is gated by `App.shared.moduleStateChannel.events` (`lib/Core/App.dart` constructs `BiometricStreamClient(grpcStub: ..., moduleStateEvents: moduleStateChannel.events)`). It streams HR, RR, EEG bands, emotions, motion only inside a `start → end` window of the shared `ModuleStateChannel`. If the meditation session drives that same channel, all current biometrics record automatically — nothing to build in biometrics.
- **Only `start` + `end` are tracked.** Meditation has no phases → no instruction stream. The user ends manually (Stop). No pause/resume. The app keeps recording while backgrounded — unlike breath, there is **no** `didChangeAppLifecycleState` auto-pause.
- **Poses are static.** Hardcoded `const List<MeditationPoseDTO>` (id + title), plain text cells. No notifier, no repository, no API, no Drift table, no gRPC list service — so **no new `App.dart` domain fields** are required.
- **Cross-project dependency:** the realtime `ActivityType` enum needs a `MEDITATION` member. Proto is owned by `mind_api` (specced in `mind_api/.ai-factory/notes/11-activity-type-meditation-extension.md`). Mobile copies the proto + regenerates, then extends its hand-written `ActivityType` enum.

## Details

### Architectural basis (why this is the intended path)

`.ai-factory/notes/01-live-session-architecture-refactor.md` designed `ModuleStateChannel` as **activity-agnostic** — it sends whatever `ActivityType` it receives. The per-module adapter (`BreathModuleStateChannel`) is the only class that knows its `ActivityType`. The note explicitly anticipated future modules: *"Any future module (yoga, meditation) gets `YogaModuleStateChannel` etc."* So `MeditationModuleStateChannel` + `ActivityType.meditation` is exactly the seam the refactor left open.

### Reuse vs copy

| Concern | Decision |
|---|---|
| Biometric pipeline (`lib/Biometrics/`, `BiometricStreamClient`) | **Reuse** — already gated by shared `ModuleStateChannel` |
| `ModuleStateChannel` (`lib/Core/Grpc/`) | **Reuse** — activity-agnostic; only gains a `MEDITATION` map branch |
| `ControlButton` (`packages/mind_ui`) | **Reuse** — same Start/Stop button as breath |
| List/session screens, ViewModels, interfaces, DTOs | **Copy** into `packages/meditation_module` (skeleton, simplified) |
| Lifecycle adapter | **Copy** → `MeditationModuleStateChannel` (minimal: start/end only) |
| Notifier / Repository / API / Drift / gRPC list | **Drop** — poses are static |
| Tick service / animation / shape / orb / audio / timeline / constructor / complexity / star / share | **Drop** — meditation session is an empty screen + one button |

### Lifecycle mapping (`MeditationModuleStateChannel`)

Mirror of `lib/BreathModule/Core/BreathModuleStateChannel.dart`, stripped down:
- subscribe to meditation session VM status stream (`idle | active`)
- `idle → active` → `channel.start(type: ActivityType.meditation, refId: poseId)` once (`_started`)
- `active → idle` → `channel.end()` once (`_ended`)
- `dispose()` → `channel.stop()` if `_started && !_ended`
- No instruction stream, no `moduleSessionId` tracking, no pause/resume, no phase dispatch.

The breath `ControlButton` reference is `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` `_buildControlButton` (play/pause). Meditation copies it minus the `complete`/replay branch and the loading-disable.

### Relevant existing files (templates)

- `lib/BreathModule/BreathModule.dart` — assembly point template (`buildSessionList`, `buildSession`).
- `lib/BreathModule/Core/BreathModuleStateChannel.dart` — lifecycle adapter template.
- `lib/Core/Grpc/ModuleStateChannel.dart` — `_mapActivityType` switch to extend.
- `lib/Core/Grpc/ActivityType.dart` — `enum ActivityType { breath }` to extend.
- `lib/router.dart` — breath routes (list / session via `state.extra`) to mirror.
- `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart` + `HomeViewModel.dart` + `HomeCoordinator.dart` — Home grid card wiring.
- `packages/breath_module/lib/src/BreathSessionsList/*` — list screen skeleton (minus pagination/starred/grouping).

### Atomic task summary (mind_mobile ROADMAP Phase 25)

1. Create `packages/meditation_module` package scaffold (+ root pubspec path dep).
2. `MeditationPoseDTO` + static `kMeditationPoses` list.
3. `MeditationListScreen` + ViewModel + `IMeditationListService`/`IMeditationListCoordinator` (text cells, tap → openSession).
4. `MeditationSessionScreen` + ViewModel (empty screen + Start/Stop `ControlButton`, local status only).
5. Copy `module_state.proto` + regen stubs (blocked on API).
6. Add `meditation` to `ActivityType` + map to `proto.ActivityType.MEDITATION`.
7. `MeditationModuleStateChannel` adapter (start/end only).
8. `MeditationModule.dart` assembly point (+ concrete coordinators).
9. Two routes in `lib/router.dart`.
10. Home grid card (`ModuleItem` + `onMeditationTap` + `HomeCoordinator.openMeditation` + `homeTabMeditation` l10n + icon).

Tasks 5–7 are the only lifecycle/cross-project chain; 1–4 and 8–10 are pure mobile UI/wiring. Copy-paste first — no breath/meditation code extraction this pass.

## Initial poses

Six poses, plain text cells. `id` is a stable slug used as the `refId` in `channel.start()`. Titles are **localized** via `mind_l10n`. `MeditationPoseDTO` carries **only `id`** (no localization-key field — `gen_l10n` has no runtime key lookup); a `meditationPoseTitle(AppLocalizations, id)` helper `switch`es `id` → the matching `l10n.meditationPose<Id>` getter. The ARB-key column below is the key the helper returns per `id`.

| id | ARB key | EN | RU |
|---|---|---|---|
| `easy` | `meditationPoseEasy` | Easy Pose | Поза по-турецки |
| `lotus` | `meditationPoseLotus` | Lotus | Лотос |
| `half_lotus` | `meditationPoseHalfLotus` | Half Lotus | Полулотос |
| `seiza` | `meditationPoseSeiza` | Kneeling (Seiza) | На коленях (сэйдза) |
| `chair` | `meditationPoseChair` | Seated (Chair) | Сидя на стуле |
| `savasana` | `meditationPoseSavasana` | Lying Down (Savasana) | Лёжа (шавасана) |

## Home card asset

`assets/images/modules/home/meditation.png` already exists (alongside `breath.png` / `bci.png` / `profile.png`), and `assets/images/modules/home/` is already declared in `pubspec.yaml` — no asset or pubspec changes needed. The Home grid currently has 3 `ModuleItem`s (Breath, Mind→BciDataScreen, Profile); meditation becomes a 4th card.

## Resolved decisions

- **Pose titles are localized** via `mind_l10n`: `MeditationPoseDTO` carries **only `id`** (no key field — `gen_l10n` has no runtime key lookup); a `meditationPoseTitle(AppLocalizations, id)` helper `switch`es `id` → `l10n.meditationPose<Id>`. Six ARB keys added EN/RU. Code: `.ai-factory/notes/34-meditation-module-impl-specs.md` (Resolved decisions).
- **`ControlButton` has no `size` param** — wrap in `SizedBox(80×80, ..., iconSize: 40)`, as breath does. It expands to fill its parent otherwise.
- **Session VM is a Riverpod `Notifier`** (like `BreathViewModel`, not `StateNotifier`). Status stream mirrors `BreathViewModel` exactly (`packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart:46-49`): private `StreamController<MeditationSessionState>.broadcast()` + `Stream<MeditationSessionState> get stream`; `set state` override does `super.state = value; _stateController.add(value);` (no tick-cadence filtering — meditation has no ticks); controller closed in the `build()` `ref.onDispose`. Provider is a `NotifierProvider` that throws by default and is overridden at `ProviderScope`. The adapter receives this `stream`, tracks previous `status`, and acts on `idle ↔ active` transitions — same shape as `BreathModuleStateChannel`.
