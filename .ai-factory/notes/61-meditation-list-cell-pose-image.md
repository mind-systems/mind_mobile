# Meditation List Cell — Pose Image

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `assets/images/modules/meditation/` is NOT declared in `pubspec.yaml`; only `assets/images/modules/home/` and `assets/audio/` are present — the directory must be added before images are loadable.
- `MeditationListScreen` currently uses a bare `ListTile` with only a pose title — replace with a custom `MeditationListCell` widget showing title + pose image below, left-aligned.
- Image naming convention in assets: `meditation-pose-<poseId>.png` (e.g. `meditation-pose-easy.png`, `meditation-pose-lotus.png`).

## Details

### pubspec.yaml change

Under `assets:`, add:
```yaml
- assets/images/modules/meditation/
```

### MeditationListCell widget

**File:** `packages/meditation_module/lib/src/MeditationList/Views/MeditationListCell.dart`

```dart
class MeditationListCell extends StatelessWidget {
  final String poseId;
  final String title;
  final VoidCallback? onTap;

  const MeditationListCell({
    required this.poseId,
    required this.title,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Image.asset(
              'assets/images/modules/meditation/meditation-pose-$poseId.png',
              height: 120,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }
}
```

### MeditationListScreen update

Replace the `ListTile` in `itemBuilder` with:

```dart
MeditationListCell(
  poseId: pose.id,
  title: meditationPoseTitle(l10n, pose.id),
  onTap: () => ref.read(meditationListViewModelProvider.notifier).onPoseTap(pose.id),
)
```

### Exports

Add to `packages/meditation_module/lib/meditation_module.dart`:
```dart
export 'src/MeditationList/Views/MeditationListCell.dart';
```

### Verify

Run app → navigate to meditation list → each cell should display the localized pose title and the corresponding pose image below it, left-aligned.
