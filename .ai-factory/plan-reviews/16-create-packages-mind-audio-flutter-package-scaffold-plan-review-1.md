# Plan Review: Create `packages/mind_audio` Flutter package scaffold

**Plan reviewed:** `.ai-factory/plans/16-create-packages-mind-audio-flutter-package-scaffold.md`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`ARCHITECTURE.md`)**: not specifically checked for this scaffold; creating a new package under `packages/` is consistent with the documented module system (`docs/core/module-system.md`) and matches the layout of `mind_l10n`, `mind_ui`, `breath_module`. No boundary violations expected — no source files added.
- **Rules (`RULES.md`)**: no project rules file in `.ai-factory/`. The plan respects the global rule "always use `flutter pub add`" by performing manual edits *only* for declaring a path-dependency in the root `pubspec.yaml` (which `flutter pub add` cannot do cleanly for sibling path deps) — this is the accepted workaround across the repo (the existing `mind_l10n`, `mind_ui`, `breath_module` entries are already managed manually).
- **Roadmap (`ROADMAP.md`)**: not checked against, but this scaffold task is plausibly a precursor to upcoming audio work; no roadmap linkage assertion needed for an empty package.

## Findings

### Notes / Minor observations

1. **`flutter create --template=package` produces more meta files than other internal packages have** — `README.md`, `CHANGELOG.md`, `LICENSE`, `.metadata`, `analysis_options.yaml`, `test/mind_audio_test.dart`. The existing `mind_l10n`, `mind_ui`, `breath_module` directories contain only `lib/`, `pubspec.yaml`, and (for some) `pubspec.lock` / generator config. The plan explicitly says "Do not add any source files beyond what the template produces", which is fine, but the result will be stylistically inconsistent with the rest of `packages/`. Two acceptable options:
   - Accept the inconsistency (plan's current direction). Fine for a one-time scaffold.
   - Add a follow-up cleanup step to delete `CHANGELOG.md`, `LICENSE`, `.metadata`, `README.md`, and the generated stub `test/` file to match the other packages. Worth a one-line note in the plan to remove `lib/mind_audio.dart`'s "Calculator" placeholder class (the template puts a sample class in there).

   **Suggestion:** add a sub-step in Task 1: "Delete the placeholder `Calculator` class body from `lib/mind_audio.dart`, leaving the file empty (or with only a library declaration), so the package contains no real source code."

2. **SDK constraint drift** — `flutter create` will emit `sdk: ^3.x.y` matching the local Flutter install (likely `^3.9.2`+), while the other internal packages use `sdk: '>=3.7.0 <4.0.0'` plus `flutter: '>=3.0.0'`. Compatible with the root project (`sdk: ^3.9.2`), so resolution will not break. If consistency with sibling packages matters, the plan could note to normalise the `environment:` block to match `mind_ui`/`breath_module`. Non-blocking.

3. **`just_audio` is added but unused** — Task 2 pins `just_audio: ^0.10.5` even though Task 1 forbids adding source files. `flutter pub get` will not fail, and Dart analyzer does not error on unused declared deps. This is a deliberate seed for forthcoming work and aligns the version with `breath_module`. Fine, but worth being explicit in the plan that the dep is intentionally unused at this stage so future reviewers don't flag it as dead config.

4. **Justification for keeping the `flutter` SDK dependency** — the plan says "needed for `rootBundle`", but the empty package will not use `rootBundle` yet. The real justification is simpler: `flutter create --template=package` generates a Flutter-aware package and the SDK entry is required for that template type. The misleading rationale is harmless but worth correcting.

5. **`name:` field check is redundant** — `flutter create --template=package packages/mind_audio` uses the directory name as the package name; the generated `pubspec.yaml` will already have `name: mind_audio`. The "Ensure" wording in Task 2 is fine as a sanity check, no action needed.

6. **Verification step is light** — Task 4 only runs `flutter pub get`. Consider also running `/usr/local/bin/flutter analyze packages/mind_audio` to confirm the empty package analyses cleanly with the template's `analysis_options.yaml`. This catches lints from the generated stub before the next consumer pulls it in. Non-blocking.

7. **`pubspec.lock` per package** — running `pub get` from the root *should* leave `packages/mind_audio/pubspec.lock` unwritten (the workspace lockfile lives at the root). The existing internal packages do carry their own `pubspec.lock` files (visible in `mind_ui/`, `breath_module/`, `mind_l10n/`), suggesting someone has run `pub get` inside those packages directly. No action needed — but if the team wants consistency, the plan could call out whether or not to commit a `packages/mind_audio/pubspec.lock`.

### Verified items

- **Path of root `pubspec.yaml` edit**: confirmed. The `# Internal packages` comment is at line 34, with `mind_l10n`, `mind_ui`, `breath_module` immediately below — the plan's reference to "lines ~34–40" is accurate.
- **`just_audio` version pinning**: confirmed against `packages/breath_module/pubspec.yaml` line 14 (`just_audio: ^0.10.5`). Matches.
- **Package template choice**: `--template=package` (not `--template=plugin`) is correct — `just_audio` is a pure-Dart consumer in dependents and no platform channels are introduced here.
- **Task ordering / dependencies**: Task 2 → Task 3 → Task 4 ordering is correct; root `pub get` must run after the path-dep is registered.
- **`flutter create` path argument**: `packages/mind_audio` (relative to `mind_mobile` root) is the correct invocation; it creates the directory and the package layout in one step. No pre-existing `packages/mind_audio/` directory present, so no collision risk.
- **Flutter binary path**: `/usr/local/bin/flutter` matches the user-memory preference.

## Conclusion

Plan is solid and low-risk. The observations above are all stylistic or clarifying — none of them are correctness or security blockers. Recommend addressing Note #1 (placeholder class deletion) in implementation, but the plan can proceed as-is.

PLAN_REVIEW_PASS
