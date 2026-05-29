# Plan: Per-metric running-max normalization in `BciDataViewModel`

## Context
SDK NFB/Emotions values empirically exceed the documented 0..1 range, so `BciMetricBar`'s clamp saturates bars at the top and kills dynamic range. Normalize each metric inside `BciDataViewModel` against its own running max so the presentation layer always stays in 0..1 while the domain/server pipeline keeps emitting raw values.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Implementation

- [x] **Task 1: Add per-metric running-max fields to `BciDataViewModel`**
  Files: `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
  Add `import 'dart:math' as math;` at the top of the file (alongside the existing `dart:async` import). Inside the `BciDataViewModel` class, declare ten mutable `double` fields, each initialized to `1.0`, grouped logically:
  - NFB bands: `_maxDelta`, `_maxTheta`, `_maxAlpha`, `_maxSmr`, `_maxBeta`
  - Emotions: `_maxAttention`, `_maxCognitiveLoad`, `_maxRelaxation`, `_maxCognitiveControl`, `_maxSelfControl`
  Do not reset these in `build()` or anywhere else — they intentionally persist for the VM lifetime (Riverpod disposes the VM when the screen is left, which provides the implicit reset). Do not import `Models/BciNfbDTO.dart` / `Models/BciEmotionsDTO.dart` explicitly — they are reachable transitively through `Models/BciDataState.dart`; add direct imports only if the analyzer requires them when constructing the DTOs in Task 2.

- [x] **Task 2: Normalize NFB and Emotions in `_onServiceEvent` before setting state**
  Files: `packages/bci_module/lib/src/BciData/BciDataViewModel.dart`
  Rewrite `_onServiceEvent` so that the `BciDataStateUpdated` branch transforms the incoming `state` instead of assigning it directly. Steps inside the case:
  1. Take the raw `state.nfb` (nullable `BciNfbDTO`). If non-null, for each of the five band fields (`delta`, `theta`, `alpha`, `smr`, `beta`), when the raw value is non-null, update the matching `_maxX` field via `_maxX = math.max(_maxX, raw)`. Then build a new `BciNfbDTO` where each field is `raw == null ? null : raw / _maxX`. If `state.nfb` is null, pass `null` through.
  2. Do the same for `state.emotions` against the five emotion `_max*` fields, producing a new `BciEmotionsDTO` (or `null`).
  3. Construct a new `BciDataState` using the normalized `nfb` and `emotions` DTOs, and pass-through `heartRate`, `channels`, `batteryPercent`, `isConnected` from the incoming `state`. Either call the `BciDataState` constructor directly or use `state.copyWith(nfb: ..., emotions: ...)` — both are equivalent here; the constructor is more explicit and matches the milestone description.
  4. Assign the resulting state to `this.state`.
  Notes:
  - Each metric tracks its own max — never cross-normalize (e.g., do not divide `alpha` by `_maxBeta`).
  - With the `1.0` floor, values inside the SDK contract are a no-op; values above 1.0 ratchet the max up so subsequent samples stay proportional.
  - `BciMetricBar`'s `clamp(0..1)` remains the safety net for floating-point rounding and negative edge cases — do not touch it.
  - No new exports from the package; no doc updates.

<!-- orchestrator-sessions
planner: 54ad73b8-4251-47d6-b813-ed97de98d586
elapsed: 316
implementer: 79b7aa80-2f36-4c1d-a5b6-e0a7f74c84eb
-->
