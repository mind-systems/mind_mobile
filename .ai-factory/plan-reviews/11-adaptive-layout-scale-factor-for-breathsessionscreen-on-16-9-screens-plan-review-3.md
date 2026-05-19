# Plan Review: Adaptive layout scale factor for BreathSessionScreen on 16:9 screens

**Plan:** `.ai-factory/plans/11-adaptive-layout-scale-factor-for-breathsessionscreen-on-16-9-screens.md`
**Spec:** `.ai-factory/notes/03-breath-session-adaptive-scale.md`
**Reviewer pass:** 3

## Summary

**Risk:** 🟢 Low

Iteration 3 cleanly resolves every blocker raised in review 2:

- **Critical 1 (bar height undercount):** Resolved. `kBottomBarBaseHeight = _kIconButtonMinTapTarget (48) + _kBottomBarVPadding*2 (16) = 64` is now the baseline; the prose explicitly explains why the bar's rendered height is dominated by the Material 48dp tap target and is independent of `iconSize`. The Mi A1 math now works: `availableHeight = 516 − (64 + 0) = 452`, `scale = 452 / 652 ≈ 0.693`, scaled content ≈ 452dp — fits exactly with zero overflow.
- **Critical 2 (`kBottomBarVPadding` not consumed):** Resolved. Task 3 now requires `SessionBottomBar` to consume `BreathSessionLayout.kBottomBarVPadding` directly for its inner padding, so the value-object contract and the widget's literal cannot drift apart.
- **Issue 4 (magic `4.5` in `build()`):** Resolved. Plan introduces a precomputed `timelineHeight` field on `BreathSessionLayout` (`_kItemHeight * _kTimelineItems * scale`) — Task 1 declares it among the seven fields and Task 4 consumes it as `layout.timelineHeight`. No `* 4.5` literal survives in `build()`.

The cross-checks all hold against the actual code:

- `BreathSessionScreen.dart` line 136 outer `LayoutBuilder` does not read `constraints` — only `MediaQuery.of(context).size.width` is used inside the body. Safe to remove. ✅
- `_TimelineItem` at line 168 of `BreathTimelineWidget.dart` matches the plan's target. The single call site is in `_buildList`'s `itemBuilder`. ✅
- `BreathTimelineWidget` already exposes `itemHeight` as a public constructor param (default 48.0); the screen passes the local `48.0` today — Task 4's `itemHeight: layout.itemHeight` is a drop-in. ✅
- `ControlButton` in `packages/mind_ui/lib/src/ControlButton.dart` paints `Icon(size: iconSize)` inside an `InkWell` with **no** min-size / tap-target enforcement — `buttonSize * 0.5` truly preserves the 40/80 ratio at every scale. ✅
- `SessionBottomBar` has exactly the three `IconButton`s with `iconSize: 28` enumerated by Task 4. No external callers exist. ✅
- Project search for `IconButtonTheme` / `iconButtonTheme` returns zero hits in `mind_mobile/` — no theme-level override will shadow `IconTheme.merge(IconThemeData(size: ...))`. ✅
- Public `kBottomBarBaseHeight` (= 64) is derived inside the value object from the same Material constant the prose justifies it with — no drift between the comment and the math.

One small inconsistency remains around `_buildControlButton`'s signature (see Issue 1). It is a clean-up nit, not a correctness or overflow problem. Not blocking — flag for the implementer.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Presentation-package-local change; pure-Dart value object inside `packages/breath_module/`; no `lib/` imports introduced; no domain leakage. The new dependency `SessionBottomBar → BreathSessionLayout` is intra-package and at the same layer. ✅ PASS
- **Rules (`.ai-factory/RULES.md`):** Project rules cover Module Services / `App.dart` wiring / DI; none apply to a UI-layer scaling refactor inside `packages/breath_module/`. ✅ PASS
- **Roadmap (`.ai-factory/ROADMAP.md`):** Roadmap linkage not requested by caller. WARN (informational).

## Critical Issues

None.

## Issues

### 1. `_buildControlButton`'s `iconSize` named parameter becomes dead

Task 4 instructs:

> change its signature to
> `Widget _buildControlButton(BreathSessionState state, BreathViewModel viewModel, {required double buttonSize, required double iconSize})`
> and replace the two hardcoded `SizedBox(width: 80, height: 80, …)` with `SizedBox(width: buttonSize, height: buttonSize, …)`. Replace the two hardcoded `iconSize: 40` inside `ControlButton(...)` with `iconSize: buttonSize * 0.5`

If the body of `_buildControlButton` writes `ControlButton(iconSize: buttonSize * 0.5, …)`, the **`iconSize` parameter on `_buildControlButton` is never read** — and Task 4 then says to pass `iconSize: layout.iconSize` at the two call sites, where it is silently discarded. That's a dead `required` parameter and a `dart analyze` `unused_element` smell.

Pick one:

- **Drop the parameter** (recommended, smallest diff): signature is `({required double buttonSize})`, body uses `buttonSize * 0.5`, call sites pass only `buttonSize: layout.buttonSize`. The "0.5 mirrors the original 40/80 icon-to-button ratio" comment stays — that's the whole story.
- **Use the parameter instead of `buttonSize * 0.5`:** declare and pass `iconSize`, and in the body write `ControlButton(iconSize: iconSize, …)`. Then the ratio computation moves to the call site (or — cleaner — into `BreathSessionLayout` as a new derived field `controlButtonIconSize = buttonSize * 0.5`). This is the "everything goes through the value object" variant.

Either is fine; the current plan text is internally inconsistent (declares a `required iconSize` it then never uses).

### 2. Separator height stays constant at 9dp while item rows scale

`BreathTimelineWidget._buildList` keeps `_buildSeparator` at `EdgeInsets.symmetric(vertical: 4)` + `height: 1` = 9dp, and `getItemScrollOffsetById` accounts for separators with the literal `9.0`. Neither scales with `itemHeight`.

This is **not** something this plan needs to fix — it's pre-existing behaviour and the plan is right to leave it alone — but two consequences are worth noting:

- The `_idealHeight` baseline (`_kItemHeight * _kTimelineItems` = 216dp) does **not** include separators, even though real sessions render them. At `scale = 1.0` this is harmless because the visible window is anyway `> 216dp` and the screen has slack. On Mi A1 at `scale ≈ 0.69`, the visible 4.5-row window shrinks to ~149dp but separators continue to consume 9dp each; if a session has many separators in the visible window, content density per row changes slightly. No overflow risk — the timeline frame is a fixed `SizedBox(height: layout.timelineHeight)` and the list scrolls inside it.
- `getItemScrollOffsetById`'s scroll-target math still computes correct *content-space* offsets because both `itemHeight` and the separator literal are content-space offsets inside the same scrollable. ✅

Flag for awareness only; no plan change.

### 3. `_buildList`'s `EdgeInsets.symmetric(vertical: widget.itemHeight)` scales correctly — confirmed

`ListView.builder(padding: EdgeInsets.symmetric(vertical: widget.itemHeight), …)` ties the top/bottom slack to one row height, and `getItemScrollOffsetById` initialises `double offset = widget.itemHeight;` to mirror it. With Task 2 scaling `widget.itemHeight` (it's `layout.itemHeight` passed from the screen), both stay in lockstep. The "2.5 visible rows inside a 4.5-row frame" relationship is invariant under scale. ✅

No plan change needed — Task 2's "no change to `_buildList` or `getItemScrollOffsetById`" is correct.

### 4. `SessionBottomBar` `Padding` keeps horizontal `left: 32, right: 32` unchanged

Task 3 rewrites only the vertical sides of `SessionBottomBar`'s `EdgeInsets.only(…)`. The `left: 32, right: 32` literals are out of scope and remain in place. That's fine — horizontal padding does not contribute to overflow — but worth a one-sentence note in Task 3 so a careless edit doesn't accidentally rewrite the whole `EdgeInsets.only(…)` block.

Minor wording nit, not blocking.

### 5. `MediaQuery.of(context)` rebuild behaviour confirmed

The plan removes the outer `LayoutBuilder` and relies on `MediaQuery.of(context)` rebuild for orientation / size / system-bar changes. `MediaQuery.of` registers the build context as a dependent on `_MediaQueryModel`, so any size/padding/textScaleFactor change re-runs `build()` and recomputes `layout` from fresh values. No `LayoutBuilder` is needed for that. ✅

### 6. Tablet/foldable caveat correctly deferred

`_idealHeight` grows with `screenWidth` (because the shape's contribution is `screenWidth * 0.7`), so on a 600dp-wide portrait device `_idealHeight` ≈ 820dp. If the device height is `< 820dp` even though there's no real overflow, the shape will visibly shrink. The plan calls this out in the Context block, the `_kMinScale = 0.5` floor bounds the worst case, and the 48dp bar baseline gives headroom. No tablet branch is needed in this milestone. ✅

## Positive Notes

- Critical Issue 1 from review 2 is resolved cleanly via the 48dp Material tap-target constant — and the explanatory prose in the Context block ("the rendered height of `SessionBottomBar` is dominated by the Material `IconButton` minimum tap target … the actual bar height is therefore `48 + 2·kBottomBarVPadding + mq.padding.bottom`, **independent of `iconSize`**") is exactly what a future reader needs to not regress this in a follow-up refactor.
- `_kIconButtonMinTapTarget = 48.0` is named, not magic; its derivation (M2 `_kMinButtonSize`; M3 `minimumSize 40` + `tapTargetSize: padded` ⇒ ~48dp) is documented as an inline comment.
- The `// Resolves via IconButton → IconButtonTheme → IconTheme. A non-null IconButtonTheme.iconSize anywhere up the tree will shadow this.` comment is a future-proofing guard worth keeping verbatim — searches confirm there is no `IconButtonTheme` in `mind_mobile/` today.
- `BreathSessionLayout.timelineHeight` as a precomputed field (Task 1 / Task 4 consume `layout.timelineHeight`) removes the last magic literal from `build()`. The constraint "no `* scale` multiplications and no magic numbers (e.g. `4.5`) appear anywhere in `build()`" is now achievable.
- `SessionBottomBar` consuming `BreathSessionLayout.kBottomBarVPadding` for its own padding means the value object's `kBottomBarBaseHeight = 64` math is anchored to the widget that actually renders the bar — no silent drift possible.
- `_idealHeight` derivation from the same constants used to scale each field eliminates the original `652.0` magic number and stays correct under any single-constant edit (e.g. if button size is bumped to 88dp later, `_idealHeight` updates automatically and `scale` re-balances).
- Commit split (Tasks 1–3 then Task 4) cleanly separates "introduce scaled API surface" from "wire it into the screen", which matches the dependency order and is reviewable in two passes.
- The pessimistic 48dp baseline does double duty: it (a) eliminates the bar-height undercount, and (b) acts as a safety margin against future changes to the bar's content (e.g. adding a label below the icons would still fit inside the 48dp tap target without requiring a constant bump).

## Verdict

Plan is implementable as written. The only follow-up before merging is Issue 1 (dead `iconSize` parameter on `_buildControlButton`) — picking either fix takes ~30 seconds and removes the inconsistency. Everything else is informational or already correct.

PLAN_REVIEW_PASS
