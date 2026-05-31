# Plan Review: Create `packages/meditation_module` Flutter package scaffold

**Plan:** `92-create-packages-meditation-module-flutter-package-scaffold.md`
**Files cross-checked:** `packages/breath_module/pubspec.yaml`, `packages/breath_module/lib/breath_module.dart`, the actual `packages/breath_module/` layout, root `pubspec.yaml`, `.ai-factory/ROADMAP.md`, `.ai-factory/RULES.md`, `.ai-factory/ARCHITECTURE.md`
**Risk Level:** 🟡 Medium

## Context Gates

- **Roadmap (WARN→OK):** The plan maps 1:1 to ROADMAP Phase 25, first task (line 211 — "Create `packages/meditation_module` Flutter package scaffold"). Scope, deps, and acceptance ("package compiling empty") all match. Linkage is present and correct.
- **Rules (OK):** `.ai-factory/RULES.md` rules concern Module Services, App.dart isolation, and constructor DI — none apply to a deps-only scaffold that creates no services/notifiers. No violation.
- **Architecture (OK):** Adding a new standalone package under `packages/` is consistent with the documented pluggable-package architecture. No boundary issue.

## Critical Issues

### 1. Generated `test/` + emptied barrel = broken analyzer / test (contradicts Task 5)

This is the one blocking flaw. `flutter create --template=package` does **not** just generate `pubspec.yaml` + an empty `lib/<name>.dart`. It generates:

- `lib/meditation_module.dart` containing a stub `Calculator` class, and
- `test/meditation_module_test.dart` that imports the package and asserts on `Calculator().addOne(2)`.

Task 3 replaces the barrel with an empty file (removing `Calculator`), while Task 1 explicitly says *"Leave the generated `test/` directory as-is."* The result: `test/meditation_module_test.dart` keeps a dangling reference to a now-deleted `Calculator`, so:

- `flutter analyze packages/meditation_module` (Task 5) will report **errors, not "analyzes clean"** — directly contradicting Task 5's stated success condition and the plan's "compiles empty" goal.
- Any later `flutter test` run on the package fails to compile.

The plan's own Context says it should "mirror `packages/breath_module`'s setup." I checked the real `breath_module` on disk: it has **no `test/` directory at all** and **no `analysis_options.yaml`** — only `lib/` and `pubspec.yaml`. So "mirroring breath_module" actually means *deleting* the generated `test/` dir, not leaving it.

**Fix:** Change Task 1 (and/or add a step) to **delete the generated `test/` directory** after `flutter create` (and either empty or delete the generated `test/meditation_module_test.dart`). This both removes the dangling `Calculator` reference and genuinely matches breath_module. Then Task 5's `flutter analyze` will be clean.

## Other Findings (Non-blocking)

### 2. WARN — Generated `analysis_options.yaml` not addressed; breath_module has none

Task 1 lists `analysis_options.yaml` as a generated artifact but no task decides its fate. The real `breath_module` has no `analysis_options.yaml` (it inherits root lints via the workspace). Keeping the generated one is harmless (it just includes `flutter_lints`), but to truly mirror breath_module you'd delete it. Low impact — call it out so the implementer makes a deliberate choice rather than leaving stray scaffold files.

### 3. WARN — `environment:` SDK constraint will differ from breath_module

breath_module pins `sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'`. Task 2 says "keep the generated `environment:` SDK constraints" — `flutter create` will emit a constraint based on the installed SDK (likely `^3.x.x`), which won't exactly match breath_module. This is harmless for resolution as long as the generated lower bound is satisfied by the installed Flutter, but it's a minor deviation from "mirror breath_module." Optional: align the constraint to `>=3.7.0 <4.0.0` for consistency across packages.

### 4. Note — `version:` field unmentioned

breath_module keeps `version: 0.0.1`. `flutter create` generates exactly that, and Task 2 doesn't touch it, so the default already matches. No action needed — noting only so it isn't "cleaned up" by mistake.

## Verified Correct

- Dependency set in Task 2 (`flutter`, `flutter_riverpod: ^3.0.0`, `mind_ui: { path: ../mind_ui }`, `mind_l10n: { path: ../mind_l10n }`) is correct: `flutter_riverpod ^3.0.0` matches both root and breath_module; the relative paths `../mind_ui` and `../mind_l10n` are correct from `packages/meditation_module/`; both target packages exist.
- Correctly **excludes** breath-specific deps (`just_audio`, `mind_audio`, `shimmer`, `uuid`) — matches the ROADMAP spec.
- Root `pubspec.yaml` registration (Task 4): `meditation_module: { path: packages/meditation_module }` under `# Internal packages` is the right path and the right location alongside `breath_module`.
- No existing `packages/meditation_module/` — safe to create.
- Empty barrel (Task 3) is valid Dart and will analyze clean **once the broken generated test is removed** (see Issue 1).
- "no tests / minimal logging / no docs" settings are appropriate for a deps-only scaffold.

## Recommendation

Resolve Issue 1 before implementation — the plan as written fails its own Task 5 verification because the leftover generated test references the deleted `Calculator` stub. The fix is small (delete the generated `test/` dir to match breath_module). Address WARNs 2–3 opportunistically for clean mirroring.
