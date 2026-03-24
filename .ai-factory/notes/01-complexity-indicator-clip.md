# ComplexityIndicator — Clip Without Overflow Warning

**Date:** 2026-03-24
**Source:** conversation context

## Key Findings

- The current `SingleChildScrollView` is a workaround: it suppresses Flutter's overflow warning by letting the `Row` scroll, but creates a redundant `Scrollable` per list cell.
- The correct solution is `OverflowBox` + `ClipRect`: `OverflowBox` gives the inner `Row` a wider constraint (full 100px), `ClipRect` clips visually to the outer `SizedBox` width — no overflow warning, no extra `Scrollable`.
- `OverflowBox` is the right tool here because the overflow happens at **layout time**, not paint time. `ClipRect` alone doesn't help since Flutter complains before clipping.

## Details

### Current implementation (file: `packages/breath_module/lib/src/Widgets/ComplexityIndicator.dart`)

```
SizedBox(width: _revealWidth, height: _iconSize)
└── SingleChildScrollView(physics: NeverScrollableScrollPhysics)   ← suppresses warning
    └── Row [5 × Icon(Icons.self_improvement)]                      ← 100px total
```

**Problem:** creates a full `Scrollable` (with `ScrollPosition`, `ScrollController`, viewport) for every list cell just to suppress a layout warning.

### Proposed replacement

```
SizedBox(width: _revealWidth, height: _iconSize)
└── ClipRect
    └── OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: _totalWidth,   // = 100px (5 × 20px)
          maxHeight: _iconSize,
        )
        └── Row [5 × Icon(Icons.self_improvement)]
```

**How it works:**
- `OverflowBox` passes `maxWidth: 100` down to `Row`, so `Row` lays out happily at full width.
- `ClipRect` clips the painted output to the `SizedBox` bounds (`_revealWidth`).
- No overflow warning — Flutter never sees a constraint violation.
- No `Scrollable` — zero scroll infrastructure overhead.

### Visual

```
  _revealWidth (e.g. 60px)
 ┌──────────────────┐╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
 │  SizedBox        │
 │  ┌──── ClipRect ─┼──────────────────────┐
 │  │  🧘  🧘  🧘  │  🧘  🧘             │
 │  └──────────────-┼──────────────────────┘
 └──────────────────┘╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌
    visible            clipped, no warning
```

### Why `OverflowBox` specifically

`ClipRect` operates at **paint** time — it clips what gets drawn. But Flutter's overflow error is a **layout** error: `RenderFlex` complains when its children don't fit the tight constraints given to it. `OverflowBox` intercepts at layout time and gives the child looser constraints, so `RenderFlex` never sees a violation.

## Open Questions

- Whether `Align` wrapping is needed inside `OverflowBox` to anchor icons to the left — depends on `Row`'s default alignment in an unconstrained horizontal axis.
