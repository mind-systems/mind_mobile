# Plan: Create `packages/mind_audio` Flutter package scaffold

## Context
Bootstrap an empty `mind_audio` Flutter package alongside the existing internal packages (`mind_l10n`, `mind_ui`, `breath_module`) so that future audio-related code has a home. Task ends with the package compiling empty and being resolvable from the root project.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Scaffold package

- [x] **Task 1: Generate the `mind_audio` package skeleton**
  Files: `packages/mind_audio/` (new directory tree created by Flutter tooling)
  Run `flutter create --template=package packages/mind_audio` from the `mind_mobile` project root (use the full Flutter path `/usr/local/bin/flutter`). This generates the standard package layout (`lib/mind_audio.dart`, `pubspec.yaml`, `analysis_options.yaml`, `test/`, etc.). Do not add any source files beyond what the template produces — the package must end this phase as a compilable empty package.

### Phase 2: Configure dependencies

- [x] **Task 2: Configure `packages/mind_audio/pubspec.yaml`** (depends on Task 1)
  Files: `packages/mind_audio/pubspec.yaml`
  Edit the generated `pubspec.yaml`:
  - Ensure `name: mind_audio`.
  - Under `dependencies:`, keep the auto-generated `flutter: sdk: flutter` entry (needed for `rootBundle`).
  - Add `just_audio: ^0.10.5` under `dependencies:` (match the exact version pinned in `packages/breath_module/pubspec.yaml`).
  - Leave the rest of the generated file (description, version, environment SDK constraints, dev dependencies) as produced by the template. Do not add any other dependencies.

- [x] **Task 3: Register `mind_audio` in the root `pubspec.yaml`** (depends on Task 2)
  Files: `pubspec.yaml`
  In the root `pubspec.yaml`, under the existing `# Internal packages` comment (currently containing `mind_l10n`, `mind_ui`, `breath_module` — see lines ~34–40), add:
  ```yaml
    mind_audio:
      path: packages/mind_audio
  ```
  Place the entry alongside the other internal package entries (keep grouping consistent).

### Phase 3: Verify resolution

- [x] **Task 4: Run `flutter pub get` from the root** (depends on Task 3)
  Files: (no file changes; updates `pubspec.lock` / `.dart_tool/`)
  From the `mind_mobile` root, run `/usr/local/bin/flutter pub get` and confirm the command exits with zero errors and that `mind_audio` is resolved as a path dependency. No source files should be added — the package compiles empty.
