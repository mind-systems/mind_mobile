# UI Overflow and System Bars (Mi A1 Investigation)

**Date:** 2026-05-19
**Source:** conversation context

## Key Findings

- `BreathSessionScreen` overflows by ~100px on small screens (Mi A1 = 360×640dp) because inner Column children have fixed heights that sum to ~652dp but only ~524dp is available.
- The outer `LayoutBuilder` in `BreathSessionScreen.build()` is dead weight — it captures `constraints` but never uses them; `screenWidth` comes from `MediaQuery`, not constraints.
- No `SystemUiOverlayStyle` is configured anywhere in the app — the nav bar defaults to black and the status bar to system gray; this is the cause of the black bar at bottom and gray bar at top on all screens.

## Details

### BreathSessionScreen overflow

**File:** `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart:136`

Height budget on Mi A1 (360×640dp, status bar 24dp, nav bar 48dp):
- Available for inner Column (`Expanded`): 640 − 24 (safeArea top) − ~92 (SessionBottomBar incl. nav bar padding) = **~524dp**
- Shape: `360 × 0.7 = 252dp` + `40dp` vertical padding = **292dp**
- Timeline: `48 × 4.5 = 216dp`
- Button + padding: `80 + 64 = 144dp`
- Total fixed: **652dp** → overflow **128dp ≈ 100px reported**

**Fix:** Remove the outer `LayoutBuilder`. Place a `LayoutBuilder` inside the `Expanded` to capture actual available height, then calculate `shapeDimension` as:
```dart
final idealShapeDim = screenWidth * 0.7;
final maxShapeDim = constraints.maxHeight - timelineHeight - buttonArea - shapeVertPadding;
final shapeDimension = idealShapeDim.clamp(80.0, maxShapeDim);
```
Constants: `timelineHeight = 216`, `buttonArea = 144`, `shapeVertPadding = 40`.

### System bars (status bar gray, nav bar black)

**File:** `lib/Core/App.dart:225` — `MaterialApp.router builder` callback

No `SystemUiOverlayStyle` is set anywhere. On Android 9 (API 28, Mi A1), the nav bar defaults to solid black and status bar to system default.

**Fix:** Wrap the `builder` child in `AnnotatedRegion<SystemUiOverlayStyle>` that adapts to the current theme brightness:
```dart
builder: (context, child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF0F4FC),
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ),
    child: GlobalListeners(...),
  );
},
```
Colors come from `AppTheme`: `_kBackgroundDark = 0xFF0A0E27`, `_kBackgroundLight = 0xFFF0F4FC`.

**Note:** This is NOT an Mi A1-specific issue — it will affect all Android devices. Mi A1 just makes it obvious because of its 3-button nav bar.

## Open Questions

- Should we also call `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` to draw behind system bars? Would require testing on API 28 (partial support) vs API 29+.
- Does reducing `shapeDimension` on very small screens feel acceptable UX? Minimum clamp of `80.0` may need tuning.
