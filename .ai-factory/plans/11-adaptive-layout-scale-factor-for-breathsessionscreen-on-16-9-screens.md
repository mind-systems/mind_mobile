# Plan: Adaptive layout scale factor for BreathSessionScreen on 16:9 screens

## Context
On 16:9 phones (~516dp visible-SafeArea height) the inner Column of `BreathSessionScreen` overflows by ~100dp because every dimension (shape, paddings, timeline rows, button, bottom-bar icons) is fixed for 18:9+ screens. Introduce a single `BreathSessionLayout` value object whose `compute(screenWidth, availableHeight)` factory derives a uniform `scale` from `availableHeight / _idealHeight(screenWidth)` (clamped to `[0.5, 1.0]`) and exposes scaled dimensions. The outer `LayoutBuilder` at line 136 of `BreathSessionScreen.dart` is dead code (its `constraints` are not read) and must be removed.

**Layout-computation strategy (Option A/c from plan review 1):** compute `layout` exactly once at the top of `BreathSessionScreen.build()` from `MediaQuery`. No `LayoutBuilder` is reintroduced anywhere. Both the inner column subtree and the `SessionBottomBar` receive the same `layout`.

**Bottom-bar baseline (Option A from plan review 2):** the rendered height of `SessionBottomBar` is **dominated by the Material `IconButton` minimum tap target (48dp)**, not by the icon paint size — Material 2 enforces `_kMinButtonSize = kMinInteractiveDimension = 48` via a `ConstrainedBox`, and Material 3 enforces `minimumSize = Size(40, 40)` plus `MaterialTapTargetSize.padded` (8dp around) ⇒ ~48dp effective. The actual bar height is therefore `48 + 2·kBottomBarVPadding + mq.padding.bottom = 64 + mq.padding.bottom`, **independent of `iconSize`**. Naively using `kIconSize + 2·kBottomBarVPadding + mq.padding.bottom = 44 + bottomInset` undercounts the bar by ~20dp and leaves residual overflow on Mi A1. The plan therefore defines `kBottomBarBaseHeight = 64.0` as a derived public constant on `BreathSessionLayout` and uses it directly (not `kIconSize`).

**Single source of truth for the bar's inner padding:** `SessionBottomBar` consumes `BreathSessionLayout.kBottomBarVPadding` for its own `Padding`, so the value-object contract ("bar vertical padding = 8dp") and the bar widget's literal cannot drift apart.

**Tablet/foldable caveat (informational):** `_idealHeight` scales with `screenWidth`, so on a 600dp-wide portrait screen ideal grows to ~820dp; if device height is ≤820dp the shape will visibly shrink even though there's no real overflow. The `_kMinScale = 0.5` floor and the conservative 48dp bottom-bar baseline keep this safe; no special tablet branch is added in this milestone.

Full spec and class skeleton: `.ai-factory/notes/03-breath-session-adaptive-scale.md`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Layout value object

- [x] **Task 1: Create `BreathSessionLayout` value object**
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionLayout.dart`
  Create a new pure-Dart file (no Flutter imports) inside the `breath_module` package containing a `final class BreathSessionLayout` with **seven** `final double` fields: `shapeDimension`, `shapePadding`, `itemHeight`, `timelineHeight`, `buttonSize`, `buttonPadding`, `iconSize`.

  Declare the private constants exactly as:
  ```dart
  static const double _kShapeWidthRatio       = 0.7;
  static const double _kShapePadding          = 20.0;
  static const double _kTimelineItems         = 4.5;
  static const double _kItemHeight            = 48.0;
  static const double _kButtonSize            = 80.0;
  static const double _kButtonPadding         = 32.0;
  static const double _kIconSize              = 28.0;
  static const double _kBottomBarVPadding     = 8.0;
  static const double _kIconButtonMinTapTarget = 48.0; // Material enforced minimum: M2 _kMinButtonSize; M3 minimumSize 40 + tapTargetSize padded.
  static const double _kMinScale              = 0.5;
  ```

  Expose three public constants:
  ```dart
  static const double kIconSize           = _kIconSize;
  static const double kBottomBarVPadding  = _kBottomBarVPadding;
  // Matches Material's enforced 48dp tap target so the bar baseline holds even at min scale.
  static const double kBottomBarBaseHeight =
      _kIconButtonMinTapTarget + _kBottomBarVPadding * 2; // 64.0
  ```

  Provide a `const` private constructor with **every field `required`** (no positional, no optional):
  ```dart
  const BreathSessionLayout._({
    required this.shapeDimension,
    required this.shapePadding,
    required this.itemHeight,
    required this.timelineHeight,
    required this.buttonSize,
    required this.buttonPadding,
    required this.iconSize,
  });
  ```

  Implement `static double _idealHeight(double screenWidth)` returning
  `(screenWidth * _kShapeWidthRatio + _kShapePadding * 2) + (_kItemHeight * _kTimelineItems) + (_kButtonSize + _kButtonPadding * 2)` —
  no hardcoded `652.0`; the reference height is derived from the same constants used to scale each field.

  Implement the factory `BreathSessionLayout.compute(double screenWidth, double availableHeight)`:
  - `final scale = (availableHeight / _idealHeight(screenWidth)).clamp(_kMinScale, 1.0);`
  - Construct the object with each field multiplied by `scale`:
    - `shapeDimension: screenWidth * _kShapeWidthRatio * scale`
    - `shapePadding: _kShapePadding * scale`
    - `itemHeight: _kItemHeight * scale`
    - `timelineHeight: _kItemHeight * _kTimelineItems * scale`
    - `buttonSize: _kButtonSize * scale`
    - `buttonPadding: _kButtonPadding * scale`
    - `iconSize: _kIconSize * scale`

### Phase 2: Propagate scaled dimensions to leaf widgets

- [x] **Task 2: Add `itemHeight`-derived font size to `_TimelineItem`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Views/BreathTimelineWidget.dart`
  In the private `_TimelineItem` class (around line 168), add a required `final double itemHeight` field and a corresponding required named parameter in its constructor. Introduce two `static const` ratio constants inside `_TimelineItem` (named, not magic):
  ```dart
  static const double _kActiveFontRatio   = 22.0 / 48.0; // 0.4583…
  static const double _kInactiveFontRatio = 16.0 / 48.0; // 0.3333…
  ```
  Replace the hardcoded `fontSize: isActive ? 22 : 16` in the `TextStyle` with
  `fontSize: itemHeight * (isActive ? _kActiveFontRatio : _kInactiveFontRatio)`.
  This preserves the original 22/16 pair at `itemHeight = 48` and automatically scales fonts when the row shrinks.
  Update the single call site in `_buildList` (inside `itemBuilder`) to pass `itemHeight: widget.itemHeight` to `_TimelineItem`.
  Do not change the public `BreathTimelineWidget` API — it already exposes `itemHeight` as a constructor parameter.
  No change to `_buildList`'s `padding: EdgeInsets.symmetric(vertical: widget.itemHeight)` or to `getItemScrollOffsetById` — both already scale correctly with `widget.itemHeight`.

- [x] **Task 3: Add `iconSize` parameter to `SessionBottomBar` and consume `kBottomBarVPadding`** (depends on Task 1)
  Files: `packages/breath_module/lib/src/BreathSession/Views/SessionBottomBar.dart`
  Add `import '../BreathSessionLayout.dart';` (or the correct relative path from the `Views/` subfolder) to the imports — `SessionBottomBar` and `BreathSessionLayout` live in the same package and at the same layer, so the dependency is allowed.

  Add a new optional named parameter `final double iconSize` (default `28.0`) to the `SessionBottomBar` constructor.

  Replace the hardcoded `top: 8` / `bottom: 8 + mq.padding.bottom` inside the existing `Padding` with `BreathSessionLayout.kBottomBarVPadding` (i.e. `top: BreathSessionLayout.kBottomBarVPadding`, `bottom: BreathSessionLayout.kBottomBarVPadding + mq.padding.bottom`). This makes `BreathSessionLayout`'s `kBottomBarVPadding`/`kBottomBarBaseHeight` constants the single source of truth for the bar's vertical padding.

  Wrap the existing `Row` (the child of the `Padding`) in `IconTheme.merge(data: IconThemeData(size: iconSize), child: Row(...))` — use `.merge`, **not** the plain `IconTheme` constructor — so ancestor theme values (`color`, `opacity`, `shadows`, `applyTextScaling`, fill/weight/grade/optical-size) are preserved and only `size` is overridden.

  Add a one-line comment immediately above the `IconTheme.merge`:
  ```dart
  // Resolves via IconButton → IconButtonTheme → IconTheme. A non-null IconButtonTheme.iconSize anywhere up the tree will shadow this.
  ```

  Do not remove the surrounding `Padding`/`ColoredBox`; only the inner `Row` is wrapped. Note that **the bar's rendered height stays ≈48dp regardless of `iconSize`** because each `IconButton` enforces a Material min tap target — this is intentional and matches `BreathSessionLayout.kBottomBarBaseHeight`. Do not add `style: IconButton.styleFrom(minimumSize: Size.zero, tapTargetSize: shrinkWrap, padding: EdgeInsets.zero)` to the `IconButton`s; shrinking tap targets below 48dp on the smallest devices would regress touch accessibility on the very screens this plan targets.

### Phase 3: Wire layout into the screen

- [x] **Task 4: Remove dead outer `LayoutBuilder`, compute `layout` once at top of `build`, use `layout.*` throughout** (depends on Tasks 1–3)
  Files: `packages/breath_module/lib/src/BreathSession/BreathSessionScreen.dart`
  Add `import 'BreathSessionLayout.dart';` to the imports.

  In `build()`:
  - **Remove the outer `LayoutBuilder`** (currently wrapping the whole `Scaffold` at line 136). Confirmed that the body uses only `MediaQuery.of(context).size.width` and never references the builder's `constraints`, so removal is safe. The `Scaffold` becomes the top-level returned widget directly. **Do not reintroduce a `LayoutBuilder`** — neither inside `Expanded` nor around the outer `Column`.
  - At the very top of `build()` (before any returned widget and before any conditional/early-return path), compute layout from `MediaQuery` using the **pessimistic 48dp bar baseline**:
    ```dart
    final mq = MediaQuery.of(context);
    final screenWidth = mq.size.width;
    final bottomBarHeight =
        BreathSessionLayout.kBottomBarBaseHeight + mq.padding.bottom;
    final availableHeight = mq.size.height - mq.padding.top - bottomBarHeight;
    final layout = BreathSessionLayout.compute(screenWidth, availableHeight);
    ```
    `kBottomBarBaseHeight` (= 64) accounts for the Material `IconButton` minimum tap target (48dp) plus `2 × kBottomBarVPadding` (16dp). This holds at every scale — the icon paint size shrinks but the bar's rendered height does not.
  - Replace every previously hardcoded/locally-computed dimension inside the `Scaffold` body with the `layout.*` equivalents — **no `* scale` multiplications and no magic numbers (e.g. `4.5`) appear anywhere in `build()`**:
    - The `Padding` around the shape `SizedBox` uses `EdgeInsets.symmetric(vertical: layout.shapePadding)` (was `vertical: 20`).
    - The shape `SizedBox` uses `width: layout.shapeDimension`, `height: layout.shapeDimension` (was `shapeDimension = screenWidth * 0.7`).
    - `EclipseOrb` keeps `size: layout.shapeDimension * progress`.
    - The timeline wrapper `SizedBox` uses `height: layout.timelineHeight` (replace the local `timelineHeight = 48.0 * 4.5` and the `// todo copypaste` comment).
    - The `BreathTimelineWidget` call uses `itemHeight: layout.itemHeight` (was the local `48.0` constant).
    - The control button `Padding` uses `EdgeInsets.all(layout.buttonPadding)` (was `EdgeInsets.all(32)`).
  - Pass `layout.buttonSize` and `layout.iconSize` into `_buildControlButton` — change its signature to
    `Widget _buildControlButton(BreathSessionState state, BreathViewModel viewModel, {required double buttonSize, required double iconSize})`
    and replace the two hardcoded `SizedBox(width: 80, height: 80, …)` with `SizedBox(width: buttonSize, height: buttonSize, …)`. Replace the two hardcoded `iconSize: 40` inside `ControlButton(...)` with `iconSize: buttonSize * 0.5` and add a one-line comment at the first call site:
    ```dart
    // 0.5 mirrors the original 40/80 icon-to-button ratio.
    iconSize: buttonSize * 0.5,
    ```
    `ControlButton` paints an `Icon(size: iconSize)` inside an `InkWell` with no min-size constraint (verified in `packages/mind_ui/lib/src/ControlButton.dart`), so the ratio holds at all scales. Update the two call sites of `_buildControlButton` inside `build()` to pass `buttonSize: layout.buttonSize, iconSize: layout.iconSize`.
  - On `SessionBottomBar`, pass `iconSize: layout.iconSize`. **Remove the three hardcoded `iconSize: 28` lines** from the three `IconButton`s inside `SessionBottomBar.actions` — they now inherit the size from the `IconTheme.merge` injected in Task 3.
  - Keep all other behaviour (the `ValueListenableBuilder<double>` for `_orbCoordinator.orbProgress`, `AnimatedOpacity`, `BreathShapeWidget`, scroll listener wiring) unchanged.

## Commit Plan
- **Commit 1** (after Tasks 1–3): "Add BreathSessionLayout and scalable params for timeline and bottom bar"
- **Commit 2** (after Task 4): "Wire adaptive layout scale into BreathSessionScreen and remove dead LayoutBuilder"
