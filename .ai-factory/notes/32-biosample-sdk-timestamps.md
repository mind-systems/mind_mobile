# BioSample SDK Timestamps — Finding and Required Changes

**Date:** 2026-05-28
**Related:** `.ai-factory/notes/28-biometric-stream-pipeline.md` (Phase 21 M5), root note `01-biosample-timestamp-open-issues.md`

## Finding

The roadmap Phase 21 M5 (`BioSample` task) states:

> "`fromRr` uses `rr.timestamp`; `fromMotion` uses `motion.timestamp`; the other three use `DateTime.now()` because **their source streams carry no per-sample timestamp**."

This assumption is wrong. All three remaining classifiers in neiry_kit **do** expose per-sample SDK timestamps:

| neiry_kit type | Field | Notes |
|---|---|---|
| `CardioData` | `timestamp: DateTime` | Beat moment for the cardio aggregate |
| `NfbUserState` | `timestamp: DateTime` | EEG band snapshot moment |
| `EmotionsStates` | `timestamp: DateTime` | Emotions snapshot moment |
| `RRInterval` | `timestamp: DateTime` | Moment of the later peak ending the interval |

All timestamps are decoded from device timestamps (not monotonic clocks).

## Impact

Without this fix, `BioSample.fromCardio`, `fromNfb`, and `fromEmotions` use `DateTime.now()` at the Dart call-site — which is the batcher flush moment, not the physiological event moment. Jitter is ~50–200 ms relative to the actual cardiac/EEG event. After the fix all five sample types carry physiological timestamps.

## Required changes to roadmap

### Phase 21 M1 — `CardioData` domain model

Add `final DateTime timestamp` as a required field alongside `heartRate`, `metricsAvailable`, `hasArtifacts`, `source`, `hrv`.

### Phase 21 M2 — migrate `BciCardioData` → `CardioData`

In `NeiryBciProvider._onCardioState`, pass `timestamp: neiryCardioData.timestamp` when constructing `CardioData`.

### Existing models `BciNfbData` and `BciEmotionsData` (Phase 19)

These are already created without a `timestamp` field. Add `final DateTime timestamp` to both. Update `NeiryBciProvider` mapping:
- `_onNfbState(NfbUserState state)` → pass `timestamp: state.timestamp`
- `_onEmotionsState(EmotionsStates state)` → pass `timestamp: state.timestamp`

Can be done as a fix inside Phase 21 M3 (which refactors `NeiryBciProvider`) or as a standalone patch before M3.

### Phase 21 M5 — `BioSample` factory methods

Replace `DateTime.now()` in all three factories:

```dart
// Before
BioSample.fromCardio(CardioData c) → timestampMs: DateTime.now().millisecondsSinceEpoch
BioSample.fromNfb(BciNfbData n)    → timestampMs: DateTime.now().millisecondsSinceEpoch
BioSample.fromEmotions(BciEmotionsData e) → timestampMs: DateTime.now().millisecondsSinceEpoch

// After
BioSample.fromCardio(CardioData c) → timestampMs: c.timestamp.millisecondsSinceEpoch
BioSample.fromNfb(BciNfbData n)    → timestampMs: n.timestamp.millisecondsSinceEpoch
BioSample.fromEmotions(BciEmotionsData e) → timestampMs: e.timestamp.millisecondsSinceEpoch
```

The note in M5 "the other three use `DateTime.now()` because their source streams carry no per-sample timestamp" should be removed; the timestamp source table in M5 becomes identical to `rr` and `motion`.

## Reconstruction accuracy after fix

| Sample type | Timestamp source | Accuracy |
|---|---|---|
| `rr` | `rr.timestamp` (SDK) | Physiological |
| `motion` | `motion.timestamp` (SDK) | Physiological |
| `cardio` | `cardio.timestamp` (SDK) | Physiological |
| `nfb` | `nfbState.timestamp` (SDK) | Physiological |
| `emotions` | `emotionsState.timestamp` (SDK) | Physiological |

## Issue 3 — Dual cardiac streams (deferred, intentional)

`rr` and `cardio` both originate from the same Neiry device, but via **different algorithms**:
- `RrInterval` — client-side Dart peak detector (`_peakDetector.processBatch`) on raw PPG batches
- `CardioData.heartRate` — firmware's internal C classifier (`clCCardio`)

The only SDK fields that cannot be derived from RR intervals are `stressIndex` and `kaplanIndex` (Baevsky/Kaplan HRV indices), but these were deliberately excluded from our domain `CardioData` because they are not comparable across vendors (see roadmap M1 rationale).

**Why we stream both anyway:** to compare firmware-computed HR vs. client-computed HR server-side. Once there's enough data to evaluate whether they diverge meaningfully, `cardio` can be dropped from `BioStreamRouter` (remove `registerHeartRateSource` in `App.initialize()` and drop `BioSample.fromCardio`). Until then, both streams run.

`SignalWindowAssembler` must treat `rr` and `cardio` as independent signal types, never joining by timestamp equality.

## Issues NOT relevant to mind_mobile

From root note `01-biosample-timestamp-open-issues.md`:
- **Issue 1 (timestamp authority)** — server-side decision for `SignalWindowAssembler`; we produce `client_timestamp` and that's sufficient.
- **Issue 2 (clock skew / epoch boundaries)** — server-side mitigation strategy; no client action until mind_api decides on delta-correction protocol.
