# Plan Review: Extract the duplicated BCI channel-quality mapper into `lib/BciModule/`

**Plan:** `102-extract-the-duplicated-bci-channel-quality-mapper-into-lib-bcimodule.md`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present. No boundary violation — the plan correctly keeps the shared mapper in `lib/BciModule/` (the delivery layer that already imports both the domain model and the package DTOs) rather than in `packages/bci_module/`, which cannot reference the domain `BciSignalLevel` enum. Aligned. ✅
- **Rules (`.ai-factory/RULES.md`):** present. The relevant rule — "Module Services must be stateless, no extra state/streams" — is unaffected; this refactor only moves two pure functions out of the services. No violation. ✅
- **Roadmap (`.ai-factory/ROADMAP.md`):** linked. Milestone at line 253 ("Extract the duplicated BCI channel-quality mapper into `lib/BciModule/`") matches the plan verbatim, and the referenced spec note `.ai-factory/notes/55-task-bci-channel-mapper-extract.md` exists and is consistent with the plan. ✅

## Verification Against Codebase

Every factual assumption in the plan was checked against the source:

- **Duplication is real and verbatim.** `_mapLevel(BciSignalLevel)→BciSignalQuality` and the inline `channels.map(...).toList(growable: false)` exist identically in `BciPairingService.dart` (lines 66–73, 189–198) and `BciDataService.dart` (lines 63–70, 102–111). Mapping is identical in both: `green→good`, `yellow→fair`, `red→poor`. ✅
- **Package exports are correct.** `packages/bci_module/lib/bci_module.dart` exports `BciChannelQualityDTO.dart`, which defines both `enum BciSignalQuality { good, fair, poor }` and `class BciChannelQualityDTO`. So `import 'package:bci_module/bci_module.dart';` does provide both symbols named in Task 1. ✅
- **DTO shape is correct.** `BciChannelQualityDTO` has exactly `{ required String channelName, required BciSignalQuality quality }` — matching the constructor call the plan specifies. ✅
- **Domain import path is correct.** `BciSignalLevel` and `BciChannelQuality` both live in `lib/Bci/Models/BciChannelQuality.dart`. ✅
- **Package name is correct.** `pubspec.yaml` → `name: mind`, so `package:mind/BciModule/BciChannelQualityMapping.dart` and `package:mind/Bci/Models/BciChannelQuality.dart` are valid import paths. ✅
- **`.toList(growable: false)`** matches the existing inline maps exactly — no behavior drift. ✅

## Findings

### Minor — Task 2 / Task 3 understate a guaranteed unused import

The plan hedges in Task 4: "BciChannelQuality.dart may still be needed in the services for other references; verify before removing." In fact, after the refactor the domain import `package:mind/Bci/Models/BciChannelQuality.dart` becomes **definitely unused** in **both** services:

- In `BciPairingService.dart`, the only explicit references to `BciSignalLevel` / `BciChannelQuality` are inside `_mapLevel` and the inline map. The `channels` binding in `case BciSignalQualityUpdated(:final channels)` is type-inferred (the type is declared in `BciNotifierEvent.dart`, not this file), and line 103's `BciChannelQualityDTO` comes from the package, not the domain import. Once `_mapLevel` and the inline map are removed, nothing in the file names a domain symbol → the import is unused.
- The same holds for `BciDataService.dart`.

This is not a blocker — Task 4's instruction "Fix any unused-import lint introduced by the change" does cover it, and the verification gate (`flutter analyze lib/BciModule/`) will surface it. But the implementer would be better served if Tasks 2 and 3 stated outright: "also remove the now-unused `import 'package:mind/Bci/Models/BciChannelQuality.dart';`." Consider tightening the wording. (Non-blocking.)

## Positive Notes

- The placement guard (must live in `lib/`, not the package, with the explicit rationale) is stated clearly and is architecturally correct.
- Pure top-level functions (no class) is the right shape for a stateless mapper and keeps the call sites clean.
- Behavior-preservation is well controlled: verbatim switch, identical `growable: false`, no logic change — zero runtime risk.
- Settings are appropriate: no tests / minimal logging / no docs is correct for a mechanical de-duplication with no behavior change. No migration is involved (no DB/schema/proto touched).
- Task dependencies are correctly ordered (Task 1 → 2,3 → 4).

## Conclusion

The plan is accurate, complete, and correctly scoped. File paths, import paths, exported symbols, DTO shape, and the duplicated logic all verified against the codebase. The single finding is a minor wording improvement, not a correctness gap.

PLAN_REVIEW_PASS
