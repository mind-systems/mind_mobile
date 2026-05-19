# Plan Review: Adaptive layout scale factor for BreathSessionScreen on 16:9 screens

**Plan:** `.ai-factory/plans/11-adaptive-layout-scale-factor-for-breathsessionscreen-on-16-9-screens.md`
**Spec:** `.ai-factory/notes/03-breath-session-adaptive-scale.md`
**Reviewer pass:** 1

## Summary

**Risk:** 🟡 Medium

The intent (uniform scale factor derived from available height, single `BreathSessionLayout` value object, font sizes derived from `itemHeight`) is well-grounded and matches the codebase. Tasks 1–3 are precise and match the actual files (`_TimelineItem` at line 168, `SessionBottomBar` Row inside `Padding`/`ColoredBox`, `ControlButton.iconSize` default 40 confirmed). The bulk of the design is sound.

However, **Task 4 contains a self-contradicting, mathematically broken instruction about LayoutBuilder placement** that, if executed as the plan currently allows, will not fix the overflow. This needs to be tightened before implementation.

## Context Gates

- **Architecture (.ai-factory/ARCHITECTURE.md):** Not consulted in this review; the change is presentation-package-local and respects the existing module boundary (pure-Dart value object inside `packages/breath_module/`, no `lib/` imports). No domain leakage. ✅ PASS
- **Rules (.ai-factory/RULES.md):** Rules cover Module Services / App.dart / DI — none of these constraints apply to this UI-layer change. ✅ PASS
- **Roadmap (.ai-factory/ROADMAP.md):** Not checked — caller did not request roadmap linkage. WARN (informational only).

## Critical Issues

### 1. Task 4 — LayoutBuilder placement guidance is contradictory and the "outer Column" alternative is broken math

The Context paragraph says:
> "replaced with an inner `LayoutBuilder` placed inside `Expanded` so the constraints actually reflect the area the inner column has to fit"

Task 4 first repeats that:
> "Inside the inner Column's first child Expanded, wrap its child Column with a LayoutBuilder…"

…then offers an alternative at the end:
> "hoist the layout computation: move the inner LayoutBuilder so it wraps the outer Column… (Either is acceptable as long as no `* scale` appears in `build()` and the constraints reflect the area that must fit.)"

These two placements are **not interchangeable**:

| Placement | `constraints.maxHeight` is | `scale` on Mi A1 (524dp SafeArea, ~64dp bottom bar) | Scaled inner content | Total (inner + bottom bar) | Overflow? |
|---|---|---|---|---|---|
| Inside `Expanded` (spec) | ≈ 524 − 64 = **460dp** | 460 / 652 ≈ 0.71 | 0.71 × 652 ≈ 460dp | 460 + 64 = 524 | **No** ✅ |
| Around outer `Column` (alternative) | full SafeArea ≈ **524dp** | 524 / 652 ≈ 0.80 | 0.80 × 652 ≈ 521dp | 521 + 64 = **585dp** | **Yes, ~61dp** ❌ |

The "hoist around outer `Column`" variant does not account for `SessionBottomBar`'s height in `_idealHeight`, so it under-estimates the overlap and the overflow that motivated this whole plan is **not fully fixed**.

**Required fix to the plan — pick one approach and remove the "either is acceptable" clause:**

- **Option A (preferred — matches the spec):** Place `LayoutBuilder` strictly inside `Expanded`. Bottom-bar `iconSize` cannot read `layout` from outside that scope, so either:
  - (a) Recompute `iconSize` separately for the bottom bar using the same `screenWidth` and a derived height (e.g. compute the scale once at the top of `build()` using `MediaQuery.of(context).size.height − padding`), or
  - (b) Hoist `layout` out of the `LayoutBuilder` via a `late final` captured in a local `Widget`-returning function, or
  - (c) Compute `layout` once at the top of `build()` from `MediaQuery.of(context).size.height − MediaQuery.of(context).padding.top − bottomBarBaseHeight`, drop the inner `LayoutBuilder` entirely, and pass `layout` to both subtrees. This is the cleanest pattern.

- **Option B (hoisted):** Keep `LayoutBuilder` around the outer `Column`, but extend `_idealHeight` to include the bottom-bar contribution and pass `MediaQuery.of(context).padding.bottom` into `BreathSessionLayout.compute`:
  ```dart
  static double _idealHeight(double screenWidth, double bottomInset) =>
      (screenWidth * _kShapeWidthRatio + _kShapePadding * 2)
      + (_kItemHeight * _kTimelineItems)
      + (_kButtonSize + _kButtonPadding * 2)
      + (_kIconSize + _kBottomBarVPadding * 2 + bottomInset);
  ```
  This requires Task 1 to add a `bottomInset` parameter and a `_kBottomBarVPadding = 8.0` constant.

As written, the plan permits Option B without the math fix — implementation following the plan literally will ship a still-overflowing layout on Mi A1.

## Issues

### 2. Task 3 — Use `IconTheme.merge`, not `IconTheme`

> "Wrap the existing `Row` in an `IconTheme(data: IconThemeData(size: iconSize), child: Row(...))`"

`IconTheme(data: IconThemeData(size: …))` replaces (does not merge) the ambient theme — every other `IconThemeData` field (`color`, `opacity`, `shadows`, `applyTextScaling`, fill/weight/grade/optical-size) becomes `null` for descendants. The bottom-bar `IconButton`s explicitly set `color` per button so visually nothing breaks today, but this is a footgun for later. Prefer:

```dart
IconTheme.merge(
  data: IconThemeData(size: iconSize),
  child: Row(...),
)
```

This preserves any ancestor theme values and is the idiomatic Material pattern.

### 3. Task 3 / Task 4 — Confirm `IconButton.iconSize` actually falls back to `IconTheme`

The plan relies on removing `iconSize: 28` from each `IconButton` and having them inherit the new `IconTheme` size. In current Flutter (3.x+), `IconButton.iconSize` defaults to `null` and resolves through `IconButtonTheme` → ambient `IconTheme` → 24dp. This works, **but** if the app ever introduces an `IconButtonTheme` with a non-null `iconSize` (e.g. via the global Material theme), the `IconTheme.size` we set here will be silently ignored. Low risk in this repo today, but worth a one-line comment in `SessionBottomBar` explaining the dependency, so a future theme refactor doesn't silently regress 16:9 layouts.

### 4. Task 4 — `MediaQuery.of` call should be hoisted above any conditional

> "Compute `final screenWidth = MediaQuery.of(context).size.width;` at the start of `build`"

Good. Just make sure this stays before any early `return` paths and before the `Scaffold` widget — the existing `build()` has none, so this is fine, but flag it if the body ever sprouts a loading branch.

### 5. Task 4 — Removing the outer `LayoutBuilder` is fine, but verify nothing else used `constraints`

The current outer `LayoutBuilder` exposes `constraints` but the body uses only `MediaQuery.of(context).size.width` and the local `screenWidth`. Confirmed by reading `BreathSessionScreen.dart` lines 136–244: `constraints` is not referenced anywhere inside the builder. Safe to remove. (Informational, not a problem with the plan.)

### 6. Task 2 — Font-ratio constants should be named, not magic

The plan introduces `itemHeight * 0.458` and `itemHeight * 0.333` directly in `_TimelineItem`. These ratios are `22/48` and `16/48` respectively. Defining them as `static const _kActiveFontRatio = 22.0 / 48.0;` (and equivalent for inactive) inside `_TimelineItem` makes the intent self-documenting and matches the project's preference for named constants over magic numbers. Not blocking, but it's an easy win and the file owns the constants instead of letting them drift if `_kItemHeight` ever changes.

### 7. Task 1 — `BreathSessionLayout._({...})` constructor signature is under-specified

The plan says "takes all six fields as required named parameters" — good. Make explicit that the constructor is `const` and that **all six fields must be `required`** (not just present). The snippet in note 03 uses `{...}` which is ambiguous. Implementor should produce:

```dart
const BreathSessionLayout._({
  required this.shapeDimension,
  required this.shapePadding,
  required this.itemHeight,
  required this.buttonSize,
  required this.buttonPadding,
  required this.iconSize,
});
```

Minor — a careful implementor will do this, but worth pinning down in the plan to remove ambiguity.

### 8. Task 4 — Tablet / very-wide screens

`_idealHeight` scales with `screenWidth`, so on a 600dp-wide screen ideal grows to `600*0.7 + 40 + 216 + 144 = 820dp`. If the device height is ≤820dp the scale clamps below 1.0 even though there's no overflow risk on tablets. This isn't a regression (current code is also fixed-ratio for shape), and `_kMinScale = 0.5` is a healthy floor, but flag for awareness — if anyone tests on a foldable in portrait, the shape may visibly shrink.

## Positive Notes

- The derivation of `_idealHeight` from the same constants used per-field is exactly right — no hand-maintained `652.0` to drift.
- Tying font size to `itemHeight` (Task 2) eliminates a separate scale parameter and keeps `_TimelineItem` self-contained.
- Architectural placement of the value object inside `packages/breath_module/` respects the module boundary; pure-Dart (no Flutter imports) is the right call for testability and ARCH layering.
- File path `packages/breath_module/lib/src/BreathSession/BreathSessionLayout.dart` matches existing PascalCase naming convention in the package.
- Commit split (value object + scalable params, then screen wiring) is sensible and reviewable.

## Verdict

Tighten Task 4 to remove the contradictory "either placement is acceptable" guidance, pick one approach (recommend Option A/c above: compute `layout` once at the top of `build()` from `MediaQuery` and pass it down), and small follow-ups on `IconTheme.merge` and named font-ratio constants. After that, the plan is implementable.

Re-plan, not pass.
