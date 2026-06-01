# Plan Review: Remove leftover `[Sound]` debug instrumentation

**Plan:** `105-remove-leftover-sound-debug-instrumentation.md`
**Target:** `packages/breath_module/lib/src/BreathSession/Audio/BreathSoundCoordinator.dart`
**Risk Level:** 🟢 Low

## Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** Present. Pure deletion of debug logs inside an existing module package; no boundary, DI, or dependency-direction impact. PASS.
- **Rules (`.ai-factory/RULES.md`):** Present. No convention conflicts — removing debug instrumentation aligns with normal cleanup. PASS.
- **Roadmap (`.ai-factory/ROADMAP.md`):** Not checked as blocking; this is a trivial `chore`-class cleanup with no milestone linkage required. WARN (non-blocking): consider noting the cleanup under the same milestone as the Phase 16 `[BREATH-PROBE]` removal if roadmap tracking is desired.

## Verification Against Codebase

The plan was checked line-by-line against the actual file:

- **`_ts()` helper at lines 9–13** — confirmed exact match. Top-level function, only ever called from the debug-log lines.
- **Enumerated `[Sound]` log lines** — all confirmed present and correctly located:
  - `initialize` → line 91 (`[Sound] initialize start`)
  - `_initAudio` → line 112 (`initialize ready — listeners attached`)
  - `_onStateChanged` status branch → lines 181 and 194
  - `_onStateChanged` phase branch → lines 211 and 215
  - `_onTick` → line 232
- **No omissions:** a search for `_ts(`, `[Sound]`, `kDebugMode`, `debugPrint` returns exactly 8 lines — the helper definition plus the 7 log lines. Nothing else references any of these symbols, so the deletion set is complete with no orphaned callers left behind.
- **Import retention is correct:** `package:flutter/foundation.dart` (line 3) must stay — `ValueNotifier` (line 31, `isMuted`) is exported from it. After removal, `kDebugMode`/`debugPrint` are no longer referenced, but the import remains validly used by `ValueNotifier`. The plan calls this out accurately.
- **`DateTime.now()`** is used only inside `_ts()`; removing the helper leaves no dangling time references.

## Critical Issues
None.

## Minor Notes
- After the edit, the dropped local variables `prev` (line 179) and `prev` (line 209) are each assigned solely for use in the deleted log strings. The plan's "pure deletion" instruction means these `final prev = ...` lines must also be removed, otherwise the analyzer will emit `unused_local_variable` warnings. Recommend the implementer treat `final prev = _currentStatus;` (line 179) and `final prev = _currentPhase;` (line 209) as part of the deletion set for the corresponding log lines. This is the one spot where "delete only the `debugPrint` line" is insufficient — the supporting variable goes with it.

## Positive Notes
- File paths, line numbers, and symbol names in the plan are all accurate.
- Scope is correctly constrained to a single file with no behavioral change.
- Import-retention reasoning is explicitly and correctly stated, pre-empting an easy mistake.
- Mirrors an established precedent (Phase 16 `[BREATH-PROBE]` removal), so the change pattern is proven.

The plan is sound. The only refinement is to ensure the two `final prev = ...` helper variables are removed alongside their log lines to avoid unused-variable analyzer warnings.

PLAN_REVIEW_PASS
