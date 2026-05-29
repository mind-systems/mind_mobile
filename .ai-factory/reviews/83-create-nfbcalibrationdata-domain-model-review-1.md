# Code Review: Create `NfbCalibrationData` domain model

**Plan:** `83-create-nfbcalibrationdata-domain-model.md`
**Files reviewed in full:** `lib/Bci/Models/NfbCalibrationData.dart` (new), plus reference siblings `lib/Bci/Models/BciNfbData.dart`, `lib/Bci/Models/BciDeviceInfo.dart`, and the JSON-pattern source `lib/BreathModule/Models/ExerciseSet.dart`.
**Risk Level:** 🟢 Low — single-file additive value-object; no callers wired in this milestone.

## Scope verification

`git status` shows three staged additions:
- `.ai-factory/plan-reviews/83-create-nfbcalibrationdata-domain-model-plan-review-1.md` (review doc, non-code)
- `.ai-factory/plans/83-create-nfbcalibrationdata-domain-model.md` (plan doc, non-code)
- `lib/Bci/Models/NfbCalibrationData.dart` (the only source file change)

No other code files touched. Matches the plan's "Do not modify any other file" constraint.

## Implementation vs. plan checklist

| Plan requirement | Implementation | Result |
|---|---|---|
| Pure Dart, only `package:flutter/foundation.dart` import | Line 1: `import 'package:flutter/foundation.dart';` only | ✅ |
| No `neiry_kit` import | Confirmed absent | ✅ |
| `@immutable` annotation | Line 8 | ✅ |
| `const` constructor, all required named params | Lines 30–41 | ✅ |
| Field set & order: `calibratedAt`, `isValid`, `failReason`, then 7 doubles in specified order | Lines 10–28 — order matches plan exactly | ✅ |
| Class-level Dartdoc explaining persistence purpose + plugin independence | Lines 3–7 | ✅ |
| `failReason` Dartdoc enumerates the three allowed values | Lines 13–19 | ✅ |
| `toJson()` returns map with camelCase keys matching field names | Lines 43–56 — all 10 keys match field identifiers exactly | ✅ |
| `calibratedAt` serialized via `toIso8601String()` | Line 45 | ✅ |
| `fromJson` parses `calibratedAt` with `DateTime.parse` | Line 60 | ✅ |
| `isValid` / `failReason` cast directly | Lines 61–62 | ✅ |
| Each `double` cast via `(json['…'] as num).toDouble()` | Lines 63–69 — all seven | ✅ |
| Mirror `ExerciseSet.dart` style (no codegen, plain map literal + factory) | Confirmed | ✅ |

## Correctness analysis

1. **JSON round-trip.** All ten `toJson` keys correspond 1:1 to `fromJson` reads with identical spellings — verified by visual comparison across lines 43–55 and 60–69. No typos.
2. **Numeric tolerance.** `(json['…'] as num).toDouble()` correctly handles both `int` (e.g. `0`, `10` decoded from whole-number JSON) and `double` payloads. This is more defensive than `ExerciseSet.fromJson`, justified here because frequency boundaries (`lowerFrequency`, `upperFrequency`) are commonly integer-valued.
3. **`DateTime` round-trip.** `toIso8601String()` preserves timezone information (UTC vs. local) when the source `DateTime` is UTC, and `DateTime.parse` is the inverse. Standard idiom — no precision loss for SharedPreferences-scoped persistence.
4. **`const` constructor + `@immutable` + all-`final` fields.** Consistent with `BciNfbData` (lines 7–22) and `BciDeviceInfo` (lines 8–17). Allows compile-time constant instances where useful and signals value semantics.
5. **No equality / hashCode override.** Matches the neighbouring `BciNfbData` and `BciDeviceInfo`, which also omit them. Not a defect at this layer — if downstream Phase 24 work needs set-membership it can be added then.
6. **No null safety pitfalls.** All fields are non-nullable; constructor enforces presence. `fromJson` will throw `TypeError` on missing/null keys, which is the right failure mode for SharedPreferences-stored data (corruption surfaces immediately rather than silently producing a partially-initialised object).

## Runtime risk check

- **Missing migrations:** none — there is no Drift/SQLite involvement.
- **Type mismatches:** none observed; casts at boundaries are explicit.
- **Race conditions:** none — pure value object with no mutable state or async work.
- **Dependency leakage:** none — the only import is `package:flutter/foundation.dart` for `@immutable`, the same minimal surface used by the other `lib/Bci/Models/` files.
- **`flutter analyze` concerns:** none predicted — code compiles in isolation, no unused fields, no unused imports.

## Style / consistency notes

- Field grouping (`calibratedAt`/`isValid` block, doc'd `failReason` block, doubles block) reads cleanly and mirrors the spacing rhythm used in `BciNfbData`. No nitpicks.
- Dartdoc on the class is two sentences and explanatory rather than a code summary — appropriate per global doc-style guidance ("describe behavior, not code").
- Method ordering (fields → constructor → `toJson` → `fromJson`) matches `ExerciseSet.dart` (lines 7–58).

## Findings

None.

REVIEW_PASS
