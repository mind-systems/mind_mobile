# Code Review: Carry `NfbCalibrationData` through `BciCalibrationCompleted`

**Plan:** `.ai-factory/plans/84-carry-nfbcalibrationdata-through-bcicalibrationcompleted.md`
**Changed files:**
- `lib/Bci/Models/BciCalibrationEvent.dart`
- `lib/Bci/NeiryBciProvider.dart`
- `lib/Bci/BciDeviceManager.dart`

## Verification

### 1. `BciCalibrationEvent.dart`
- `import 'NfbCalibrationData.dart';` added at the top — sibling-file relative import is consistent with the file's existing conventions and avoids cycles (`NfbCalibrationData` imports only `package:flutter/foundation.dart`).
- `BciCalibrationCompleted` gains `final NfbCalibrationData data;` and a `const BciCalibrationCompleted(this.data);` constructor. Positional + required matches the style of `BciCalibrationStageFinished(this.stage)` and `BciCalibrationFailed(this.reason)`. ✅
- Dartdoc updated to describe the payload while preserving the "plugin types must not leak" warning (now correctly worded since the sealed base's own docstring already covers the rule).
- `const` constructor preserved — `NfbCalibrationData` is `@immutable` with a `const` constructor, so the variant can still be canonicalized when callers happen to pass a constant `NfbCalibrationData`. No callers do today, but the constraint costs nothing.

### 2. `NeiryBciProvider.dart`
- New import `'Models/NfbCalibrationData.dart'` inserted in alphabetical position within the `Models/...` block. ✅
- Mapping inside `startCalibration()` matches the field-by-field table in `.ai-factory/notes/30-nfb-calibration-history.md`, verified against `/Users/max/projects/mind/neiry_kit/lib/src/models/individual_nfb_data.dart`:
  - `data.timestamp` is `DateTime?` (sentinel `-1` decoded to `null`). `?? DateTime.now()` is the correct fallback. ✅
  - `data.isValid` getter returns `failReason == NfbCalibrationFailReason.none`. ✅
  - `data.failReason.name` produces `"none" | "tooManyArtifacts" | "peakFrequencyAtBorder"`, which are exactly the values documented as legal for `NfbCalibrationData.failReason`. ✅
  - All seven `double` fields exist on `IndividualNfbData` with matching names; type compatibility verified. ✅
  - `individualPeakFrequency` (legacy alias) is correctly omitted. ✅
- `const` correctly dropped from `BciCalibrationCompleted(mapped)` because `mapped` is built at runtime.
- `CalibrationStageFinished` branch, `onError` handler, subscription bookkeeping, and dispose flow are untouched as specified. ✅

### 3. `BciDeviceManager.dart`
- Single change: `case BciCalibrationCompleted():` → `case BciCalibrationCompleted(data: final _):`. The `final _` form is a Dart 3 wildcard variable pattern that destructures the field without binding it to a name — no `unused_local_variable` analyzer warning. ✅
- Case body preserved verbatim. Other cases (`BciCalibrationStageFinished`, `BciCalibrationFailed`) untouched. ✅
- No new imports needed (the wildcard pattern does not reference `NfbCalibrationData` by name; type comes from `BciCalibrationCompleted`'s declaration which is already imported).

## Cross-file compile check
- `lib/BciModule/BciPairingService.dart:172` still uses `case BciCalibrationCompleted():`. Bare class patterns continue to match an enriched variant — no change required and none made, consistent with the plan's "Cross-cutting verification" note. ✅
- No other matches for `BciCalibrationCompleted` exist outside the three changed files and `BciPairingService.dart` (verified via grep).
- Sealed-class exhaustiveness is preserved (no new variants introduced).

## Runtime correctness
- **Stream lifecycle:** `_calibrationController` is a broadcast `StreamController`; emitting a non-const value has no allocation or lifecycle implications.
- **Null safety:** `data.timestamp ?? DateTime.now()` and `data.failReason.name` cannot throw at runtime — both `failReason` (non-null, defaults to `none`) and the seven `double` fields are non-nullable in `IndividualNfbData`.
- **No race conditions / state changes:** the manager's case body is unchanged; behavior is identical to before for the `calibrating → ready` transition. The new payload is intentionally unused at the consumer end.
- **No migrations, no persisted-state changes** in this milestone — repository wiring is deferred to a later task per the plan.

## Findings

None. The implementation matches the plan and the source-of-truth mapping in `notes/30`, all types line up, all preserved code paths are byte-equivalent, and no existing consumer is broken.

REVIEW_PASS
