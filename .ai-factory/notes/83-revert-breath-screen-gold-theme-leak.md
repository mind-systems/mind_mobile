# Revert the warm-gold/theme-leak on BreathSessionScreen — keep only the orb gold

**Date:** 2026-06-03
**Source:** conversation context

## Key Findings

- The intended task was narrow: make **only the EclipseOrb** gold (its rotating blurred "prominences"). The commit `fc23442 "Warm gold color scheme for BreathSessionScreen"` overreached — it re-themed the whole screen, swapped every cyan control to gold (`cs.tertiary`), and replaced the two hardcoded dark-navy constants with `Theme.of(context).scaffoldBackgroundColor`. That last change is what makes the light theme leak in and makes the orb render **white** (the orb's `maskColor` is its central eclipse disk — when the app is in light mode it becomes the light background instead of dark navy, so the "eclipse" disappears).
- **Two files change:** `packages/mind_ui/lib/src/AppTheme.dart` (additive — expose the dark palette as public `AppColors` constants) and `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart` (repaint via those constants).
- The screen is pinned to the **dark palette via named constants** (`AppColors.backgroundDark` / `.accent` / `.warmAccentDark`), never the live `Theme.of(context)` and never raw hex. Background + orb eclipse-disk → dark navy; orb glow + starred star → gold; every other control → the default highlight accent (cyan). Heart and star are the only two non-highlight controls: star gold when starred, heart red when active.
- The orb is configured **entirely from the screen** — `EclipseOrb` receives `glowColor` and `maskColor` as explicit arguments, so `EclipseOrb.dart` does **not** need editing (its gold default `0xFFFFB347` is fine and unused-as-default since the call site passes a value).

## Details

### Exact edits — two files

**Approach** (per user, final): the screen is pinned to the **dark palette**, so every color comes from a **named dark-palette constant**, never from the live `Theme.of(context)` and never a raw hex literal. The dark constants are currently private (`_k*` in `AppTheme.dart`), so Step A exposes them publicly; Step B repaints the screen with them.

**Color rule:**
- **Background + orb eclipse-disk** → `AppColors.backgroundDark` (dark navy) — stops the light-theme leak and the white orb.
- **Orb glow** → `AppColors.warmAccentDark` (gold) — the actual task.
- **Every other control** (breathing figure, mute, share, edit) → `AppColors.accent` (the default highlight cyan). **Not gold.**
- **Star** (exception) → `AppColors.warmAccentDark` (gold) when starred, `AppColors.accent` when not.
- **Heart** (exception) → `Colors.red` when active (heartbeat tick source), dimmed white otherwise — already correct, **no edit**.

#### Step A — expose the dark palette from `mind_ui`

`packages/mind_ui/lib/src/AppTheme.dart` — add a public holder that mirrors the existing private dark constants (single source of truth; the `_k*` values and the `AppTheme.dark()`/`.light()` builders are **unchanged**):

```dart
/// Dark-palette colors, for screens intentionally pinned to the dark theme
/// regardless of the active ThemeData (e.g. BreathSessionScreen).
abstract class AppColors {
  static const Color backgroundDark = _kBackgroundDark; // 0xFF0A0E27
  static const Color accent         = _kAccent;         // 0xFF00D9FF — default highlight (shared, no light variant)
  static const Color warmAccentDark = _kWarmAccentDark;  // 0xFFFFB347 — gold (the dark member of the warm pair)
}
```

`AppTheme.dart` is already exported by the `mind_ui` barrel and `BreathSessionScreen` already imports `package:mind_ui/mind_ui.dart`, so **no barrel/import changes** are needed. Only re-expose — do not alter values.

#### Step B — repaint `BreathSessionScreen` via `AppColors`

Remove the `final cs = Theme.of(context).colorScheme;` line (currently line 178) — the screen reads **no** live theme colors after this.

| Element | Current (broken) | Target |
|---|---|---|
| `backgroundColor` (Scaffold) | `Theme.of(context).scaffoldBackgroundColor` | `AppColors.backgroundDark` |
| `EclipseOrb.glowColor` (orb prominences) | `cs.tertiary` | `AppColors.warmAccentDark` — **gold, the whole point** |
| `EclipseOrb.maskColor` (eclipse disk) | `Theme.of(context).scaffoldBackgroundColor` | `AppColors.backgroundDark` — fixes the white orb |
| `BreathShapeWidget.shapeColor` (figure) | `cs.tertiary` | `AppColors.accent` — default highlight |
| mute icon, unmuted state | `cs.tertiary` | `AppColors.accent` (muted state stays `Colors.white` α0.3) |
| share icon | `cs.tertiary` | `AppColors.accent` |
| edit icon | `cs.tertiary` | `AppColors.accent` |
| star icon | `cs.tertiary` (always gold) | `isStarred ? AppColors.warmAccentDark : AppColors.accent` |
| heart icon | `isActive ? Colors.red : white α0.3` | **unchanged** |

Star and orb now reference the *same* `AppColors.warmAccentDark`, so the starred star is exactly the orb's gold. Every value is a dark-pair member, so the screen renders identically in light or dark mode.

### Guards — leave untouched (except the additive `AppColors`)

- **Sound:** only the mute button's icon *color* changes. The `_soundCoordinator` wiring, `toggleMute`, and the muted-state opacity (`Colors.white.withValues(alpha: 0.3)`) are untouched.
- **Heartbeat tick source:** the favorite/heart `IconButton` (its `Colors.red` / dimmed-white colors and `viewModel.toggleHeartTickSource`) is untouched.
- **`packages/mind_ui/lib/src/ControlButton.dart`** — leave as-is. It already uses `cs.primary` (the default highlight accent the user wants for non-heart/non-star controls), which is `_kAccent = 0xFF00D9FF` cyan in **both** themes — so the bottom play/pause/replay button already satisfies the rule. It is also a shared component used outside this screen. No edit.
- **`packages/mind_ui/lib/src/AppTheme.dart`** — the only change is **additive** (the new public `AppColors` holder in Step A). The existing color **values** and the `AppTheme.dark()`/`.light()` builders are unchanged. In particular the gold token `cs.tertiary` is correctly gold in **both** themes — `_kWarmAccentDark = 0xFFFFB347` (brighter amber) in dark, `_kWarmAccentLight = 0xFFFF9D3D` (slightly deeper, for contrast on the light background) in light. It is **never white**: the white-orb symptom was *not* a gold-value problem but the `maskColor`/`backgroundColor` binding to `scaffoldBackgroundColor` (fixed by `AppColors.backgroundDark`). Do **not** "fix" or re-value the gold token — only re-expose the dark constants.
- **`EclipseOrb.dart`** — untouched; colors are passed in from the screen.
- The `shapeColor`-required refactor (commit `99ba8a2`) stays — the single call site still passes an explicit color (`0xFF00D9FF`), so the required parameter is satisfied.
- The gold active-timeline-row accent (commit `e50752b`) is a separate, intentional change and is **out of scope** — not part of this revert.

### Verify
- App in **either** light or dark mode → BreathSessionScreen background is always dark navy.
- Orb shows **gold** glowing prominences around a **dark** central disk (eclipse), never white.
- Breathing figure, mute, share, edit icons use `AppColors.accent` (cyan highlight); star is `AppColors.warmAccentDark` (gold) when starred and `AppColors.accent` otherwise; heart is **red** when active.
- Switch the app to light mode → the BreathSessionScreen looks **identical** (all colors are dark-pair constants); the orb gold and the starred star are the exact same gold.
- Sound toggle still mutes/unmutes; heartbeat tick-source toggle still switches the tick source.
- `flutter analyze` (full path `/usr/local/bin/flutter`) inside **both** `packages/mind_ui` and `packages/breath_module` reports no issues (confirm the `final cs` line is removed with no unused-variable warning, and `AppColors` resolves).

## Open Questions

None.
