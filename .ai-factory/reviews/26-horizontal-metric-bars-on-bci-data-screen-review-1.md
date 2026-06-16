# Code Review: Horizontal metric bars on BCI data screen

**Plan:** `.ai-factory/plans/26-horizontal-metric-bars-on-bci-data-screen.md`
**Files reviewed (in full):**
- `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart`
- `packages/bci_module/lib/src/BciData/BciDataScreen.dart`

**Verdict:** 🟢 No bugs, security, or correctness problems found.

## Correctness analysis

- **`BciMetricBar` rewrite is correct.** The widget now reads `constraints.maxWidth` via `LayoutBuilder`, computes `clamped = (value ?? 0.0).clamp(0.0, 1.0)`, and renders `width: maxWidth * clamped`. `double * num` resolves to `double` (Dart's `double.operator *` accepts `num`, returns `double`), so the `AnimatedContainer.width` assignment type-checks — same expression form the previous implementation already used (`_maxBarHeight * clamped`). No new type issues.
- **Null handling is sound.** `value == null` → `valueText = '--'`, opacity `0.3`, and `clamped = 0.0` so the bar collapses to `width: 0` (height 24). No null deref; the `AnimatedContainer` animates from/to width 0 cleanly.
- **`borderRadius: 12` with `height: 24`** yields a pill cap; when the animated width is below the radius, Flutter clamps the radius automatically — no render exception.
- **`LayoutBuilder` constraints are bounded.** The bar sits inside a vertical `SingleChildScrollView → Padding → Column`, which constrains width to the viewport (minus 16+16 outer and 16+16 section padding) and leaves only height unbounded. `constraints.maxWidth` is therefore finite — no "unbounded width" assertion risk.
- **Screen layout change is correct.** Both sections swapped `Row(spaceEvenly)` → `Column(crossAxisAlignment: start)` with `SizedBox(height: 12)` between cells and no trailing spacer, exactly as specified. The outer `SingleChildScrollView` (pre-existing) absorbs the now-taller content; the added vertical extent (10 cells × ~50px + gaps) is well within a scrollable column. No overflow.
- **Invariants preserved.** Metric colors, the 400 ms / `Curves.easeOut` timing on both the opacity fade and the width animation, and the null-dim behavior (now via `AnimatedOpacity` instead of the prior `AnimatedOpacity` + `opacity` local — functionally identical) are all unchanged. ViewModel normalization untouched.
- **Dead code removed cleanly.** `_barWidth` / `_maxBarHeight` constants and the `topLeft`/`topRight` border radius are gone with no dangling references. `BciMetricBar` has a single consumer (`BciDataScreen`); the `required value` signature is unchanged, so no call site breaks.

## Non-blocking observations (not defects)

1. **Label `Text` has no `Flexible`/ellipsis guard.** Inside the cell `Row`, `Text(label)` + `Spacer` + `Text(value)`: a label wider than the available main-axis space would trigger a `RenderFlex` overflow. Verified this does **not** occur with the actual labels — the longest is `"Cognitive load"` (RU: `"Расслабление"`), and the row now spans the full padded screen width (~290dp+), leaving large headroom versus the prior 36px box. Worth wrapping the label in `Expanded`/`Flexible` with `TextOverflow.ellipsis` only if longer labels are added later. No action required now.
2. **`textAlign: TextAlign.right` on the value `Text` is a no-op** — the `Text` sizes to its content and the `Spacer` already right-aligns it, so there is nothing to align within. Harmless, carried over from the spec verbatim.

Both items are cosmetic/forward-looking and do not affect current behavior.

REVIEW_PASS
