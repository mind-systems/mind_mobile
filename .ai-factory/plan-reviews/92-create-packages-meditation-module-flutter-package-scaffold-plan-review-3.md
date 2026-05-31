# Plan Review (3): Create `packages/meditation_module` Flutter package scaffold

**Plan:** `92-create-packages-meditation-module-flutter-package-scaffold.md`
**Files cross-checked:** `packages/breath_module/{pubspec.yaml,lib/breath_module.dart}`, `packages/bci_module/{pubspec.yaml,lib/bci_module.dart,analysis_options.yaml,test/}` (most recent analogous scaffold), root `pubspec.yaml`, `packages/mind_ui` / `packages/mind_l10n` presence, `.ai-factory/RULES.md`, `.ai-factory/ARCHITECTURE.md`, `.ai-factory/ROADMAP.md` (Phase 25)
**Risk Level:** 🟢 Low
**Status vs. review-2:** The single blocking issue from reviews 1 & 2 is now **resolved**, and the optional WARN on the SDK constraint is also **addressed**.

## Context Gates

- **Roadmap (OK):** Maps 1:1 to the ROADMAP task "Create `packages/meditation_module` Flutter package scaffold". Scope, dependency set (`flutter`, `flutter_riverpod`, `mind_ui`, `mind_l10n`), root registration alongside `breath_module`, empty-barrel replacement, and the "compiles empty" acceptance criterion all align with the roadmap text. Linkage present and correct.
- **Rules (OK):** `.ai-factory/RULES.md` rules concern stateless Module Services, App.dart isolation, and constructor DI. None apply to a deps-only scaffold that defines no services, notifiers, or App.dart wiring. No violation.
- **Architecture (OK):** A new standalone package under `packages/` is consistent with the documented pluggable-package architecture (modules are standalone Flutter packages). No boundary issue.

## Critical Issues

None.

## Resolved Since Review-2

### 1. (RESOLVED) Dangling `Calculator` reference from leftover generated test
Reviews 1 & 2 blocked on Task 1 leaving `test/meditation_module_test.dart` in place while Task 3 deletes the `Calculator` stub it asserts on — which would make Task 5's `flutter analyze` fail. Task 1 now explicitly instructs **deleting `test/meditation_module_test.dart`** (leaving the `test/` directory empty), and Task 5 references this removal as the reason analyze passes clean. Verified against the codebase precedent: `packages/bci_module/test/` exists but is empty (the generated `*_test.dart` was deleted). Fix is correct and matches convention.

### 2. (RESOLVED) `environment:` SDK constraint mirroring
Review-2's optional WARN 3 noted the `flutter create`-generated `sdk:` constraint won't match siblings. Task 2 now explicitly instructs replacing it with `sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'`, exactly matching `breath_module` and `bci_module`. Confirmed against both sibling pubspecs.

## Verified Correct

- **Dependency set (Task 2):** `flutter: { sdk: flutter }`, `flutter_riverpod: ^3.0.0`, `mind_ui: { path: ../mind_ui }`, `mind_l10n: { path: ../mind_l10n }`. `flutter_riverpod ^3.0.0` matches root `pubspec.yaml:60`, breath_module, and bci_module. Relative paths `../mind_ui` / `../mind_l10n` are correct from `packages/meditation_module/`; both target packages exist on disk (`packages/mind_ui`, `packages/mind_l10n`).
- **Correctly excludes** breath/bci-specific deps (`just_audio`, `mind_audio`, `shimmer`, `uuid`, `permission_handler`) per the roadmap spec — no audio/BLE in scope for this scaffold.
- **`publish_to: none`, `version: 0.0.1`, `dev_dependencies`** (`flutter_test`, `flutter_lints`) — all match siblings; Task 2 handles each correctly.
- **Keep `analysis_options.yaml` (Task 1):** matches `bci_module`, which retains its own. Consistent with current convention.
- **Root registration (Task 4):** `meditation_module: { path: packages/meditation_module }` under `# Internal packages` is the correct path and location — the block already lists `mind_l10n`, `mind_ui`, `breath_module`, `mind_audio`, `bci_module` (root `pubspec.yaml:34-44`), so adding alongside is right.
- **Empty barrel (Task 3):** mirroring `breath_module/lib/breath_module.dart` with no `export` lines is valid Dart and analyzes clean once the generated test file is removed (Issue 1, now resolved).
- No existing `packages/meditation_module/` on disk — safe to create.
- Settings (no tests / minimal logging / no docs) are appropriate for a deps-only scaffold.

## Positive Notes

- The plan now internalizes the codebase precedent from `bci_module` rather than guessing, and each task explicitly states why a step is needed (e.g. why the test file must go before Task 5's analyze).
- Dependency ordering between tasks is explicit and correct (Task 2/3 depend on 1; Task 4 on 2; Task 5 on 2/3/4).
- Single, well-scoped commit plan matches the deliverable.

## Recommendation

The plan is solid and self-consistent. All blocking issues from prior reviews are resolved, the SDK-constraint polish is addressed, and every file path, dependency, and API instruction was cross-checked against the live codebase. Ready to implement.

PLAN_REVIEW_PASS
