# Meditation List — Section Header and Hairline Dividers

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- Add a "Poses"/"Позы" section header at the top of `MeditationListScreen`, matching `BreathSessionListSectionHeader` style exactly.
- Insert 1-physical-pixel hairline dividers between cells (not before the first, not after the last) — same pattern as `BreathSessionListCell`.
- `itemCount` grows from `poses.length` to `poses.length + 1` (header at index 0, cells at index i+1).

## Details

### New widget: MeditationListSectionHeader

**File:** `packages/meditation_module/lib/src/MeditationList/Views/MeditationListSectionHeader.dart`

Mirror of `BreathSessionListSectionHeader`:

```dart
class MeditationListSectionHeader extends StatelessWidget {
  final String title;
  const MeditationListSectionHeader({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.cardColor.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.textTheme.labelLarge?.color?.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
```

### L10n

Add to both ARB files in `packages/mind_l10n/`:
- Key: `meditationPoseSectionTitle`
- EN: `"Poses"`
- RU: `"Позы"`

### MeditationListScreen update

```dart
itemCount: state.poses.length + 1,
itemBuilder: (context, index) {
  if (index == 0) {
    return MeditationListSectionHeader(title: l10n.meditationPoseSectionTitle);
  }
  final poseIndex = index - 1;
  final pose = state.poses[poseIndex];
  final pixel = 1.0 / MediaQuery.devicePixelRatioOf(context);
  final showDivider = poseIndex < state.poses.length - 1;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      MeditationListCell(
        poseId: pose.id,
        title: meditationPoseTitle(l10n, pose.id),
        onTap: () => ref.read(meditationListViewModelProvider.notifier).onPoseTap(pose.id),
      ),
      if (showDivider)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(height: pixel, color: theme.dividerColor),
        ),
    ],
  );
},
```

### Exports

Add to `packages/meditation_module/lib/meditation_module.dart`:
```dart
export 'src/MeditationList/Views/MeditationListSectionHeader.dart';
```

### Verify

Run app → meditation list: "Poses"/"Позы" header at top with muted background, hairline dividers between pose cells, no divider after the last cell.
