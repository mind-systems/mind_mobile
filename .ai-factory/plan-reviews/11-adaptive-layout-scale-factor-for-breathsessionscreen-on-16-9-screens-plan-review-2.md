# Plan Review: Adaptive layout scale factor for BreathSessionScreen on 16:9 screens

**Plan:** `.ai-factory/plans/11-adaptive-layout-scale-factor-for-breathsessionscreen-on-16-9-screens.md`
**Spec:** `.ai-factory/notes/03-breath-session-adaptive-scale.md`
**Reviewer pass:** 2

## Summary

**Risk:** 🟡 Medium

Iteration 2 addresses every issue flagged in review 1 cleanly: Option A/c is locked in, `IconTheme.merge` replaces the plain `IconTheme`, font ratios are named constants, the `const`/`required` constructor is pinned down, public `kIconSize`/`kBottomBarVPadding` are exposed exactly for the `bottomBarBaseHeight` computation, and `_idealHeight` is derived (no hardcoded 652). The math for the inner column is sound and the layout value-object placement respects the package boundary.

However, the revised plan **repeats the same class of mistake review 1 warned about** in a new place: `bottomBarBaseHeight = kIconSize + 2·kBottomBarVPadding + bottomInset` (i.e. `44 + bottomInset`) does **not** equal the actual rendered height of `SessionBottomBar`, because each `IconButton` enforces a Material minimum render size that is independent of its `iconSize`. The actual bar is ~20dp taller. The plan calls this an "overcount" — it's an undercount, and on Mi A1 it leaves a residual ~20dp overflow exactly as in Option B from review 1.

This needs to be fixed in Task 1 / Task 4 before implementation. Everything else is implementable as written.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Change is presentation-package-local; pure-Dart value object inside `packages/breath_module/`; no `lib/` imports; no domain leakage. ✅ PASS
- **Rules (`.ai-factory/RULES.md`):** Project rules cover Module Services / App.dart wiring / DI — none of those constraints apply to a UI-layer scaling refactor. ✅ PASS
- **Roadmap (`.ai-factory/ROADMAP.md`):** Roadmap linkage not requested by caller. WARN (informational).

## Critical Issues

### 1. `bottomBarBaseHeight` undercounts the real bar by ~20dp — overflow on Mi A1 remains

The plan computes:
```dart
final bottomBarBaseHeight =
    BreathSessionLayout.kIconSize +              // 28
    BreathSessionLayout.kBottomBarVPadding * 2 + // 16
    mq.padding.bottom;                            // 0 on Mi A1
// → 44 + bottomInset
```
and claims this **over-counts** the bar at small scales ("the actual scaled icon will be smaller").

That claim is wrong. `SessionBottomBar.actions` are stock Material `IconButton`s with no `style:` override, and an `IconButton`'s rendered height is **not** `iconSize + 2·outerPadding`. It is dominated by the button's Material minimum-size + tap-target constraints:

- Material 2 `IconButton`: `ConstrainedBox(minWidth: 48, minHeight: 48)` (constant `_kMinButtonSize = kMinInteractiveDimension = 48`).
- Material 3 `_IconButtonM3` (the default in this app — `AppTheme` constructs `ThemeData(...)` without `useMaterial3: false`, so M3 is on for Flutter 3.16+): `_IconButtonDefaultsM3.minimumSize = Size(40, 40)`, plus `tapTargetSize: MaterialTapTargetSize.padded` adds 8dp around it ⇒ effective rendered height ≈ 48.

In both cases the `IconButton`'s rendered height is **≥ 40–48dp regardless of `iconSize`**. The bar's measured height is therefore:

```
sessionBottomBar.height
  = max(iconButton.renderedHeight) + outerPadding.vertical + mq.padding.bottom
  ≈ 48 + 16 + bottomInset
  = 64 + bottomInset
```

not `44 + bottomInset`.

**Concrete impact on Mi A1 (the device this plan exists to fix):**

| Quantity | Value |
|---|---|
| `mq.size.height − mq.padding.top` (visible inside SafeArea) | ~516dp |
| Actual `SessionBottomBar` height (`48 + 16 + 0`) | 64dp |
| Actual inner `Expanded` space | **452dp** |
| Plan's `availableHeight` (`516 − 44`) | **472dp** |
| `_idealHeight` at 360dp width | 652dp |
| Plan's `scale` (`472 / 652`) | 0.724 |
| Scaled inner content total (`0.724 × 652`) | 472dp |
| **Residual overflow** (`472 − 452`) | **≈ 20dp** |

This is the same failure mode review 1 called out for Option B ("hoist `LayoutBuilder` around outer Column") — the bottom bar's true height is under-counted, so `scale` is too large and the inner column still overflows. The bug just shifted from "wrong placement of `LayoutBuilder`" to "wrong baseline constant inside `bottomBarBaseHeight`".

**Pick one of three fixes (recommend Option A):**

- **Option A — pessimistic baseline (smallest diff, recommended):** Treat the bar as 48dp (M3 padded tap target / M2 `_kMinButtonSize`) regardless of icon scale. Add a constant to `BreathSessionLayout` and use it directly:
  ```dart
  // BreathSessionLayout
  static const double _kIconButtonMinTapTarget = 48.0; // Material default
  static const double kBottomBarBaseHeight =
      _kIconButtonMinTapTarget + _kBottomBarVPadding * 2; // 64
  ```
  ```dart
  // BreathSessionScreen.build
  final bottomBarBaseHeight =
      BreathSessionLayout.kBottomBarBaseHeight + mq.padding.bottom;
  ```
  The `kIconSize` / `kBottomBarVPadding` public constants can stay (they still scale the icon paint size) but the **bar-height baseline** stops referencing `kIconSize`. Update the "deliberately conservative" comment to reflect what's actually conservative: "matches Material's enforced 48dp tap target so the bar baseline holds even at min scale."

- **Option B — shrink the bar to actually match `iconSize`:** Pass each `IconButton`
  ```dart
  IconButton(
    style: IconButton.styleFrom(
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    ),
    ...
  )
  ```
  so that the bar's actual height becomes `iconSize + 16 + bottomInset` and matches the plan's formula. **Not recommended** — this also shrinks the tap targets below the Material guideline at small scales (e.g. 14×14 at `scale = 0.5`), regressing touch accessibility on the very devices this plan targets.

- **Option C — measure the bar with a `LayoutBuilder`/`SafeArea`/`Builder` and subtract it dynamically.** Adds back the `LayoutBuilder` the plan was at pains to remove; not worth it given how cheap Option A is.

Whichever option is picked, also update the plan's prose ("slightly over-counts the bar on small screens (the actual scaled icon will be smaller), giving the inner column a small safety margin and guaranteeing no overflow") — that sentence is currently both factually wrong **and** would be a misleading comment to leave in the source code as a justification.

### 2. The exposed `kBottomBarVPadding = 8` is not actually consumed by `SessionBottomBar`

`BreathSessionLayout` will expose `kBottomBarVPadding = 8.0`, but `SessionBottomBar.dart` continues to hardcode `top: 8, bottom: 8 + mq.padding.bottom` in its own `Padding`. So the layout value object is asserting a contract ("bar vertical padding = 8") that the bar widget independently re-asserts with a literal. If anyone changes one in the future without the other, the bar height estimate silently drifts.

Either (a) make `SessionBottomBar` consume `BreathSessionLayout.kBottomBarVPadding` for its inner padding, or (b) drop `kBottomBarVPadding` from the public surface and inline the `8` in the screen's `bottomBarBaseHeight` calculation with a comment pinning the relationship. (a) is cleaner and the value object is already imported via the screen — but it does mean `SessionBottomBar` depends on `BreathSessionLayout`, which is fine since they live in the same package and at the same layer.

Not blocking by itself, but worth fixing alongside Critical Issue 1 since both are about the bar height being expressed in two places.

## Issues

### 3. `_buildList` `padding: EdgeInsets.symmetric(vertical: widget.itemHeight)` interacts with the scaled `itemHeight`

`BreathTimelineWidget._buildList` uses `padding: EdgeInsets.symmetric(vertical: widget.itemHeight)`, so the ListView's top/bottom padding equals one row height. With `itemHeight` scaled (e.g. `48 → 38` at `scale = 0.80`), the padding shrinks proportionally. That keeps the "2.5 items visible inside the 4.5-row-tall frame" relationship invariant, which is good.

It also means `getItemScrollOffsetById` (which initialises `double offset = widget.itemHeight;` to mirror that top padding) continues to return correct content-space offsets without changes. ✅

Not a problem with the plan — just noting that no Task 2 change to `_buildList` or `getItemScrollOffsetById` is needed, and the plan correctly does not touch them.

### 4. `_kTimelineItems = 4.5` is referenced twice but inlined as a magic number in one of them

Task 4 says: "The timeline wrapper `SizedBox` uses `height: layout.itemHeight * 4.5` (replace the local `timelineHeight` and the `// todo copypaste` comment)."

`4.5` is the same value as `BreathSessionLayout._kTimelineItems` and is used inside `_idealHeight` already. Leaving a hardcoded `4.5` in `BreathSessionScreen.build()` re-introduces exactly the kind of magic-number duplication the rest of the plan is taking pains to eliminate. Either:

- Expose `_kTimelineItems` as another public constant on `BreathSessionLayout` (e.g. `kTimelineItems`) and use it: `height: layout.itemHeight * BreathSessionLayout.kTimelineItems`, or
- Add a pre-computed `final double timelineHeight` field on `BreathSessionLayout` (scaled = `_kItemHeight * _kTimelineItems * scale`) and use `layout.timelineHeight`.

The second option matches how every other dimension in this file is consumed (`layout.shapeDimension`, `layout.itemHeight`, `layout.buttonSize`, …) and removes the last `* literal` arithmetic from `build()`. Minor, not blocking.

### 5. `scrollController` jumping during transient layout changes

When `availableHeight` shrinks (e.g. system bar height changes on rotation, or device chrome reflow), `itemHeight` shrinks, all `_itemKeys` invalidate their offsets, and `_scrollToActive` is only called on `activeStepId` changes. This means the timeline can end up scrolled to a stale offset until the next active step boundary. Not a regression introduced by this plan — current code has the same property — but flag for awareness: if QA tries rotation or display-size changes during a session, the timeline may briefly look misaligned until the next phase. No action required for this milestone.

### 6. `ControlButton.iconSize = buttonSize * 0.5` is correct but worth a one-line comment

Task 4 replaces both `iconSize: 40` literals inside `ControlButton(...)` with `iconSize: buttonSize * 0.5`. This preserves the `40/80 = 0.5` ratio at `scale = 1.0`. `ControlButton` itself just paints an `Icon(size: iconSize)` inside an `InkWell` with no min-size constraint (verified in `packages/mind_ui/lib/src/ControlButton.dart`), so the ratio holds at all scales. Add a one-line comment at the call site: `// 0.5 mirrors the original 40/80 icon-to-button ratio.` — makes intent self-documenting once the literal is gone.

### 7. Confirming `IconTheme.merge` actually feeds M3 `IconButton.iconSize`

Sanity check, since the plan depends on it. In M3, `_IconButtonDefaultsM3` resolves `iconSize` via `MaterialStatePropertyAll<double>(_iconTheme.size ?? 24.0)` where `_iconTheme = IconTheme.of(context)`. With `iconSize: null` on the `IconButton` (i.e. the plan's "remove the three hardcoded `iconSize: 28` lines"), the default style wins and pulls from the ambient `IconTheme.size`. Wrapping the `Row` in `IconTheme.merge(data: IconThemeData(size: layout.iconSize), child: ...)` therefore correctly drives every descendant `IconButton`. ✅

(M2 path: `IconButton.M2.build()` does `widget.iconSize ?? IconTheme.of(context).size ?? 24.0` directly — same outcome.)

Project search for `IconButtonTheme`/`iconButtonTheme` found zero hits in `mind_mobile/`, so there's no theme-level `iconSize` that would shadow `IconTheme.merge`. The one-line comment Task 3 plans to add ("a non-null `IconButtonTheme.iconSize` anywhere up the tree will shadow this") is correct and worth keeping as a guard against future regressions.

### 8. `SessionBottomBar` `iconSize` default of 28 is fine for callers outside this screen

`SessionBottomBar` is currently used only by `BreathSessionScreen`, but defaulting `iconSize` to `28.0` preserves the contract for any future caller that doesn't compute a `BreathSessionLayout`. ✅ The fact that the screen will always pass an explicit value while the default exists for external callers is the right shape for a package-level widget.

## Positive Notes

- Option A/c is now unambiguous: `layout` computed exactly once at the top of `build()` from `MediaQuery`, no `LayoutBuilder` reintroduced anywhere, both subtrees consume the same value object. Resolves review 1's primary critical issue cleanly.
- `IconTheme.merge` replaces the plain `IconTheme` and is correctly accompanied by an explanatory comment about `IconButtonTheme` shadowing.
- Public exposure of `kIconSize` (and intended `kBottomBarVPadding`) for use by `BreathSessionScreen`'s baseline computation eliminates magic-number duplication between the value object and its consumer.
- `_idealHeight` derivation from constants (no hardcoded `652.0`) eliminates drift if any single constant changes — explicit, testable, and matches the design intent stated in note 03.
- Named font ratios `_kActiveFontRatio = 22.0 / 48.0` and `_kInactiveFontRatio = 16.0 / 48.0` inside `_TimelineItem` document the original 22/16 pair and self-scale with `itemHeight`. Clean.
- `BreathSessionLayout._({required ...})` constructor pinned down as `const` with every field `required` — removes review 1's "constructor signature is under-specified" ambiguity.
- The tablet/foldable caveat is now called out informationally in the Context section; `_kMinScale = 0.5` is the right floor for this milestone, and a dedicated tablet branch is correctly deferred.
- Commit split (value object + leaf-widget params, then screen wiring) is reviewable and matches the dependency order.

## Verdict

Critical Issue 1 must be fixed before implementation — pick Option A (pessimistic 48dp bar baseline) and update both the `bottomBarBaseHeight` computation and the "deliberately conservative" comment to reflect the actual Material `IconButton` minimum tap target. Critical Issue 2 (`kBottomBarVPadding` exposed but unused by `SessionBottomBar`) should be resolved in the same pass. Issue 4 (magic `4.5` in `build()`) is a small follow-up worth doing alongside.

Everything else is implementable as written; the rest of the plan is solid.

Re-plan, not pass.
