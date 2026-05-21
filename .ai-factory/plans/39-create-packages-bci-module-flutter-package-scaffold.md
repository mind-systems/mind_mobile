# Plan: Create `packages/bci_module/` Flutter package scaffold

## Context
Bootstrap a new standalone Flutter package `bci_module` (presentation layer for BCI pairing flow) that follows the same conventions as `packages/breath_module/` and `packages/mind_audio/`. The deliverable is an empty package that compiles, is wired into the app's `pubspec.yaml`, and has the `BciPairing/Models/` directory ready for subsequent milestones.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Generate and configure the package

- [x] **Task 1: Generate the package skeleton**
  Files: `packages/bci_module/` (new directory tree)
  Run `flutter create --template=package packages/bci_module` from the repo root (`/Users/max/projects/mind/mind_mobile`). This creates `packages/bci_module/` with `pubspec.yaml`, `lib/bci_module.dart`, `test/bci_module_test.dart`, `analysis_options.yaml`, and `.gitignore`. Do NOT modify the generated files yet — Tasks 2–4 will overwrite the relevant ones.

- [x] **Task 2: Configure `packages/bci_module/pubspec.yaml`**
  Files: `packages/bci_module/pubspec.yaml`
  Replace the generated `pubspec.yaml` content with the same structure used by `packages/breath_module/pubspec.yaml`:
  - `name: bci_module`
  - `description: BCI pairing presentation layer for Mind app.`
  - `version: 0.0.1`
  - `publish_to: none`
  - `environment.sdk: '>=3.7.0 <4.0.0'`
  - `environment.flutter: '>=3.0.0'`
  - `dependencies`:
    - `flutter: { sdk: flutter }`
    - `flutter_riverpod: ^3.0.0`
    - `just_audio: ^0.10.5`
    - `mind_l10n: { path: ../mind_l10n }`
    - `mind_ui: { path: ../mind_ui }`
  - `dev_dependencies`:
    - `flutter_test: { sdk: flutter }`
    - `flutter_lints: ^6.0.0`
  - Empty `flutter:` section (matches existing packages).

  Note: `just_audio` is included because the milestone description in ROADMAP.md line 89 explicitly lists it as a required dep (BCI calibration screen plays a completion sound in a later milestone).

- [x] **Task 3: Replace `lib/bci_module.dart` with an empty export barrel** (depends on Task 1)
  Files: `packages/bci_module/lib/bci_module.dart`
  Overwrite the auto-generated file content (which contains a placeholder `Calculator` class) with an empty barrel placeholder consistent with the comment-section style used in `packages/breath_module/lib/breath_module.dart`:
  ```dart
  // Screens
  // ViewModels
  // Service + Coordinator interfaces
  // Other public symbols
  ```
  No exports yet — subsequent milestones will add them.

- [x] **Task 4: Delete the auto-generated test file** (depends on Task 1)
  Files: `packages/bci_module/test/bci_module_test.dart` (delete)
  `flutter create --template=package` generates `test/bci_module_test.dart` that imports the placeholder `Calculator` class from `lib/bci_module.dart`. After Task 3 wipes that class, the test would fail to compile and break Task 6's `flutter analyze`. Delete the file outright (Settings declares `Testing: no`, so no replacement test is needed). Leave the empty `test/` directory in place.

- [x] **Task 5: Create the `BciPairing/Models/` directory** (depends on Task 1)
  Files: `packages/bci_module/lib/src/BciPairing/Models/.gitkeep`
  Create `lib/src/BciPairing/Models/` and place an empty `.gitkeep` file inside so the empty directory is tracked by git. (No other package in `mind_mobile` currently uses `.gitkeep` — this is just the standard Git idiom for tracking an empty directory; the milestone explicitly requires this directory to exist before it ends.)

### Phase 2: Wire the package into the app

- [x] **Task 6: Add `bci_module` to the app `pubspec.yaml`** (depends on Tasks 2–5)
  Files: `pubspec.yaml` (repo root, app-level)
  Add a new entry under `dependencies` after the existing `mind_audio` block (root `pubspec.yaml` lines 41–42):
  ```yaml
    bci_module:
      path: packages/bci_module
  ```
  Match the insertion-order grouping of the existing module entries (`mind_l10n`, `mind_ui`, `breath_module`, `mind_audio`) — no alphabetical sort.

- [x] **Task 7: Resolve dependencies and verify compilation** (depends on Task 6)
  Files: (no source changes — verification only)
  From the repo root (`/Users/max/projects/mind/mind_mobile`), run `/usr/local/bin/flutter pub get`. This resolves both the app workspace and transitively the new `bci_module` package via its path dependency. Then run `/usr/local/bin/flutter analyze packages/bci_module` to confirm the empty package compiles with zero errors. Milestone is complete when `pub get` succeeds and `flutter analyze` reports no errors for the new package.
