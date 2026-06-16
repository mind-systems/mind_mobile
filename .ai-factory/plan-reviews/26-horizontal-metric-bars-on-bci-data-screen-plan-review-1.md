# Plan Review: Horizontal metric bars on BCI data screen

**Plan:** `.ai-factory/plans/26-horizontal-metric-bars-on-bci-data-screen.md`
**Files Reviewed:** 2 target files + spec note + ROADMAP
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`):** OK. Change is confined to `packages/bci_module` presentation layer. `BciMetricBar` is a pure-Flutter stateless widget with no domain-model or notifier coupling, consistent with the module-boundary rule. No DTO, service, or notifier surface is touched.
- **Rules (`RULES.md`):** OK. The documented rules concern Module Services (statelessness, DI, App.dart purity) — none apply to a presentation widget change. No violations.
- **Roadmap (`ROADMAP.md`):** OK. Milestone "Horizontal metric bars on BCI data screen" (line 91) matches the plan one-to-one — layout, 24 px bar height, integer value display, 12 px inter-cell vs 4 px label-to-bar gap, unchanged colors/opacity/timing. Linkage is explicit.

## Verification Against Codebase

- **File paths correct.** `packages/bci_module/lib/src/BciData/Views/BciMetricBar.dart` and `packages/bci_module/lib/src/BciData/BciDataScreen.dart` both exist as referenced. Note: the plan correctly uses the `Views/` subpath, fixing the spec note's stale `BciData/BciMetricBar.dart` path.
- **Sole consumer confirmed.** Grep shows `BciMetricBar` is used only in `BciDataScreen.dart` (plus docs/plan/note). Keeping the constructor `required value` is safe — no other call sites, no tests reference it.
- **Current implementation matches the plan's description** of what to remove: `_barWidth`/`_maxBarHeight` constants, the `topLeft`/`topRight`-only border radius, and the vertical `Align(bottomCenter)` column. All accurately identified.
- **Screen layout matches.** Both sections currently use `Row(mainAxisAlignment: spaceEvenly, ...)` inside a `Padding(horizontal: 16)`, wrapped in `SingleChildScrollView`. The plan's claim that the scroll wrapper already satisfies the overflow requirement is correct — no extra scroll view needed.
- **LayoutBuilder sizing is sound.** Inside a vertical `Column`, each `BciMetricBar` receives the padded row's width as `constraints.maxWidth`; the inner `Row` (default `mainAxisSize.max`) expands to it, so `maxWidth * clamped` yields the intended full-width-relative bar. Layout reasoning holds.
- **Numeric expressions compile.** `(value ?? 0.0).clamp(...)` returns `num`; `maxWidth * clamped` and `clamped * 100` follow the same pattern already present in the existing file, so no new type issues.
- **Simplification noted:** the plan replaces the spec note's `mapIndexed`-based interleaving (which would need the `collection` package) with explicit `SizedBox(height: 12)` separators between literal children. This avoids a new import and is cleaner. Good call.

## Non-Blocking Observations

1. **Label overflow protection (minor).** The new cell's label `Text(label, style: bodyMedium)` has no `overflow`/`Flexible` handling, unlike the existing heart-rate row which wraps its label in `Flexible` + `TextOverflow.ellipsis`. Current labels are short ('Delta', 'Focus', etc.), but some localized emotion strings (e.g. cognitive control/self-control) could be long on narrow devices, producing a `Row` overflow next to the `Spacer` + value. Consider wrapping the label in `Expanded`/`Flexible` with ellipsis during implementation. Not a blocker given current label lengths.
2. **`textAlign: TextAlign.right` on the value Text is a no-op** in this layout — the value `Text` sizes to its content and the `Spacer` already pushes it right, so `textAlign` has nothing to align within. Harmless; carried over verbatim from the spec. Can be dropped, but no need to.

## Positive Notes

- Scope is tightly bounded to exactly two files with no cross-project, proto, or migration impact.
- Plan correctly carries forward the invariants the spec marks as unchanged (colors, opacity dim behavior, 400 ms/easeOut timing, ViewModel normalization).
- Settings (no tests, minimal logging, no docs) are appropriate for a self-contained UI restyle.
- Single-commit guidance with a suitable message; commit prefix-free per project convention.

The plan is solid, accurate against the codebase, and implementable as written. The two observations above are optional refinements, not blockers.

PLAN_REVIEW_PASS
