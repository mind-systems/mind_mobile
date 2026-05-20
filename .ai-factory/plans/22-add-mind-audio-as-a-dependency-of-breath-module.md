# Plan: Add `mind_audio` as a dependency of `breath_module`

## Context
Wire the existing `packages/mind_audio` package into `packages/breath_module` so the breath module can `import 'package:mind_audio/mind_audio.dart'`. No source code changes — pubspec wiring only.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Dependency wiring

- [x] **Task 1: Add `mind_audio` path dependency to `breath_module/pubspec.yaml`**
  Files: `packages/breath_module/pubspec.yaml`
  The existing dependency ordering in this file is alphabetical:
  `flutter (sdk) → flutter_riverpod → just_audio → mind_l10n → mind_ui → shimmer → uuid`.
  Insert the new entry **directly after the `just_audio:` line and before the `mind_l10n:` block** so the resulting order remains alphabetical (`… just_audio → mind_audio → mind_l10n → mind_ui …`):
  ```yaml
    mind_audio:
      path: ../mind_audio
  ```
  Keep the existing two-space indentation and do not change any other dependency, version constraint, or section.

- [x] **Task 2: Resolve dependencies at the repo root** (depends on Task 1)
  Files: `pubspec.lock` (auto-generated), `.dart_tool/package_config.json` (auto-generated)
  The root app (`mind_mobile/pubspec.yaml`) consumes both `breath_module` and `mind_audio` as path dependencies, so the root workspace must be refreshed for the new transitive path to be picked up everywhere the app is built/launched. From the repo root run:
  ```bash
  /usr/local/bin/flutter pub get
  ```
  Confirm the command exits with code 0. Do not hand-edit `pubspec.lock` or `package_config.json`.

- [x] **Task 3: Verify `mind_audio` is wired into `breath_module`** (depends on Task 2)
  Files: none (verification only — no source change)
  From the repo root run:
  ```bash
  cd packages/breath_module && /usr/local/bin/flutter pub deps --no-dev
  ```
  Confirm the output lists `mind_audio` under the direct dependencies of `breath_module`. This proves `package:mind_audio/mind_audio.dart` is now resolvable from inside `breath_module` without modifying any source file. The task ends here — no temporary imports, no leftover edits in the working tree beyond the `pubspec.yaml` change from Task 1 and the auto-regenerated lockfile/package config from Task 2.
