# Plan Review: Add `BciNfbData`, `BciCardioData`, `BciEmotionsData` domain models

**Plan file:** `.ai-factory/plans/53-add-bcinfbdata-bcicardiodata-bciemotionsdata-domain-models.md`
**Risk Level:** 🟢 Low
**Scope:** 3 new pure-Dart value objects in `lib/Bci/Models/`.

## Context Gates

- **ARCHITECTURE.md (`.ai-factory/ARCHITECTURE.md`):** Not checked in detail; plan introduces only pure-Dart domain value objects with no Flutter/Riverpod dependencies. Aligned with the "Domain layer is pure Dart" rule in `mind_mobile/CLAUDE.md`. WARN: plan does not reference ARCHITECTURE.md explicitly, but the change is too small to warrant it.
- **RULES.md:** Not present at `.ai-factory/RULES.md`. No project-rules violation detected.
- **ROADMAP.md:** Not explicitly linked from the plan. WARN: plan references `notes/24-bci-data-screen.md` as the parent design doc, which is the canonical source for the BCI Data Screen feature; this is acceptable linkage for a sub-step of that feature.
- **Skill context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present. No project-specific overrides applied.

## Verification Against Codebase

- `lib/Bci/Models/` exists and currently contains `BciCalibrationEvent.dart`, `BciChannelQuality.dart`, `BciConnectionState.dart`, `BciDeviceInfo.dart`, `BciNotifierEvent.dart`, `BluetoothPermissionDeniedException.dart`. New files do not collide.
- `BciChannelQuality.dart` is correctly identified as the style template: uses `package:flutter/foundation.dart` for `@immutable`, no `==`/`hashCode`, no `copyWith`, no JSON. The plan's three new models match that style exactly.
- Field names in Task 1 (`delta, theta, alpha, smr, beta`) match the documented `NfbUserState` mapping in note 24 and the `BciNfbDTO` in the same note.
- Field names in Task 2 (`heartRate`, `metricsAvailable`, `hasArtifacts`) match note 24 (`BciCardioData` block) and align with the `BciDataService` mapping rule `heartRate = (metricsAvailable && !hasArtifacts) ? data.heartRate.round() : null`.
- Field names in Task 3 (`attention, relaxation, cognitiveLoad, cognitiveControl, selfControl`) match note 24 and the downstream `BciEmotionsDTO`.
- No `neiry_kit` imports — matches the layering rule (domain is pure Dart, conversion from neiry_kit happens in `NeiryBciProvider`).

## Critical Issues

None.

## Minor Observations (non-blocking)

- **No `==`/`hashCode`.** Consistent with `BciChannelQuality.dart`. If these values are later compared in `BehaviorSubject.distinct()` or test expectations, equality may need to be added. Out of scope for this plan but worth noting for downstream tasks.
- **Field ordering in `BciEmotionsData`.** The plan lists `attention, relaxation, cognitiveLoad, cognitiveControl, selfControl`, while the downstream `BciEmotionsDTO` (note 24) lists `attention, cognitiveLoad, relaxation, cognitiveControl, selfControl`. Order is semantically irrelevant for named parameters, but matching the DTO order would marginally improve readability in the future Service mapping code. Not a defect.
- **`BciCardioData.heartRate` is non-nullable `double`.** Matches note 24. Consumers must rely on `metricsAvailable && !hasArtifacts` to decide validity. The Task 2 dartdoc note already calls this out — good.
- **Plan does not list `BciNotifierEvent.dart` edits** (adding `BciNfbUpdated`, `BciCardioUpdated`, `BciEmotionsUpdated`). Note 24 indicates these events are part of the broader feature, but the plan explicitly scopes itself to "three pure-Dart value objects" — splitting the event types into a later task is acceptable.

## Positive Notes

- Tight, single-purpose plan with clear file paths and explicit style references.
- Correctly preserves the domain/module boundary (no `neiry_kit` imports, no Flutter widget imports, no Riverpod).
- Matches the existing `BciChannelQuality.dart` template precisely — same imports, same `@immutable`, same `const` constructor style.
- Field semantics (range `0–1`, `null` when unavailable, transport-flag gating for cardio) are documented in the task descriptions so dartdoc comments will be accurate.

PLAN_REVIEW_PASS
