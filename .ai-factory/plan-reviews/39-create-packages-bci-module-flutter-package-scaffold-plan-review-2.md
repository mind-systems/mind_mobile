# Plan Review: 39 — Create `packages/bci_module/` Flutter package scaffold (iteration 2)

**Plan file:** `.ai-factory/plans/39-create-packages-bci-module-flutter-package-scaffold.md`
**Prior review:** `.ai-factory/plan-reviews/39-create-packages-bci-module-flutter-package-scaffold-plan-review-1.md`

## Context Gates

- **ROADMAP.md (line 89)** — PASS. Plan matches the Phase 17 milestone verbatim — `flutter create --template=package`, dep list (`flutter`, `flutter_riverpod: ^3.0.0`, `just_audio: ^0.10.5`, `mind_l10n`, `mind_ui`), root pubspec wiring, empty barrel, and the `lib/src/BciPairing/Models/` directory.
- **ARCHITECTURE.md** — PASS. `lib/src/BciPairing/` follows the same PascalCase subdirectory pattern as `packages/breath_module/lib/src/BreathSession/`. No domain leak risk in a scaffold-only milestone.
- **RULES.md** — Not applicable to scaffolding. The three rules (stateless module services, App.dart kept infra-only, constructor DI) apply only to subsequent milestones that add code.
- **CLAUDE.md (mobile)** — Aligned with the "modules are standalone Flutter packages" rule.

## Resolution of Prior Review Findings

| # | Prior finding | Status in v2 |
|---|---|---|
| 1 | CRITICAL — auto-generated `test/bci_module_test.dart` would break `flutter analyze` after the barrel is wiped | **RESOLVED.** New Task 4 explicitly deletes the file and explains the compile-failure reasoning. |
| 2 | `.gitkeep` justification was inaccurate (no precedent in repo) | **RESOLVED.** Task 5 now correctly notes "no other package in `mind_mobile` currently uses `.gitkeep`" and frames it as the standard Git idiom. |
| 3 | `just_audio` likely unused in scaffold | **ACKNOWLEDGED.** Plan keeps the dep and cites ROADMAP.md line 89, which explicitly lists `just_audio: ^0.10.5` in the milestone spec. Defensible choice — the roadmap text is authoritative. |
| 4 | Redundant `pub get` (in-package + root) | **RESOLVED.** Task 7 runs `flutter pub get` only once from the repo root. |
| 5 | Wrong "alphabetical" wording for module list ordering | **RESOLVED.** Task 6 now says "Match the insertion-order grouping … no alphabetical sort." |

## Critical Issues

None.

## Non-Critical Observations

### A. Task 2 reference is partially imprecise (NIT)

Task 2 says "the same structure used by `packages/breath_module/pubspec.yaml`" but then adds `dev_dependencies` (`flutter_test`, `flutter_lints: ^6.0.0`) and an empty `flutter:` section — neither of which exists in `breath_module/pubspec.yaml`. Both *do* exist in `mind_audio/pubspec.yaml`, so the reference should mention both packages, or simply state the desired content without claiming a single template. Implementation is unaffected.

### B. "Leave the empty test/ directory in place" (NIT)

Task 4 instructs to leave the `test/` directory after deleting the only file in it. Git does not track empty directories, so this instruction is a no-op — the directory will not be present in the next clone. Harmless; could just be removed.

### C. Task 5 — empty `Models/` directory is created purely for git tracking

The chosen `.gitkeep` approach is fine. An equally valid alternative is to drop the empty directory entirely and let the next milestone (which actually adds DTO files under `Models/`) create it implicitly. The milestone spec on ROADMAP.md line 89 explicitly says "Create dir `lib/src/BciPairing/Models/`", so the plan is justified in honouring it — but the only practical effect of `.gitkeep` is making the empty directory survive a fresh clone. Not a defect.

## Positive Notes

- All blocking and non-blocking items from review 1 are addressed concretely, not hand-waved.
- Task 4's reasoning is excellent — it spells out *why* the deletion is required (placeholder `Calculator` reference disappears in Task 3, breaking Task 7's `flutter analyze`).
- Task ordering and inter-task dependencies (`depends on Task 1`, `depends on Tasks 2–5`, `depends on Task 6`) are explicit and correct.
- Dep versions (`flutter_riverpod: ^3.0.0`, `just_audio: ^0.10.5`, environment `>=3.7.0 <4.0.0` / flutter `>=3.0.0`) match neighbouring packages — no version drift introduced.
- Root pubspec insertion point (after `mind_audio` block at lines 41–42) is verified accurate against the current file.
- Plan correctly avoids touching subsequent milestone scope (no premature ViewModel, Service interfaces, screens, or l10n keys).
- Anchors ROADMAP.md line 89 as the source of truth for the `just_audio` dependency — a citation that withstands scrutiny.

## Required Changes Before PASS

None — the plan is implementation-ready.

PLAN_REVIEW_PASS
