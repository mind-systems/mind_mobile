# Plan: Pin BreathSessionScreen to the dark palette via named `AppColors`, keep only the orb gold

## Context
Commit `fc23442` over-applied the "make the orb gold" task: it re-themed the whole `BreathSessionScreen`, swapped every cyan control to gold (`cs.tertiary`), and bound the Scaffold background + orb `maskColor` to `Theme.of(context).scaffoldBackgroundColor` — which leaks the light theme and renders the orb white. This milestone pins the screen to fixed dark-palette constants (exposed as a new public `AppColors` holder) so only the orb glow + starred star stay gold and everything else returns to the default cyan accent.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Expose the dark palette

- [x] **Task 1: Add public `AppColors` holder to `mind_ui`**
  Files: `packages/mind_ui/lib/src/AppTheme.dart`
  Additive change only — do not alter any existing color values or the `AppTheme.dark()` / `AppTheme.light()` builders. After the existing private constants (`_kBackgroundDark` `0xFF0A0E27`, `_kAccent` `0xFF00D9FF`, `_kWarmAccentDark` `0xFFFFB347`), add a public `abstract class AppColors` that mirrors them as a single source of truth:
  ```dart
  /// Dark-palette colors, for screens intentionally pinned to the dark theme
  /// regardless of the active ThemeData (e.g. BreathSessionScreen).
  abstract class AppColors {
    static const Color backgroundDark = _kBackgroundDark; // 0xFF0A0E27
    static const Color accent         = _kAccent;         // 0xFF00D9FF — default highlight
    static const Color warmAccentDark = _kWarmAccentDark; // 0xFFFFB347 — gold
  }
  ```
  `AppTheme.dart` is already exported by the `mind_ui` barrel, so no barrel/import edits are needed. Do NOT touch the `_kWarmAccentLight` `0xFFFF9D3D` value or the gold `tertiary` token in either theme.

### Phase 2: Repaint the screen from `AppColors`

- [x] **Task 2: Drop the live theme read and repaint via `AppColors`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Remove the `final cs = Theme.of(context).colorScheme;` line (currently line 178). The `build` method must read no live theme colors afterward (confirm no unused-variable warning). Repaint each element with a named `AppColors` constant — no `Theme.of(context)` color reads, no raw hex:
  - `Scaffold.backgroundColor` (line ~184): `Theme.of(context).scaffoldBackgroundColor` → `AppColors.backgroundDark`
  - `EclipseOrb.glowColor` (line ~220): `cs.tertiary` → `AppColors.warmAccentDark` (the gold — the actual task)
  - `EclipseOrb.maskColor` (line ~221-224): `Theme.of(context).scaffoldBackgroundColor` → `AppColors.backgroundDark` (fixes the white orb)
  - `BreathShapeWidget.shapeColor` (line ~242): `cs.tertiary` → `AppColors.accent`
  - Mute `IconButton` unmuted color (line ~329): `cs.tertiary` → `AppColors.accent` (muted state stays `Colors.white` α0.3 — untouched)
  - Share `IconButton` color (line ~350): `cs.tertiary` → `AppColors.accent`
  - Star `IconButton` color (line ~358): `cs.tertiary` → `isStarred ? AppColors.warmAccentDark : AppColors.accent`
  - Edit `IconButton` color (line ~363): `cs.tertiary` → `AppColors.accent`
  - Heart/favorite `IconButton` (line ~339-343): **leave untouched** — stays `isActive ? Colors.red : white α0.3`.
  `BreathSessionScreen` already imports `package:mind_ui/mind_ui.dart`, so `AppColors` resolves without new imports.

- [x] **Task 3: Verify analyzer is clean** (depends on Task 2)
  Files: (none — verification only)
  Run `/usr/local/bin/flutter analyze` inside both `packages/mind_ui` and `packages/breath_module`. Confirm no issues: the removed `final cs` line produces no unused-variable warning and `AppColors` resolves in both packages.

## Guards — do NOT touch
- Sound: `_soundCoordinator` wiring, `toggleMute`, and the muted-state opacity (`Colors.white.withValues(alpha: 0.3)`). Only the unmuted icon color changes.
- Heartbeat tick source: the favorite/heart `IconButton` (its red / dimmed-white colors and `viewModel.toggleHeartTickSource`).
- Gold token **values** in `AppTheme` — gold is correct in both themes (`0xFFFFB347` dark, `0xFFFF9D3D` light); never white. The white orb was the `maskColor`/background binding bug, not a gold-value problem.
- `packages/mind_ui/lib/src/ControlButton.dart` — shared, already `cs.primary` (cyan in both themes). No edit.
- `EclipseOrb.dart` — colors are passed in from the screen. No edit.
