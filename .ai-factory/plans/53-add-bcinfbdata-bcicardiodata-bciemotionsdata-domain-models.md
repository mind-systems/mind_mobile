# Plan: Add `BciNfbData`, `BciCardioData`, `BciEmotionsData` domain models

## Context
Introduce three pure-Dart value objects in the BCI domain layer that will later carry NFB band amplitudes, cardio metrics, and emotion classifier outputs from the device provider through the notifier and into the module DTOs. See `.ai-factory/notes/24-bci-data-screen.md` for the full shapes and downstream usage.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Domain models

- [x] **Task 1: Create `BciNfbData` value object**
  Files: `lib/Bci/Models/BciNfbData.dart`
  Pure Dart `@immutable` class with `final double? delta, theta, alpha, smr, beta` (all in 0–1, `null` when unavailable). Constructor `const BciNfbData({this.delta, this.theta, this.alpha, this.smr, this.beta})`. No imports from `neiry_kit`; follow the same style as `lib/Bci/Models/BciChannelQuality.dart` (use `package:flutter/foundation.dart` for `@immutable`). Add a short dartdoc comment describing the field semantics (raw NFB band amplitudes, 0–1, `null` when no reading yet).

- [x] **Task 2: Create `BciCardioData` value object**
  Files: `lib/Bci/Models/BciCardioData.dart`
  Pure Dart `@immutable` class with `final double heartRate`, `final bool metricsAvailable`, `final bool hasArtifacts`. Constructor `const BciCardioData({required this.heartRate, required this.metricsAvailable, required this.hasArtifacts})`. No imports from `neiry_kit`. Match the style of `BciChannelQuality.dart`. Dartdoc note: `metricsAvailable` and `hasArtifacts` are transport flags; consumers gate valid readings via `metricsAvailable && !hasArtifacts`.

- [x] **Task 3: Create `BciEmotionsData` value object**
  Files: `lib/Bci/Models/BciEmotionsData.dart`
  Pure Dart `@immutable` class with `final double? attention, relaxation, cognitiveLoad, cognitiveControl, selfControl` (all 0–1, `null` when unavailable). Constructor `const BciEmotionsData({this.attention, this.relaxation, this.cognitiveLoad, this.cognitiveControl, this.selfControl})`. No imports from `neiry_kit`. Match the style of `BciChannelQuality.dart`. Dartdoc note: high-level emotion classifier outputs, mapped from `EmotionsStates`.

<!-- orchestrator-sessions
planner: 64688cbc-386b-41be-a007-40fb5dbbfd84
implementer: e393f23e-3b52-41aa-8b9d-ee3e94963183
-->
