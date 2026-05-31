# Plan: Define `MeditationPoseDTO` + static pose list + title helper in `meditation_module`

## Context
Add the pure-data foundation of the meditation module: a minimal `MeditationPoseDTO` (id only), a hardcoded list of six poses, and an id→localized-title `switch` helper, backed by six new ARB keys in both `mind_l10n` files. No persistence, no domain layer — package code only.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Localization

- [x] **Task 1: Add six pose ARB keys to both `mind_l10n` files**
  Files: `packages/mind_l10n/lib/l10n/app_en.arb`, `packages/mind_l10n/lib/l10n/app_ru.arb`
  Append six new string keys to each ARB file (insert before the closing `}`, keep a comma on the previously-last entry). Keys and EN values: `meditationPoseEasy` = "Easy Pose", `meditationPoseLotus` = "Lotus", `meditationPoseHalfLotus` = "Half Lotus", `meditationPoseSeiza` = "Kneeling (Seiza)", `meditationPoseChair` = "Seated (Chair)", `meditationPoseSavasana` = "Lying Down (Savasana)". RU values: `meditationPoseEasy` = "Поза по-турецки", `meditationPoseLotus` = "Лотос", `meditationPoseHalfLotus` = "Полулотос", `meditationPoseSeiza` = "На коленях (сэйдза)", `meditationPoseChair` = "Сидя на стуле", `meditationPoseSavasana` = "Лёжа (шавасана)". Match the existing ARB formatting (two-space indent, no `@`-metadata blocks are used for these simple strings — follow the pattern of the surrounding plain keys like `bciConnectButton`). Ensure both files remain valid JSON.

- [x] **Task 2: Regenerate `AppLocalizations` from the updated ARB files** (depends on Task 1)
  Files: generated output under `packages/mind_l10n/lib/` (no manual edits)
  Run the project's l10n codegen so the six new getters (`l10n.meditationPoseEasy` … `l10n.meditationPoseSavasana`) exist on `AppLocalizations`. Use `/usr/local/bin/flutter gen-l10n` (or the project's configured generation command) from `packages/mind_l10n`, then `/usr/local/bin/flutter pub get` from the repo root if needed. This must succeed before Task 4 will compile.

### Phase 2: Package model code

- [x] **Task 3: Create `MeditationPoseDTO` + `kMeditationPoses` + `meditationPoseTitle` helper** (depends on Task 2)
  Files: `packages/meditation_module/lib/src/Models/MeditationPoses.dart`
  Create the file with exactly the shapes from `.ai-factory/notes/34-meditation-module-impl-specs.md` (Resolved decisions):
  - `@immutable class MeditationPoseDTO { final String id; const MeditationPoseDTO({required this.id}); }` — `@immutable` requires `import 'package:flutter/foundation.dart';`.
  - `const List<MeditationPoseDTO> kMeditationPoses = [ ... ]` with the six poses in order: `easy`, `lotus`, `half_lotus`, `seiza`, `chair`, `savasana` (each `MeditationPoseDTO(id: '<slug>')`).
  - Top-level `String meditationPoseTitle(AppLocalizations l10n, String id)` that `switch`es each id slug to the matching getter (`'easy' → l10n.meditationPoseEasy`, `'lotus' → l10n.meditationPoseLotus`, `'half_lotus' → l10n.meditationPoseHalfLotus`, `'seiza' → l10n.meditationPoseSeiza`, `'chair' → l10n.meditationPoseChair`, `'savasana' → l10n.meditationPoseSavasana`), `default: return id;`.
  - Add `import 'package:mind_l10n/mind_l10n.dart';` for `AppLocalizations` (matches how `breath_module` imports it).

- [x] **Task 4: Export the new symbols from the package barrel** (depends on Task 3)
  Files: `packages/meditation_module/lib/meditation_module.dart`
  Replace the placeholder comment with `export 'src/Models/MeditationPoses.dart';` so `MeditationPoseDTO`, `kMeditationPoses`, and `meditationPoseTitle` are all re-exported (a single file export covers all three top-level symbols). Then run `/usr/local/bin/flutter pub get` and confirm `meditation_module` analyzes/compiles cleanly.
