# Plan Review: 39 — Create `packages/bci_module/` Flutter package scaffold

**Plan file:** `.ai-factory/plans/39-create-packages-bci-module-flutter-package-scaffold.md`

## Context Gates

- **ROADMAP.md** — WARN-clear. Plan matches the Phase 17 milestone "Create `packages/bci_module/` Flutter package scaffold" verbatim (deps list, target directory, barrel file, `lib/src/BciPairing/Models/`).
- **ARCHITECTURE.md / RULES.md** — Not violated. The three project rules (stateless module services, App.dart kept infra-only, constructor DI) all apply to subsequent milestones, not this scaffold-only task.
- **CLAUDE.md (mobile)** — Aligned: scaffold matches the "modules are standalone Flutter packages" pattern, `lib/src/BciPairing/` matches the PascalCase convention used by `packages/breath_module/lib/src/BreathSession/`.

## Critical Issues

### 1. Auto-generated `test/bci_module_test.dart` will break `flutter analyze`

`flutter create --template=package packages/bci_module` generates a default test that imports a placeholder class from the package's main library file. The default test looks roughly like:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bci_module/bci_module.dart';

void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    ...
  });
}
```

Task 3 overwrites `lib/bci_module.dart` with only comments — no `Calculator` class — so the test file becomes an unresolved-import / undefined-class error and **Task 6's `flutter analyze packages/bci_module` will fail with non-zero errors**, defeating the milestone's completion criterion.

**Fix:** add an explicit task (between Task 3 and Task 6) to either:
- Delete `packages/bci_module/test/bci_module_test.dart` outright (preferred — Settings explicitly says "Testing: no"), or
- Overwrite it with a no-op placeholder:
  ```dart
  void main() {}
  ```

The same risk applies to the auto-generated example `Calculator` class inside `lib/bci_module.dart` — Task 3 already overwrites that file, so that side is covered, but the test referencing it is not.

## Non-Critical Issues

### 2. `.gitkeep` justification is inaccurate (MINOR)

Task 4 says placing `.gitkeep` in `lib/src/BciPairing/Models/` "mirrors how other packages keep empty subtrees in source control." A search across the repo (`find packages -name .gitkeep`) returns no matches — there is no precedent for `.gitkeep` files anywhere in `mind_mobile`. The chosen technique itself is fine (standard Git idiom), but the justification is misleading and should be edited to say something like "so the empty directory is tracked by git" without claiming consistency with existing packages.

Alternative: drop the directory entirely and let the next milestone (which actually adds files under `Models/`) create it implicitly when its first `.dart` file is written. Empty directories without contents add nothing to this scaffold milestone.

### 3. `just_audio: ^0.10.5` dependency is unused (MINOR)

The plan copies `just_audio: ^0.10.5` from `breath_module/pubspec.yaml` into `bci_module/pubspec.yaml`. `breath_module` uses `just_audio` for breath-cycle sound effects; the BCI pairing flow described in subsequent roadmap tasks (milestones 41–47) plays a single "calibration complete" sound (see milestone 41's "completion sound" note) — which arguably justifies it — but adding the dep before any code uses it adds unused-import surface area to `flutter analyze` and `pub get` resolution time.

**Recommendation:** drop `just_audio` from this scaffold; let milestone 41 add it when the screen actually plays a sound. If the intent is to mirror `breath_module` exactly, then for consistency the plan should also include `shimmer: any` and `uuid: any` (both present in `breath_module/pubspec.yaml`) — but those are clearly unneeded, which underscores that "mirror breath_module" should not be the rule.

### 4. `pub get` ordering in Task 6 (MINOR)

Task 6 instructs `flutter pub get` from `packages/bci_module/` first, then from the repo root. The root `pubspec.yaml` references `bci_module: path: packages/bci_module` (added by Task 5), so resolving from root will transitively resolve the package — running `pub get` inside the package first is redundant. Single `flutter pub get` from the repo root is sufficient and faster. Not wrong, just superfluous.

### 5. Alphabetical-grouping claim in Task 5 (NIT)

Task 5 says "Keep alphabetical/visual grouping consistent with the existing module list." The existing list in root `pubspec.yaml` (lines 35–44) is `mind_l10n, mind_ui, breath_module, mind_audio, neiry_kit` — not alphabetical, ordered by insertion. The instruction to add `bci_module` after the `mind_audio` block is fine, but the "alphabetical" half of the sentence is wrong. Suggest dropping the word "alphabetical."

## Positive Notes

- Plan correctly identifies that `lib/src/BciPairing/` matches the PascalCase subdirectory convention of `breath_module` (`BreathSession/`, `BreathSessionsList/`).
- Pinning `environment.sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'` matches both `breath_module` and `mind_audio` pubspecs.
- Dependency on `mind_l10n` and `mind_ui` via relative path matches the standalone-package boundary rule from `CLAUDE.md`.
- Task ordering (generate → overwrite pubspec → barrel → directory → wire into app → verify) is correct; deps between tasks are explicit.
- Barrel-comment template (`// Screens / // ViewModels / // Service + Coordinator interfaces / // Other public symbols`) matches the comment-section style used in `breath_module/lib/breath_module.dart`.
- Plan correctly anchors line numbers (root `pubspec.yaml` lines 41–42) for the `mind_audio` block — verified accurate.

## Required Changes Before PASS

1. Add a task (between Task 3 and Task 6, or merged into Task 3) to delete `packages/bci_module/test/bci_module_test.dart` (or replace it with `void main() {}`) so `flutter analyze` succeeds.

The remaining items (`.gitkeep` justification, `just_audio` inclusion, redundant `pub get`, alphabetical wording) are recommendations and would not block implementation.