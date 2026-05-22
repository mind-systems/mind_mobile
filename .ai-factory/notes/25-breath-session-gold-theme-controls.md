# Note 25 — Breath Session: Gold Theme + Mute + Screen Blackout

Retheme the breath session screen with warm amber-gold; add mute and screen-blackout controls to the bottom bar. All colors come from `colorScheme.tertiary` — no hardcodes.

## Color slot

`colorScheme.tertiary` (`_kWarmAccentDark`) is already warm gold. Its current value `0xFFF4BA40` is slightly yellow; update it to `0xFFFFB347` (warmer amber-gold) in `AppTheme.dart`. Both dark and light values update:

```dart
const _kWarmAccentDark  = Color(0xFFFFB347); // warm amber-gold (UAE ambient)
const _kWarmAccentLight = Color(0xFFFF9D3D); // slightly deeper for light bg
```

Access everywhere via `Theme.of(context).colorScheme.tertiary`. No other theme fields are added.

---

## Milestone A — Warm gold color scheme

### `packages/mind_ui/lib/src/AppTheme.dart`

Update the two warm accent constants:

```dart
const _kWarmAccentDark  = Color(0xFFFFB347);
const _kWarmAccentLight = Color(0xFFFF9D3D);
```

### `packages/mind_ui/lib/src/ControlButton.dart`

Remove hardcoded cyan; read from theme:

```dart
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final isDisabled = onPressed == null;
  return Opacity(
    opacity: isDisabled ? 0.4 : 1.0,
    child: Material(
      color: cs.primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Center(
          child: Icon(
            icon,
            color: destructive ? cs.error : cs.primary,
            size: iconSize,
          ),
        ),
      ),
    ),
  );
}
```

The central pause/play/restart button keeps using `cs.primary` (cyan) — it is not in the bottom panel and should stay visually distinct from the bottom bar controls.

### `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`

Read the theme once at the top of `build()` and use it:

```dart
final cs = Theme.of(context).colorScheme;
```

Replace four hardcoded color sites:

1. `EclipseOrb glowColor: const Color(0xFF00C8E0)` → `glowColor: cs.tertiary`
2. `BreathShapeWidget shapeColor: const Color(0xFF00D9FF)` → `shapeColor: cs.tertiary`
3. Share `IconButton color: const Color(0xFF00D9FF)` → `color: cs.tertiary`
4. Edit `IconButton color: const Color(0xFF00D9FF)` → `color: cs.tertiary`
5. Star (not starred): already `colorScheme.primary` — change to `cs.tertiary` to match
6. `maskColor: const Color(0xFF0A0E27)` → `maskColor: Theme.of(context).scaffoldBackgroundColor`
7. `backgroundColor: const Color(0xFF0A0E27)` → `backgroundColor: Theme.of(context).scaffoldBackgroundColor`

### `packages/breath_module/lib/src/BreathSession/Views/EclipseOrb.dart`

Update default parameter to match the theme default (cosmetic — actual value always comes from the call site):

```dart
this.glowColor = const Color(0xFFFFB347),
```

---

## Milestone B — Mute + screen-off controls

### `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`

New field:
```dart
final ValueNotifier<bool> isMuted = ValueNotifier(false);
```

New method:
```dart
void toggleMute() {
  isMuted.value = !isMuted.value;
  if (isMuted.value) {
    _looper.fadeOut(const Duration(milliseconds: 300));
    _oneShot.stop();
  } else {
    if (_currentStatus == BreathSessionStatus.breath &&
        _currentPhase != null &&
        _phaseAssets.containsKey(_currentPhase)) {
      _looper.crossfadeTo(
        _phaseOrder.indexOf(_currentPhase!),
        const Duration(milliseconds: 300),
      );
    }
  }
}
```

Guard `_onStateChanged`: wrap the `switch(state.status)` block and the phase-change audio calls with `if (!isMuted.value)`. State tracking (`_currentStatus`, `_currentPhase`) continues unconditionally.

Guard `_onTick`:
```dart
if (_isSuspended) return;
if (isMuted.value) return;
```

In `dispose()`: `isMuted.dispose();`

### `packages/breath_module/lib/src/BreathSession/Views/SessionBottomBar.dart`

Rename `actions` → `trailingActions`, add `leadingActions`:

```dart
class SessionBottomBar extends StatelessWidget {
  const SessionBottomBar({
    super.key,
    this.leadingActions = const [],
    required this.trailingActions,
    this.iconSize = BreathSessionLayout.kIconSize,
  });

  final List<Widget> leadingActions;
  final List<Widget> trailingActions;
  final double iconSize;
```

Row layout:
```dart
Row(
  children: [
    Row(spacing: 8, children: leadingActions),
    const Spacer(),
    Row(spacing: 8, children: trailingActions),
  ],
),
```

### `packages/breath_module/lib/src/BreathSession/Views/EclipseOrb.dart`

Add optional `VoidCallback? onTap` parameter to `EclipseOrb`:

```dart
const EclipseOrb({
  ...
  this.onTap,
});

final VoidCallback? onTap;
```

In `_EclipseOrbState.build()`, the existing `GestureDetector.onTap` calls only `pulse`. Change it to call both:

```dart
GestureDetector(
  onTap: () {
    pulse();
    widget.onTap?.call();
  },
  ...
)
```

### `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`

Add `bool _isBlackedOut = false;` field.

Pass `onTap` to `EclipseOrb` inside the existing `ValueListenableBuilder`:

```dart
EclipseOrb(
  size: layout.shapeDimension * progress,
  glowColor: cs.tertiary,
  maskColor: Theme.of(context).scaffoldBackgroundColor,
  pulseStream: viewModel.tickStream,
  onTap: () => setState(() => _isBlackedOut = true),
),
```

Wrap `Scaffold.body` in a `Stack`, adding the blackout overlay — dismissed by tapping anywhere on the black screen:

```dart
body: Stack(
  children: [
    SafeArea(/* existing content */),
    AnimatedOpacity(
      opacity: _isBlackedOut ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_isBlackedOut,
        child: GestureDetector(
          onTap: () => setState(() => _isBlackedOut = false),
          child: const ColoredBox(color: Colors.black, child: SizedBox.expand()),
        ),
      ),
    ),
  ],
),
```

Update `SessionBottomBar` call — only mute button on the left, no screen-off button:

```dart
SessionBottomBar(
  iconSize: layout.iconSize,
  leadingActions: [
    ValueListenableBuilder<bool>(
      valueListenable: _soundCoordinator.isMuted,
      builder: (context, isMuted, _) => IconButton(
        icon: Icon(isMuted ? Icons.volume_off_outlined : Icons.volume_up),
        color: isMuted
            ? Colors.white.withValues(alpha: 0.3)
            : cs.tertiary,
        onPressed: _soundCoordinator.toggleMute,
      ),
    ),
  ],
  trailingActions: [
    IconButton(
      icon: const Icon(Icons.share_outlined),
      color: cs.tertiary,
      onPressed: () => viewModel.shareSession(),
    ),
    if (canStar)
      IconButton(
        icon: Icon(isStarred ? Icons.star : Icons.star_border),
        color: cs.tertiary,
        onPressed: () => viewModel.toggleStar(),
      ),
    IconButton(
      icon: const Icon(Icons.edit_outlined),
      color: cs.tertiary,
      onPressed: () => viewModel.openEditor(),
    ),
  ],
),
```

Note: starred and unstarred both use `cs.tertiary`; the fill vs outline icon already communicates the state.

---

## Atomicity

- Milestone A (colors) ships alone — ControlButton and session colors decoupled from new controls.
- Milestone B (controls) depends on A only for color consistency; can technically ship independently since it adds new `leadingActions` without touching existing colors.
