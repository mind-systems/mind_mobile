# Meditation Module — Detailed Implementation Specs

**Date:** 2026-05-30
**Source:** conversation context

Detailed per-task specs for the larger Phase 25 tasks (mind_mobile ROADMAP). The roadmap entries are summaries that tag this note by section. High-level rationale and the reuse-vs-copy table live in `.ai-factory/notes/33-meditation-module.md`. This note is the copy-from reference for the orchestrator — every shape here is taken from the actual breath code, not invented.

## Resolved decisions (apply across all tasks)

- **Pose title localization uses a `switch`, not a dynamic key lookup.** `gen_l10n` exposes only getters (`l10n.meditationPoseEasy`); there is no way to resolve a title from a runtime key string. Therefore `MeditationPoseDTO` carries **only `id`** (no `l10nKey` field), and a single helper function maps `id → localized title`:
  ```dart
  // packages/meditation_module/lib/src/Models/MeditationPoses.dart
  String meditationPoseTitle(AppLocalizations l10n, String id) {
    switch (id) {
      case 'easy': return l10n.meditationPoseEasy;
      case 'lotus': return l10n.meditationPoseLotus;
      case 'half_lotus': return l10n.meditationPoseHalfLotus;
      case 'seiza': return l10n.meditationPoseSeiza;
      case 'chair': return l10n.meditationPoseChair;
      case 'savasana': return l10n.meditationPoseSavasana;
      default: return id;
    }
  }
  ```
  The list cell calls `meditationPoseTitle(AppLocalizations.of(context)!, pose.id)`.
- **No domain event stream for the static list.** Breath's `IBreathSessionListService` exposes `observeChanges()` + a sealed `BreathSessionListEvent` hierarchy because data is async/paginated. Meditation poses are static — the meditation list service has **no `observeChanges`, no event classes, no pagination, no refresh**. Just a synchronous `poses()` getter.
- **`ControlButton` (`packages/mind_ui/lib/src/ControlButton.dart`, exported from `mind_ui.dart`) is a `StatelessWidget`** with `required IconData icon`, `required VoidCallback? onPressed`, `bool destructive = false`, `double iconSize = 40`. It has **NO `size` parameter** — internally it is a `Material` + `InkWell` + `Center` that expands to fill its parent. Breath therefore wraps it in `SizedBox(width: buttonSize, height: buttonSize, child: ControlButton(..., iconSize: buttonSize * 0.5))`. Meditation must do the same: wrap in `SizedBox(width: 80, height: 80, child: ControlButton(icon: ..., onPressed: ..., iconSize: 40))` (80/40 are the breath base sizes `BreathSessionLayout._kButtonSize` / icon ≈ half). `onPressed` is required and must be non-null (always passed here, never disabled).
- **Riverpod is `flutter_riverpod: ^3.0.0`** (same as `breath_module`). VMs are `Notifier<T>` + `NotifierProvider`; the `@override set state` pattern is valid (breath uses it).
- **The session VM's initial `idle` state is NOT emitted on the broadcast stream** (breath only adds to the controller inside `set state`, never the `build()` return). The adapter therefore treats the pre-stream state as `idle` and acts on the first real transition (`idle → active`).

---

## §A — Task 3: MeditationList (screen + VM + interfaces)

All in `packages/meditation_module/lib/src/MeditationList/`. Mirror breath list, drop pagination/starred/grouping/skeletons/errors.

**`IMeditationListService.dart`**
```dart
abstract class IMeditationListService {
  List<MeditationPoseDTO> poses();
}
```
No events, no async. (Breath equivalent: `IBreathSessionListService` — we keep only the data accessor.)

**`IMeditationListCoordinator.dart`**
```dart
abstract class IMeditationListCoordinator {
  void openSession(String poseId);
}
```
(Breath has `openSession` + `openConstructor`; meditation has no constructor.)

**`Models/MeditationListState.dart`**
```dart
class MeditationListState {
  final List<MeditationPoseDTO> poses;
  const MeditationListState({required this.poses});
}
```
No `mode`/`hasMore` (breath needs them for loading states; static list does not).

**`MeditationListViewModel.dart`** — `Notifier<MeditationListState>`, mirroring `BreathSessionListViewModel` (which is `Notifier`, provider `NotifierProvider` throwing by default):
```dart
final meditationListViewModelProvider =
    NotifierProvider<MeditationListViewModel, MeditationListState>(() {
      throw UnimplementedError('must be overridden via ProviderScope');
    });

class MeditationListViewModel extends Notifier<MeditationListState> {
  final IMeditationListService service;
  final IMeditationListCoordinator coordinator;
  MeditationListViewModel({required this.service, required this.coordinator});

  @override
  MeditationListState build() => MeditationListState(poses: service.poses());

  void onPoseTap(String id) => coordinator.openSession(id);
}
```

**`MeditationListScreen.dart`** — `ConsumerWidget` (stateless; no scroll controller / pagination, unlike breath's `ConsumerStatefulWidget`). `static name = 'meditation_list'`, `static path = '/$name'`. Body: `Scaffold` → `SafeArea` → `ListView.builder` over `state.poses`; each row a `ListTile(title: Text(meditationPoseTitle(l10n, pose.id)), onTap: () => vm.onPoseTap(pose.id))`. No FloatingActionButton (breath has one for the constructor — meditation has none).

**Concrete service** lives in `lib/` (per architecture: concrete service outside the package) → `lib/MeditationModule/MeditationListService.dart`:
```dart
class MeditationListService implements IMeditationListService {
  @override
  List<MeditationPoseDTO> poses() => kMeditationPoses;
}
```

**Barrel exports** (`lib/meditation_module.dart`): `MeditationListScreen`, `MeditationListViewModel`, `IMeditationListService`, `IMeditationListCoordinator`, `MeditationListState`, plus the Models from Task 2.

---

## §B — Task 4: MeditationSession (screen + VM + stream)

All in `packages/meditation_module/lib/src/MeditationSession/`.

**`Models/MeditationSessionState.dart`**
```dart
enum MeditationSessionStatus { idle, active }

class MeditationSessionState {
  final MeditationSessionStatus status;
  const MeditationSessionState({required this.status});
  const MeditationSessionState.initial() : status = MeditationSessionStatus.idle;
  MeditationSessionState copyWith({MeditationSessionStatus? status}) =>
      MeditationSessionState(status: status ?? this.status);
}
```

**`MeditationSessionViewModel.dart`** — `Notifier<MeditationSessionState>`, copying the stream mechanism from `BreathSessionViewModel.dart:46-49,95-...`:
```dart
final meditationSessionViewModelProvider =
    NotifierProvider<MeditationSessionViewModel, MeditationSessionState>(() {
      throw UnimplementedError('must be overridden via ProviderScope');
    });

class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  final _stateController = StreamController<MeditationSessionState>.broadcast();
  Stream<MeditationSessionState> get stream => _stateController.stream;

  @override
  MeditationSessionState build() {
    ref.onDispose(() => _stateController.close());
    return const MeditationSessionState.initial();
  }

  @override
  set state(MeditationSessionState value) {
    super.state = value;
    _stateController.add(value); // no tick-cadence filtering — meditation has no ticks
  }

  void start() => state = state.copyWith(status: MeditationSessionStatus.active);
  void stop()  => state = state.copyWith(status: MeditationSessionStatus.idle);
}
```

**`IMeditationSessionCoordinator.dart`** — minimal: `void close();` (parity with breath's coordinator; may be unused initially but keeps the boundary symmetric). The concrete impl is in `lib/MeditationModule/MeditationSessionCoordinator.dart`.

**`MeditationSessionScreen.dart`** — `ConsumerStatefulWidget` (needs a `dispose()` to fire `widget.onDispose`, mirroring `BreathSessionScreen`). Constructor: `const MeditationSessionScreen({this.onDispose, super.key});` with `final VoidCallback? onDispose;`. `static name = 'meditation_session'`, `static path = '/$name'`. **Does NOT take `poseId`** — `poseId` flows route → `buildSession` → adapter only. `dispose()` calls `widget.onDispose?.call()` then `super.dispose()`. Body: `Scaffold` → `Center` → a `Consumer` watching `status`, rendering one size-wrapped `ControlButton`:
```dart
final isActive = status == MeditationSessionStatus.active;
return SizedBox(
  width: 80,
  height: 80,
  child: ControlButton(
    icon: isActive ? Icons.stop : Icons.play_arrow,
    onPressed: () => isActive ? vm.stop() : vm.start(),
    iconSize: 40,
  ),
);
```
The `SizedBox` is mandatory — `ControlButton` has no intrinsic size and would otherwise fill the screen (see Resolved decisions). No bottom bar, no shape, no timeline, no audio, no tick service, no animation coordinators, no `WidgetsBindingObserver` (meditation keeps recording in background — there is deliberately no app-lifecycle pause).

**Barrel exports:** `MeditationSessionScreen`, `MeditationSessionViewModel`, `IMeditationSessionCoordinator`, `MeditationSessionState` (+ `MeditationSessionStatus`).

---

## §C — Task 7: MeditationModuleStateChannel adapter

New file `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`. Strip `lib/BreathModule/Core/BreathModuleStateChannel.dart` down to lifecycle-only.

```dart
class MeditationModuleStateChannel {
  final ModuleStateChannel _channel;
  final String _poseId;
  bool _started = false;
  bool _ended = false;
  MeditationSessionStatus? _previousStatus;
  late final StreamSubscription<MeditationSessionState> _stateSub;

  MeditationModuleStateChannel({
    required ModuleStateChannel channel,
    required Stream<MeditationSessionState> stateStream,
    required String poseId,
  })  : _channel = channel, _poseId = poseId {
    _stateSub = stateStream.listen(_onState);
  }

  void _onState(MeditationSessionState state) {
    final status = state.status;
    if (status == _previousStatus) return;

    if (status == MeditationSessionStatus.active && !_started) {
      _channel.start(type: ActivityType.meditation, refId: _poseId);
      _started = true;
    } else if (status == MeditationSessionStatus.idle && _started && !_ended) {
      _channel.end();
      _ended = true;
    }
    _previousStatus = status;
  }

  void dispose() {
    if (_started && !_ended) _channel.stop();
    _stateSub.cancel();
  }
}
```

Deliberately absent vs breath: no `BreathModuleInstructionStream`, no `_channelSub`/`_moduleSessionId`/`_pendingInstruction`/`_flushPending`, no `_handleInstruction`, no pause/resume branch, no phase tracking, no `reset()` (no restart in meditation). `import 'package:mind/Core/Grpc/ActivityType.dart'` + `ModuleState`-channel import + the session state type from `package:meditation_module/meditation_module.dart`.

**Lifecycle reasoning:** Stop button → `vm.stop()` → status `idle` → `channel.end()` once. Screen pop → `onDispose` → `dispose()` → if user navigated away without pressing Stop while active, `channel.stop()` closes it (server treats `stop` as interrupt). `dispose()` after a normal `end()` does nothing (`_ended` guard).

---

## §D — Task 8: MeditationModule.dart assembly point

New file `lib/MeditationModule/MeditationModule.dart`, mirroring `lib/BreathModule/BreathModule.dart`.

```dart
class MeditationModule {
  static Widget buildSessionList(BuildContext context) {
    final service = MeditationListService();
    final coordinator = MeditationListCoordinator(context);
    return ProviderScope(
      overrides: [
        meditationListViewModelProvider.overrideWith(
          () => MeditationListViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const MeditationListScreen(),
    );
  }

  static Widget buildSession(BuildContext context, {required String poseId}) {
    late final MeditationModuleStateChannel stateChannel;
    return ProviderScope(
      overrides: [
        meditationSessionViewModelProvider.overrideWith(() {
          final vm = MeditationSessionViewModel();
          stateChannel = MeditationModuleStateChannel(
            channel: App.shared.moduleStateChannel,
            stateStream: vm.stream,
            poseId: poseId,
          );
          return vm;
        }),
      ],
      child: MeditationSessionScreen(onDispose: () => stateChannel.dispose()),
    );
  }
}
```

This is the exact shape of `BreathModule.buildSession` (the `late final stateChannel` captured inside the `overrideWith` factory, wired to `vm.stream`, disposed via the screen's `onDispose`) minus tick services, the instruction stream, and the session/constructor services.

**Concrete coordinators** in `lib/MeditationModule/`:
- `MeditationListCoordinator(BuildContext context)` → `openSession(poseId) => context.push(MeditationSessionScreen.path, extra: poseId);`
- `MeditationSessionCoordinator(BuildContext context)` → `close() => context.pop();` (or Navigator equivalent used elsewhere).

No new `App.dart` fields (only the already-wired `App.shared.moduleStateChannel` is referenced).

## Open Questions

None — all shapes verified against current breath code.
