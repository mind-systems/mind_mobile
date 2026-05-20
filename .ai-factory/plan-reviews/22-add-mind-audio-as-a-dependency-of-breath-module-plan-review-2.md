# Plan Review: Add `mind_audio` as a dependency of `breath_module`

**Plan file:** `.ai-factory/plans/22-add-mind-audio-as-a-dependency-of-breath-module.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — WARN (informational): `mind_audio` is a standalone package and is already adopted in the module system. Adding it as a transitive path-dep of `breath_module` aligns with the "Modules are standalone Flutter packages" rule in `mind_mobile/CLAUDE.md` and does not cross any boundary.
- **RULES.md** — PASS: The three project rules (stateless services, no module concerns in `App.dart`, constructor DI) are not affected by a pubspec wiring change.
- **ROADMAP.md** — PASS with note: This work is the exact next unchecked item on line 43 of `ROADMAP.md` ("Add `mind_audio` as a dependency of `breath_module`"). The roadmap suggests inserting `mind_audio: { path: ../mind_audio }` *after `mind_ui`*, while the plan inserts it *between `just_audio` and `mind_l10n`* to preserve alphabetical order. The deviation is intentional, internally consistent (the existing block is alphabetical: `flutter` → `flutter_riverpod` → `just_audio` → `mind_l10n` → `mind_ui` → `shimmer` → `uuid`), and functionally equivalent — accept.

## Verification Against Codebase

- `packages/mind_audio/` exists with a valid `pubspec.yaml` (`name: mind_audio`) and a barrel file `lib/mind_audio.dart` exporting `audio_track`, `audio_catalog`, `audio_looper`, `audio_one_shot`. The target import `package:mind_audio/mind_audio.dart` is real.
- `packages/breath_module/pubspec.yaml` matches the plan's quoted block (lines 10–20). The proposed insertion point and two-space indentation are correct.
- Root `pubspec.yaml` (lines 39–42) already declares both `breath_module` and `mind_audio` as path deps, so `flutter pub get` from root will see the new transitive edge without further wiring.
- `just_audio` version constraint is identical in both `mind_audio` (`^0.10.5`) and `breath_module` (`^0.10.5`) — no resolver conflict risk.
- `flutter pub deps --no-dev` is a valid flag and will list direct deps of `breath_module`; the verification check in Task 3 is reasonable.

## Critical Issues

None.

## Minor Notes (non-blocking)

1. **Task 3 working-directory hygiene.** The command `cd packages/breath_module && /usr/local/bin/flutter pub deps --no-dev` changes the shell's CWD for the remainder of the agent's session if the command is run without a subshell. Suggest wrapping in `(cd packages/breath_module && /usr/local/bin/flutter pub deps --no-dev)` or running `/usr/local/bin/flutter pub deps --no-dev --directory packages/breath_module` from root. Cosmetic.
2. **Task 2 expected output.** "Exits with code 0" is fine; the harness will also surface any path-not-found errors, so no extra assertion is needed. No change required.
3. **Documentation linkage (optional).** Not flagged as ERROR because the plan's `Docs: no` setting is consistent with a pubspec-only wiring change and no doc in `docs/` currently inventories module dependencies. If the implementer later wants discoverability, `docs/core/module-system.md` would be the natural home.

## Positive Notes

- The plan correctly identifies that no source-code changes are required and resists the temptation to add a temporary `import 'package:mind_audio/mind_audio.dart';` for verification — `flutter pub deps` is the cleaner proof.
- Alphabetical ordering of dependencies is preserved, justified inline, and matches the surrounding block exactly.
- Auto-generated artifacts (`pubspec.lock`, `.dart_tool/package_config.json`) are explicitly called out as not-hand-editable.
- Task dependencies (`Task 2` depends on `Task 1`, `Task 3` depends on `Task 2`) are correct and minimal.
- Scope is tight: one pubspec line + two verification commands. No scope creep into `BreathSoundCoordinator` refactoring (that is correctly deferred to a later roadmap item).

PLAN_REVIEW_PASS
