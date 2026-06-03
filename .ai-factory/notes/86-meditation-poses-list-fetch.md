# Meditation Poses — Fetch UUIDs When List Opens

**Date:** 2026-06-03
**Source:** conversation context

## Key Findings

- `IMeditationListService` gets a new `Future<void> refresh()` method.
- `MeditationListService` (concrete, in `lib/`) implements it by calling `meditationPosesApi.listPoses()` and writing the result into `App.shared.meditationPoseUuids`.
- `MeditationListViewModel.build()` fires-and-forgets `refresh()`. No loading state — the static pose list renders immediately; UUID cache is ready before the user can pick a pose.

## Details

### Interface change (`packages/meditation_module/lib/src/MeditationList/IMeditationListService.dart`)

```dart
abstract class IMeditationListService {
  List<MeditationPoseDTO> poses();
  Future<void> refresh();   // new
}
```

### `MeditationListService` (`lib/MeditationModule/MeditationListService.dart`)

```dart
@override
Future<void> refresh() async {
  try {
    final poses = await App.shared.meditationPosesApi.listPoses();
    App.shared.meditationPoseUuids = {
      for (final p in poses) p.slug: p.id,
    };
  } catch (e) {
    // Fetch failed — meditationPoseUuids stays empty.
    // Channel falls back to slug (session won't be recorded server-side).
    // No user-visible error.
  }
}
```

### `MeditationListViewModel.build()` (`packages/meditation_module/lib/src/MeditationList/MeditationListViewModel.dart`)

After the existing state initialization:
```dart
unawaited(service.refresh());
```

Fire-and-forget. Errors are already swallowed in the service.

### Guard
`refresh()` is declared on `IMeditationListService` (package interface), so `MeditationListService` in `lib/` can call `App.shared` without leaking domain knowledge into the package.
