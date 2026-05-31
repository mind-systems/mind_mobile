# Plan: Create `packages/meditation_module` Flutter package scaffold

## Context
Scaffold a new empty standalone Flutter package `meditation_module` (following the same setup as the most recent analogous scaffold `packages/bci_module`) and wire it into the root project so it resolves and compiles empty, ready for screens to be added in later milestones.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Scaffold and configure the package

- [x] **Task 1: Generate the package skeleton, then remove the generated stub test**
  Files: `packages/meditation_module/` (new)
  Run `flutter create --template=package packages/meditation_module` from the repo root (use the full flutter path `/usr/local/bin/flutter`). This generates `pubspec.yaml`, `lib/meditation_module.dart` (a stub `Calculator` class), `analysis_options.yaml`, `test/meditation_module_test.dart` (asserts on `Calculator().addOne(2)`), and `.gitignore`.
  After generation, **delete `test/meditation_module_test.dart`** (leave the now-empty `test/` directory in place). This matches the established convention of the most recent analogous scaffold `packages/bci_module`, whose `test/` directory exists but is empty. It also removes the dangling `Calculator` reference that would otherwise break `flutter analyze`/`flutter test` once Task 3 empties the barrel.
  Keep the generated `analysis_options.yaml` (bci_module keeps its own — this is consistent with current convention).

- [x] **Task 2: Configure the package `pubspec.yaml`** (depends on Task 1)
  Files: `packages/meditation_module/pubspec.yaml`
  Edit the generated file to match `packages/breath_module/pubspec.yaml` / `packages/bci_module/pubspec.yaml` conventions:
  - `name: meditation_module`
  - `description:` a short one-line description, e.g. `Meditation session presentation layer for Mind app.`
  - `version: 0.0.1` (the generated default — leave unchanged, matches siblings)
  - `publish_to: none`
  - Set `environment:` to match siblings exactly: `sdk: '>=3.7.0 <4.0.0'` and `flutter: '>=3.0.0'` (replace the `flutter create`-generated `sdk: ^3.x.x` constraint so it aligns with breath_module and bci_module).
  - Under `dependencies:` declare only the deps needed for screens:
    - `flutter: { sdk: flutter }`
    - `flutter_riverpod: ^3.0.0`
    - `mind_ui: { path: ../mind_ui }`
    - `mind_l10n: { path: ../mind_l10n }`
  Do NOT add breath/bci-specific deps (`just_audio`, `mind_audio`, `shimmer`, `uuid`, `permission_handler`) — only the four listed by the milestone. Keep the generated `dev_dependencies` (`flutter_test`, `flutter_lints`).

- [x] **Task 3: Replace the generated barrel with an empty barrel** (depends on Task 1)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Replace the generated stub class content with an empty barrel file (no exports yet — they will be added in later milestones). Include a brief leading comment noting that exports will be added later, mirroring the structure of `packages/breath_module/lib/breath_module.dart` but with no `export` lines. Ensure the file has no dangling references so the package analyzes clean.

### Phase 2: Wire into the root project

- [x] **Task 4: Register the package in root `pubspec.yaml`** (depends on Task 2)
  Files: `pubspec.yaml`
  Under the `# Internal packages` comment, alongside `breath_module` / `bci_module`, add:
  ```yaml
  meditation_module:
    path: packages/meditation_module
  ```

- [x] **Task 5: Confirm resolution** (depends on Tasks 2, 3, 4)
  Files: (none — verification step)
  Run `flutter pub get` from the repo root (full flutter path) and confirm dependencies resolve with no errors. Then run `flutter analyze packages/meditation_module` and confirm it reports **no issues** (the package compiles empty). This passes cleanly because Task 1 removed the generated `test/meditation_module_test.dart` that referenced the deleted `Calculator` stub.

## Commit Plan
- **Commit 1** (after tasks 1-5): "Add empty meditation_module package scaffold"
