# Meditation Session Screen — Pose Image

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `MeditationSessionState` has no `poseId` field — add it so the screen can load the correct image.
- `MeditationSessionViewModel` receives `poseId` the same way `BreathModule` threads its params: set a field on the notifier inside the `overrideWith` factory before `build()` is called.
- The pose image sits above the `ControlButton`, sized 240×240, with a 40px gap — scaled comparably to the breath orb/shape widget.

## Details

### MeditationSessionState changes

**File:** `packages/meditation_module/lib/src/MeditationSession/Models/MeditationSessionState.dart`

Add `final String poseId` (required). Update constructor, `initial`, and `copyWith`:

```dart
@immutable
class MeditationSessionState {
  final MeditationSessionStatus status;
  final String poseId;

  const MeditationSessionState({required this.status, required this.poseId});

  const MeditationSessionState.initial({required String poseId})
      : status = MeditationSessionStatus.idle,
        poseId = poseId;

  MeditationSessionState copyWith({MeditationSessionStatus? status, String? poseId}) =>
      MeditationSessionState(
        status: status ?? this.status,
        poseId: poseId ?? this.poseId,
      );
}
```

### MeditationSessionViewModel changes

**File:** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionViewModel.dart`

Add a settable field `String? _poseId`. Change `build()` to use it:

```dart
class MeditationSessionViewModel extends Notifier<MeditationSessionState> {
  String? _poseId;

  @override
  MeditationSessionState build() {
    ref.onDispose(() => _stateController.close());
    return MeditationSessionState.initial(poseId: _poseId ?? '');
  }
  // ... rest unchanged
}
```

### MeditationModule.buildSession wiring

**File:** `lib/MeditationModule/MeditationModule.dart`

Inside the `overrideWith` factory, set `_poseId` before returning `vm`:

```dart
meditationSessionViewModelProvider.overrideWith((_) {
  final vm = MeditationSessionViewModel().._poseId = poseId;
  // existing stateChannel setup...
  return vm;
})
```

### MeditationSessionScreen UI change

**File:** `packages/meditation_module/lib/src/MeditationSession/MeditationSessionScreen.dart`

Watch `poseId` with a narrow select. Replace `Center(child: SizedBox(80, 80, ControlButton))` with:

```dart
final poseId = ref.watch(
  meditationSessionViewModelProvider.select((s) => s.poseId),
);

return Scaffold(
  body: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Image.asset(
            'assets/images/modules/meditation/meditation-pose-$poseId.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 80,
          height: 80,
          child: ControlButton(
            icon: isActive ? Icons.stop : Icons.play_arrow,
            onPressed: ...,
            iconSize: 40,
          ),
        ),
      ],
    ),
  ),
);
```

### Verify

Open session for any pose → the corresponding pose image appears above the start/stop button, 240×240, vertically centered together with the button.
