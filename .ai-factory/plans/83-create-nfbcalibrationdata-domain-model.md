# Plan: Create `NfbCalibrationData` domain model

## Context
Introduce a pure-Dart domain model that captures the result of an NFB (Neurofeedback) calibration so it can be persisted via SharedPreferences and consumed across the BCI domain without leaking the `neiry_kit` plugin types. This is a single-file additive change with no callers updated in this milestone.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain model

- [x] **Task 1: Create `NfbCalibrationData` model with JSON serialization**
  Files: `lib/Bci/Models/NfbCalibrationData.dart`
  Create a new immutable, pure-Dart class. Follow conventions from neighbouring `lib/Bci/Models/BciNfbData.dart` and `lib/Bci/Models/BciDeviceInfo.dart`:
  - Annotate the class with `@immutable` and import only `package:flutter/foundation.dart` (for `@immutable`). **Do not import `neiry_kit`**.
  - Declare a `const` constructor with **all fields required** (use `required` named parameters, matching the style of `BciNfbData` / `BciDeviceInfo`).
  - Fields (in this order):
    - `final DateTime calibratedAt;`
    - `final bool isValid;`
    - `final String failReason;` — enum-like string, allowed values: `"none"`, `"tooManyArtifacts"`, `"peakFrequencyAtBorder"`. Document allowed values in a Dartdoc comment above the field.
    - Seven `double` fields:
      - `final double individualFrequency;`
      - `final double individualPeakFrequencyPower;`
      - `final double individualPeakFrequencySuppression;`
      - `final double individualBandwidth;`
      - `final double individualNormalizedPower;`
      - `final double lowerFrequency;`
      - `final double upperFrequency;`
  - Add `Map<String, dynamic> toJson()` returning a map with **camelCase keys matching the field names** exactly. Serialize `calibratedAt` as an ISO-8601 string via `calibratedAt.toIso8601String()`. All other fields serialized as primitive `bool` / `String` / `double`.
  - Add `factory NfbCalibrationData.fromJson(Map<String, dynamic> json)` that:
    - Parses `calibratedAt` with `DateTime.parse(json['calibratedAt'] as String)`.
    - Reads `isValid` as `bool`, `failReason` as `String`.
    - Reads each `double` field by casting `(json['<field>'] as num).toDouble()` to be tolerant of JSON-decoded `int` values.
  - Add a class-level Dartdoc comment explaining the model holds the latest NFB calibration result for SharedPreferences persistence and that it is a domain projection independent of `neiry_kit`.
  - Mirror the JSON style of `lib/BreathModule/Models/ExerciseSet.dart` (plain `toJson()` map literal + `factory fromJson` with explicit casts) — no `json_serializable`, no code generation.
  - Do not modify any other file.

<!-- orchestrator-sessions
planner: 906ba51a-1d1d-41c4-9f88-9e56e998285b
elapsed: 277
implementer: 15d0bd95-70b2-4430-ab9f-cc3f10573789
-->
