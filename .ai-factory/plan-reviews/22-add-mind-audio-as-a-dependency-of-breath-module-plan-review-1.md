# Plan Review: Add `mind_audio` as a dependency of `breath_module`

**Plan reviewed:** `22-add-mind-audio-as-a-dependency-of-breath-module.md`
**Risk Level:** 🟢 Low

## Summary

The plan is small and well-scoped: a single pubspec wiring change in `packages/breath_module/pubspec.yaml` with a verification step. The target package (`packages/mind_audio`) exists with a valid `pubspec.yaml` and a public barrel file (`lib/mind_audio.dart` exporting `audio_track`, `audio_catalog`, `audio_looper`, `audio_one_shot`). Version constraints align: both packages use `just_audio: ^0.10.5`, no conflict.

## Context Gates

- **Architecture (.ai-factory/ARCHITECTURE.md):** N/A — pubspec-only change, no architectural impact. The wiring follows the existing pattern (`mind_l10n`, `mind_ui` are added as path dependencies).
- **Rules (.ai-factory/RULES.md):** N/A — none present.
- **Roadmap (.ai-factory/ROADMAP.md):** Plan is numbered `22` and follows the `mind_audio` scaffolding sequence (16–21). Consistent with ordering.

## Findings

### Issue 1 — Wrong alphabetical placement justification (minor, but the instruction itself is wrong)

Task 1 instructs:
> "Insert a new dependency entry directly after the `mind_ui` block (which currently lives at lines 17–18 with `path: ../mind_ui`) so that alphabetical ordering with the surrounding entries is preserved …"

The current ordering of dependencies in `packages/breath_module/pubspec.yaml` is alphabetical:
```
flutter (sdk), flutter_riverpod, just_audio, mind_l10n, mind_ui, shimmer, uuid
```

Inserting `mind_audio` **after** `mind_ui` would produce `mind_l10n → mind_ui → mind_audio → shimmer`, which **breaks** alphabetical order. To preserve the existing ordering, `mind_audio` must go **between `just_audio` and `mind_l10n`** (so the order becomes `… just_audio → mind_audio → mind_l10n → mind_ui …`).

**Recommended fix:** Update Task 1 to say "insert directly after the `just_audio` line and before the `mind_l10n` block." The YAML snippet itself is correct; only the placement instruction needs to change.

### Issue 2 — Root-level `pub get` not run (minor)

The root app (`mind_mobile/pubspec.yaml`) consumes both `breath_module` and `mind_audio` as path dependencies. After modifying `packages/breath_module/pubspec.yaml`, the root project's `.dart_tool/package_config.json` and `pubspec.lock` should also be refreshed. Running `flutter pub get` only inside `packages/breath_module` will resolve the package's own metadata but won't refresh the root app, which is the only place from which the app is actually launched/built.

**Recommended fix:** Either run `/usr/local/bin/flutter pub get` from the repo root as well (preferred — this resolves the workspace including all path packages), or replace the per-package step entirely with a single root-level `flutter pub get`. Confirm there is no "Target of URI doesn't exist" error when the root app imports something from `breath_module`.

### Issue 3 — Verification approach is hacky but harmless (nit)

Task 3 instructs adding a temporary `import 'package:mind_audio/mind_audio.dart';` to a file under `packages/breath_module/lib/`, running `flutter analyze`, then removing the import. This works but is fragile: forgetting to remove the import would leak into the working tree.

**Recommended alternative:** A successful `flutter pub get` already proves the path resolves; if extra verification is wanted, `flutter pub deps --no-dev` inside `packages/breath_module` will list `mind_audio` without touching any source file. Either is acceptable — flag this only as a softer suggestion.

## Positive Notes

- Scope is correctly minimal: pubspec wiring only, no source code change, no test/doc requirement.
- Version constraints checked implicitly: both packages already use `just_audio: ^0.10.5` so no transitive conflict.
- Phased task ordering with explicit `depends on` annotations is clear.
- The `package:mind_audio/mind_audio.dart` import path matches the existing barrel file in `packages/mind_audio/lib/mind_audio.dart`.
- Uses absolute Flutter path (`/usr/local/bin/flutter`) per project convention.

## Required Changes Before Implementation

1. Correct the alphabetical placement in Task 1 (insert between `just_audio` and `mind_l10n`, not after `mind_ui`).
2. Add a root-level `flutter pub get` step (or replace Task 2 with it).

The two changes are small. After they are applied, this plan is ready to implement.
