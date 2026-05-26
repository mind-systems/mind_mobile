# Neiry Classifier Stream Timestamps — Research Findings

**Date:** 2026-05-28
**Source:** conversation context

## Key Findings

- Every Neiry classifier stream exposes a `DateTime timestamp` sourced from the C SDK struct (`timestampMilli`), not from Dart dispatch time.
- `BioSample.fromCardio()`, `fromNfb()`, `fromEmotions()` currently call `DateTime.now()` — this is a bug, not an approximation. SDK timestamps are already present in the emitted objects.
- Fixing this is trivial: replace `DateTime.now()` with `sample.timestamp` in each factory.
- Without the fix, Phase 20 WCSP Signal Reduction reconstructs an inaccurate physiological timeline with ~50–200 ms jitter per sample.

## Details

### Timestamp availability by stream

| Stream | Emitted type | Timestamp field | C source |
|---|---|---|---|
| `NfbClassifier.stateStream` | `NfbUserState` | `DateTime timestamp` | `clCNFB_UserState.timestampMilli` |
| `EmotionsClassifier.stateStream` | `EmotionsStates` | `DateTime timestamp` | `clCEmotions_States.timestampMilli` |
| `CardioClassifier.stateStream` | `CardioData` | `DateTime timestamp` | `clCCardio_Data.timestampMilli` |
| `CardioClassifier.rrStream` | `RRInterval` | `DateTime timestamp` | `clCPPGTimedData_GetTimestampMilli` per peak |
| `PhysioClassifier.stateStream` | `PhysiologicalStatesValue` | `DateTime timestamp` | same pattern |

All timestamps are wall-clock `int64_t` milliseconds since epoch, embedded in the C struct at the moment of physiological event — not at Dart callback delivery time.

### Native bridge mechanics

**iOS (Swift):** C struct callback extracts `state.timestampMilli`, packs into EventChannel map as `"ts": Int64`. Dart decodes: `DateTime.fromMillisecondsSinceEpoch(map['ts'])`.

**Android (Kotlin):** JNI layer (`nativeSetNfbStateSink` / `nativeSetEmotionsStateSink` / `nativeSetCardioStateSink`) packs timestamp into EventChannel map identically.

**PPG batch case:** PPG data arrives in batches; each sample has its own timestamp via `clCPPGTimedData_GetTimestampMilli(ppgData, i)`. iOS bridge iterates and collects `List<UInt64>` → Dart receives `PpgData.timestamps: List<int>`. `PpgPeakDetector` uses these per-sample timestamps when constructing `RRInterval`.

### Current BioSample factory issue

In Phase 21 mobile roadmap (Milestone 5 — `BioSample` value object):

```dart
// WRONG — current design intent
BioSample.fromNfb(NfbUserState state) => BioSample(
  timestamp: DateTime.now(), // ← Dart dispatch time, not event time
  sampleType: 'nfb',
  data: { 'alpha': state.alpha, ... },
);

// CORRECT — must use SDK timestamp
BioSample.fromNfb(NfbUserState state) => BioSample(
  timestamp: state.timestamp, // ← C struct timestampMilli, physiological event time
  sampleType: 'nfb',
  data: { 'alpha': state.alpha, ... },
);
```

Same applies to `fromEmotions(EmotionsStates)` and `fromCardio(CardioData)`.

### RR and MEMS were already correct

`BioSample.fromRr(RRInterval rr)` uses `rr.timestamp` (SDK) — correct.
`BioSample.fromMotion(MotionData motion)` uses `motion.timestamp` (SDK) — correct.

The newly confirmed fix brings the remaining three factories to the same accuracy level.

### Impact on Phase 20 WCSP

Signal Reduction Pipeline (Phase 20) relies on `client_timestamp` as the sole authoritative physiological time axis. With `DateTime.now()` in the factories, the server receives:
- `rr` samples: accurate to PPG peak moment
- `nfb`, `emotions`, `cardio` samples: accurate only to Dart callback delivery

This would cause misalignment at signal window assembly. With SDK timestamps, all sample types are physiologically aligned.

## Open Questions

- None blocking Milestone 5 implementation. The fix is clear.
- Consider whether `PhysioClassifier.stateStream` → `PhysiologicalStatesValue` will be used in Phase 21 (not currently in the milestone plan).
