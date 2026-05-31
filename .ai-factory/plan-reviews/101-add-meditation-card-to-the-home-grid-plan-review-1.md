# Plan Review: Add meditation card to the Home grid

**Plan:** `101-add-meditation-card-to-the-home-grid.md`
**Files Reviewed:** 8 (plan + 7 target/dependency files)
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Plan respects the layered boundary — UI (`HomeScreen`) → ViewModel (`HomeViewModel`) → Coordinator (`IHomeCoordinator` / `HomeCoordinator`). The new `openMeditation()` follows the exact same path as `openBreath()`, and navigation/side-effects stay in the coordinator. No boundary violation. **PASS**
- **Rules (`.ai-factory/RULES.md`):** Not present — non-blocking. The plan does honor the project memory rule about using `/usr/local/bin/flutter` (referenced in Task 2). **WARN (file absent)**
- **Roadmap (`.ai-factory/ROADMAP.md`):** Not checked into review scope; this is a small wiring milestone. No explicit linkage required for a single UI-wiring change. **WARN (linkage not verified)**

## Verification of Plan Assumptions

Every factual claim in the plan was checked against the codebase and holds:

| Claim | Status |
|---|---|
| `meditation_module` is already a dependency | ✅ `pubspec.yaml:45-46` (`path: packages/meditation_module`) |
| `/meditation_list` route already registered | ✅ `router.dart:55-59` uses `MeditationListScreen.path` |
| `MeditationListScreen.path` exists and is public | ✅ `MeditationListScreen.dart:11-12` → `static String path = '/$name'` (`/meditation_list`) |
| Asset `assets/images/modules/home/meditation.png` exists | ✅ file present (161 KB) and folder `assets/images/modules/home/` is declared in `pubspec.yaml:113` |
| `homeTabBreath` / `homeTabMind` exist in both ARB files | ✅ `app_en.arb:67-68`, `app_ru.arb:61-62` |
| Generated getters exist for siblings | ✅ `app_localizations.dart:399/405`, `_en.dart:167/170`, `_ru.dart:168/171` |
| `IHomeCoordinator` has `openBreath()` to mirror | ✅ `IHomeCoordinator.dart:2` |
| `HomeViewModel` has `onBreathTap`/`onComingSoonTap` | ✅ `HomeViewModel.dart:76-77` |
| Grid renders `modules.length` cells, `crossAxisCount: 2` | ✅ `HomeScreen.dart:45-54` — growing to 4 needs no layout change |

## Critical Issues

None.

## Minor Notes (non-blocking)

1. **Grid item count vs. plan narrative.** The current grid has 3 items (Breath, Mind, Profile) — there is no separate "Mind" content card beyond the coming-soon `bci.png` tile. The plan's Task 6 says insert "between the Breath and Mind entries" to yield "Breath, Meditation, Mind, Profile". That matches the actual list exactly (the second entry titled `homeTabMind` maps to `onComingSoonTap`). No action needed, but be aware the "Mind" tile is currently a coming-soon placeholder, not a finished module — ordering is still correct.

2. **L10n codegen output location.** `packages/mind_l10n/l10n.yaml` sets `arb-dir: lib/l10n` with `synthetic-package: false` and no `output-dir`, so generated files land in `lib/l10n` — exactly the committed files Task 2 expects to update. Running `flutter gen-l10n` from `packages/mind_l10n` is correct. The manual-fallback instruction (mirror the three `homeTabBreath` getters) is a sound safety net.

3. **`l10n.yaml` template is `app_en.arb`.** Task 1 must keep EN as the source of truth (it adds the key to both, which is fine); just ensure the EN entry is well-formed JSON (comma placement) since it is the template that drives codegen.

## Positive Notes

- Tasks are correctly ordered with explicit dependencies (l10n → interface → impl/VM → UI).
- The plan reuses the existing coordinator/ViewModel pattern verbatim rather than inventing new wiring — fully consistent with the module-system architecture.
- No database/Drift schema change is involved, so no migration is needed — the plan correctly omits one.
- No security surface is touched (pure local navigation + a static asset + a localized string).
- File paths and API usage (`context.push`, `MeditationListScreen.path`, `ModuleItem` shape) are all accurate against the real code.

PLAN_REVIEW_PASS
