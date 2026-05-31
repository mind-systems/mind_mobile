# Plan Review (2): Create `packages/meditation_module` Flutter package scaffold

**Plan:** `92-create-packages-meditation-module-flutter-package-scaffold.md`
**Files cross-checked:** `packages/breath_module/{pubspec.yaml,lib/breath_module.dart}` and on-disk layout, `packages/bci_module/{pubspec.yaml,lib/bci_module.dart}` and on-disk layout (most recent analogous scaffold, ROADMAP Phase 39), root `pubspec.yaml`, `packages/mind_ui` / `packages/mind_l10n` presence, `.ai-factory/RULES.md`, `.ai-factory/ARCHITECTURE.md`, `.ai-factory/ROADMAP.md`
**Risk Level:** 🟡 Medium
**Status vs. review-1:** The plan text is **unchanged** from the version reviewed in review-1. The single blocking issue raised there is **still present**.

## Context Gates

- **Roadmap (OK):** Maps 1:1 to ROADMAP Phase 25 — "Create `packages/meditation_module` Flutter package scaffold". Scope, dependency set, and the "compiles empty" acceptance criterion all align. Linkage present and correct.
- **Rules (OK):** `.ai-factory/RULES.md` rules concern Module Services, App.dart isolation, and constructor DI. None apply to a deps-only scaffold that defines no services/notifiers. No violation.
- **Architecture (OK):** A new standalone package under `packages/` is consistent with the documented pluggable-package architecture. No boundary issue.

## Critical Issues

### 1. (UNRESOLVED from review-1) "Leave the generated `test/` as-is" + emptied barrel → dangling `Calculator` reference, fails Task 5

`flutter create --template=package` generates **both**:
- `lib/meditation_module.dart` with a stub `Calculator` class, and
- `test/meditation_module_test.dart` that imports the package and asserts on `Calculator().addOne(2)`.

Task 3 empties the barrel (deleting `Calculator`), while Task 1 explicitly says *"Leave the generated `test/` directory as-is for now."* The leftover `test/meditation_module_test.dart` then references a symbol that no longer exists, so:
- `flutter analyze packages/meditation_module` (Task 5) reports **errors** — directly contradicting Task 5's "analyzes clean / compiles empty" success condition.
- Any later `flutter test` on the package fails to compile.

**The codebase precedent confirms the fix.** I inspected the most recent analogous scaffold, `packages/bci_module` (created in Phase 39, after breath_module). Its `test/` directory exists but is **empty** — the generated `bci_module_test.dart` (with the `Calculator` reference) was deleted. So the established convention is: **keep an empty `test/` dir, delete the generated `<name>_test.dart`**.

**Fix:** Change Task 1 to **delete the generated `test/meditation_module_test.dart`** after `flutter create` (leaving the `test/` directory empty, matching bci_module). This removes the dangling reference so Task 5's analyze is genuinely clean. This is the same fix review-1 recommended; it remains unaddressed in the current plan text.

## Other Findings (Non-blocking)

### 2. CORRECTION to review-1 WARN — keeping `analysis_options.yaml` is fine (matches bci_module)

Review-1 suggested deleting the generated `analysis_options.yaml` to mirror breath_module (which has none). On re-inspection, the **more recent** scaffold `bci_module` **keeps** its `analysis_options.yaml`. So keeping the generated file is consistent with current convention and requires no action. The plan's silence on it is acceptable — either keep it (matches bci_module) or delete it (matches breath_module); both are precedented. No blocking concern.

### 3. WARN — `environment:` SDK constraint may differ from sibling packages

Both breath_module and bci_module pin `sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'`. Task 2 says "keep the generated `environment:` SDK constraints", and `flutter create` emits a constraint based on the installed SDK (e.g. `^3.x.x`), which won't exactly match. Harmless for resolution as long as the installed Flutter satisfies the lower bound, but for clean mirroring align the constraint to `>=3.7.0 <4.0.0`. Task 2 already correctly instructs adding `flutter: '>=3.0.0'`.

### 4. Note — `version: 0.0.1` and `dev_dependencies` already match

`flutter create` emits `version: 0.0.1` and `dev_dependencies` (`flutter_test`, `flutter_lints`) — both bci_module and breath_module keep these. Task 2 leaves them untouched, which is correct. No action; noted so they aren't "cleaned up" by mistake.

## Verified Correct

- **Dependency set (Task 2):** `flutter`, `flutter_riverpod: ^3.0.0`, `mind_ui: { path: ../mind_ui }`, `mind_l10n: { path: ../mind_l10n }`. `flutter_riverpod ^3.0.0` matches root (`pubspec.yaml:60`), breath_module, and bci_module. Relative paths `../mind_ui` / `../mind_l10n` are correct from `packages/meditation_module/`; both target packages exist on disk.
- **Correctly excludes** breath-specific deps (`just_audio`, `mind_audio`, `shimmer`, `uuid`) per the ROADMAP spec. (Note: bci_module carries `mind_audio` + `permission_handler`; meditation correctly omits both since no audio/BLE is in scope yet.)
- **Root registration (Task 4):** `meditation_module: { path: packages/meditation_module }` under `# Internal packages` is the correct path and location — the block already lists `mind_l10n`, `mind_ui`, `breath_module`, `mind_audio`, `bci_module`, so adding alongside is right.
- No existing `packages/meditation_module/` — safe to create.
- Empty barrel (Task 3) is valid Dart and analyzes clean **once the generated test file is removed** (Issue 1).
- Settings (no tests / minimal logging / no docs) are appropriate for a deps-only scaffold.

## Recommendation

**Do not pass yet.** Resolve Issue 1 — the one-line fix is: delete the generated `test/meditation_module_test.dart` in Task 1 (leave `test/` empty, matching bci_module). As written, the plan fails its own Task 5 verification because the leftover generated test references the deleted `Calculator` stub. WARN 3 is optional polish. Once Task 1 is amended to remove the generated test file, the plan is ready to implement.
