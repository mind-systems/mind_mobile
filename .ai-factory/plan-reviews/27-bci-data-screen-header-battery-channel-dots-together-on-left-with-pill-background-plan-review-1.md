# Plan Review: BCI data screen header — battery + channel dots together on left with pill

**Plan:** `27-bci-data-screen-header-battery-channel-dots-together-on-left-with-pill-background.md`
**Risk Level:** 🟢 Low

## Verification against codebase

- **File path** — `packages/bci_module/lib/src/BciData/Views/BciDataHeader.dart` exists and is the right widget. ✅
- **Line references** — outer `Row` at lines 77–98, class doc comment at lines 18–19, `channelRow` definition and dot sizing (8×8, `SizedBox(width: 4)`) all match the actual file. ✅
- **Edit target** — `const Spacer(), channelRow,` (lines 96–97) is exactly what the plan rewrites. The replacement snippet (`SizedBox(8)` → `Container` pill → `Spacer`) is well-formed and `child: channelRow` preserves the existing dot widget unchanged. ✅
- **`context` availability** — confirmed; `build(BuildContext context, WidgetRef ref)` is in scope. ✅
- **`Theme.of(context).cardColor`** — valid token defined in `mind_ui/AppTheme.dart` (`_kCardDark` / `_kCardLight`) and used across packages. ✅
- **Spec-note path correction** — the plan correctly flags that the spec references `BciDataScreen.dart` but the header lives in `Views/BciDataHeader.dart`. Good catch; prevents a wrong-file edit. ✅

## Context Gates

- **Architecture** — `.ai-factory/ARCHITECTURE.md` present. Change is confined to a presentation-package view; no boundary/dependency violation (no domain import, no cross-layer leak). WARN: none.
- **Rules** — `.ai-factory/RULES.md` present. No convention conflict in a pure-widget layout tweak. WARN: none.
- **Roadmap** — `.ai-factory/ROADMAP.md` present. This is a UI-polish `feat` with no matching open milestone entry. WARN (non-blocking): no explicit roadmap linkage; consistent with prior small BCI UI tweaks that were tracked under Phase 30 — consider logging it there for history, but not required.

## Minor Notes (non-blocking)

- The plan states `cardColor` is "the same token `SessionBottomBar` uses." Accurate that the *token* is identical, but `SessionBottomBar` applies it at `cardColor.withValues(alpha: 0.3)` (verified at `SessionBottomBar.dart:20`), whereas this pill uses solid `cardColor`. Solid is a deliberate, reasonable choice for a small pill and produces a more visible background; just be aware the visual weight will differ from the breath bar. No change required.
- `Settings: Logging minimal / Docs no / Testing no` are appropriate for a layout-only change. The class doc comment update (lines 18–19) is correctly included so the "on the right" description doesn't go stale.

## Conclusion

Single-file, single-task layout change. File path, line numbers, widget structure, and theme token all verified against the live codebase. No missing steps, wrong assumptions, architectural issues, or migrations. The plan even pre-empts the one trap (wrong file named in the upstream spec).

PLAN_REVIEW_PASS
