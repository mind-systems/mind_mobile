# Code Review: Add `BciNfbData`, `BciCardioData`, `BciEmotionsData` domain models

**Plan file:** `.ai-factory/plans/53-add-bcinfbdata-bcicardiodata-bciemotionsdata-domain-models.md`
**Changed files:**
- `lib/Bci/Models/BciNfbData.dart` (new)
- `lib/Bci/Models/BciCardioData.dart` (new)
- `lib/Bci/Models/BciEmotionsData.dart` (new)

## Scope verification

`git status` shows only the three new domain model files plus the plan and plan-review artifacts. No collateral edits, no untracked changes. Plan tasks 1–3 are all marked `[x]`.

## Per-file review

### `lib/Bci/Models/BciNfbData.dart`
- `@immutable` class, `const` constructor, all fields `final double?` (`delta`, `theta`, `alpha`, `smr`, `beta`).
- Field names match `NfbUserState` mapping documented in `.ai-factory/notes/24-bci-data-screen.md` (line 80) and the downstream `BciNfbDTO` (line 177).
- Imports `package:flutter/foundation.dart` only — matches the style template `BciChannelQuality.dart`. No `neiry_kit` imports.
- Dartdoc reflects the plan's intent (raw NFB band amplitudes, 0–1, `null` when no reading yet).
- No defects.

### `lib/Bci/Models/BciCardioData.dart`
- `@immutable` class, `const` constructor, all three fields marked `required`: `final double heartRate`, `final bool metricsAvailable`, `final bool hasArtifacts`.
- Field types and names match note 24 (line 88) and the `BciDataService` mapping rule `heartRate = (metricsAvailable && !hasArtifacts) ? data.heartRate.round() : null` (line 152).
- Dartdoc explicitly flags `metricsAvailable` / `hasArtifacts` as transport flags consumers must gate on — aligns with the design intent that these are dropped at the DTO boundary.
- No `neiry_kit` imports. Style matches `BciChannelQuality.dart`.
- No defects.

### `lib/Bci/Models/BciEmotionsData.dart`
- `@immutable` class, `const` constructor, five `final double?` fields: `attention`, `relaxation`, `cognitiveLoad`, `cognitiveControl`, `selfControl`.
- Field names match note 24 (line 97). Field order differs from `BciEmotionsDTO` (note 24, line 170: `attention, cognitiveLoad, relaxation, cognitiveControl, selfControl`), but the parameters are named, so this is semantically irrelevant. Not a defect.
- Dartdoc reflects mapping origin (`EmotionsStates`) and value range.
- No `neiry_kit` imports. Style matches `BciChannelQuality.dart`.
- No defects.

## Cross-cutting concerns

- **Layering:** All three files contain only pure Dart + `@immutable`. No Flutter widgets, no Riverpod, no Drift, no `neiry_kit`. Matches the domain-layer rule in `mind_mobile/CLAUDE.md` ("Domain layer is pure Dart").
- **Runtime risk:** None. These are leaf value objects with no callers yet — they cannot break existing code. No migrations, no DB schema, no concurrent state.
- **Naming collisions:** Verified against the existing contents of `lib/Bci/Models/` — no collisions with `BciCalibrationEvent`, `BciChannelQuality`, `BciConnectionState`, `BciDeviceInfo`, `BciNotifierEvent`, `BluetoothPermissionDeniedException`.
- **Equality / hashCode:** Not implemented. Consistent with the sibling `BciChannelQuality` and explicitly out of scope for this milestone. Worth tracking for downstream consumers that may use `BehaviorSubject.distinct()` or test equality, but not a current defect.
- **JSON / serialization:** Not present. Not required by the plan or note 24 — these models do not cross the network boundary.

## Conclusion

The implementation matches the plan exactly and adheres to the existing `BciChannelQuality` template. No bugs, no security issues, no correctness problems, no runtime risks.

REVIEW_PASS
