# Code Review: Create `BioSample` value object + per-type encoder

**Plan file:** `.ai-factory/plans/67-create-biosample-value-object-per-type-encoder.md`
**Files changed:**
- `lib/Biometrics/BioSample.dart` (new, 122 lines)
- `.ai-factory/plans/67-...md` (new — plan doc)
- `.ai-factory/plan-reviews/67-...-plan-review-1.md` (new — plan review doc)

Only the Dart file affects runtime. Verification performed:
- `git status` / `git diff HEAD` reviewed (entire diff above).
- New file read in full.
- All five referenced domain models inspected (`CardioData`, `CardioHrvIndices`, `RrInterval`, `MotionData`, `SensorSource`, `BciNfbData`, `BciEmotionsData`).
- `flutter analyze lib/Biometrics/BioSample.dart` → `No issues found!`.

## Correctness — field-by-field check against actual source

| Plan / code reference | Source-of-truth file | Status |
|---|---|---|
| `cardio.timestamp` (DateTime) | `Models/CardioData.dart:12` `final DateTime timestamp` | ✓ |
| `cardio.heartRate` (double) | `Models/CardioData.dart:9` | ✓ |
| `cardio.metricsAvailable` (bool) | `Models/CardioData.dart:10` | ✓ |
| `cardio.hasArtifacts` (bool) | `Models/CardioData.dart:11` | ✓ |
| `cardio.source.name` (SensorSource enum) | `Models/SensorSource.dart` | ✓ |
| `cardio.hrv!.{rmssd,sdnn,pnn50,lf,hf,lfhf}` | `Models/CardioHrvIndices.dart` (all `double?`) | ✓ |
| `rr.timestamp / intervalMs / isArtifact / source.name` | `Models/RrInterval.dart` | ✓ |
| `nfb.timestamp / delta / theta / alpha / smr / beta` | `Bci/Models/BciNfbData.dart` | ✓ |
| `emotions.timestamp / attention / relaxation / cognitiveLoad / cognitiveControl / selfControl` | `Bci/Models/BciEmotionsData.dart` | ✓ |
| `motion.timestamp / accelerometer.{x,y,z} / gyroscope.{x,y,z} / source.name` | `Models/MotionData.dart` (record types) | ✓ |
| Import paths (`package:mind/Bci/Models/...`, relative `Models/...`) | All files exist at stated paths | ✓ |

Every accessor used in the file resolves. No type mismatch — `timestampMs` is `int` and every source is `DateTime.millisecondsSinceEpoch` (returns `int`). HRV doubles flow through as `dynamic` map values cleanly.

## Behavioral / runtime checks

- **No `DateTime.now()` anywhere** in the file — verified by reading the full source. All five factories use SDK-supplied `timestamp` fields, satisfying the explicit spec from `notes/32-biosample-sdk-timestamps.md` and avoiding the MEMS batch-collapse pitfall for `fromMotion`.
- **No `sessionId` field** — verified. The class has exactly three fields. Consistent with note 28's contract that the session ID is injected at wire-encoding time by `BiometricStreamClient.sendBatch`.
- **`hrv` sub-map is conditional** — `BioSample.fromCardio` constructs the base map first, then adds `'hrv'` only when `cardio.hrv != null`. Correct null-handling; no NPE risk. The `cardio.hrv!` non-null assertions inside the guarded block are safe.
- **`isArtifact` forwarded** in `fromRr`, per the deliberate "server decides filtering" stance.
- **Six raw motion axes** carried through unchanged (no client normalization), per spec.
- **Hard-coded `'source': 'neiry'`** in `fromNfb`/`fromEmotions` — correct because neither domain model exposes a `source` field today; the in-line doc comment captures the forward-migration plan.
- **`const` constructor** preserved; `final class` prevents subclassing; all fields `final` — value-object semantics intact.
- **No I/O, no streams, no Flutter imports** — pure data, as required for a hardware-/session-agnostic producer-side type.

## Architectural / contract alignment

- File lives in `lib/Biometrics/` (correct producer-side location per ARCHITECTURE.md and module-system rules; UI cannot reach it via the `packages/` boundary).
- Imports respect the convention used elsewhere in `lib/Biometrics/`: same-feature siblings via relative path (`Models/...`), cross-feature via `package:mind/...`.
- No coupling to Riverpod, gRPC, generated proto types, or any other layer — keeps the future router/batcher/client free to evolve.

## Minor observations (non-blocking, no action required)

1. **`Map<String, dynamic>` is mutable.** A caller could in principle mutate `sample.data['source'] = 'spoof'` after construction. There is no current caller that does this, and `BiometricBatcher` (M8) wraps the batch as `List.unmodifiable(...)` — but the inner map is still mutable. Not flagged as a defect because the milestone spec is explicit about the shape and does not require deep immutability; logging here only to note this design property.
2. **No `==` / `hashCode`.** The class has reference equality (two structurally identical `BioSample`s are not `==`). This is acceptable and correct given note 28 explicitly disallows client-side dedup. No `Set<BioSample>` usage exists.
3. **Future name collision with generated proto.** `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` defines a `class BioSample` (the wire type). This file does not import that proto, so there is no collision today. Milestone 7's implementer will need an `import ... as proto;` alias — flagged in the plan-review already; not a finding against this code.

## Conclusion

The implementation faithfully encodes every requirement of the plan and underlying spec notes (28 and 32). All five factories are present, all timestamps come from SDK clocks, the `hrv` sub-map is conditional, hard-coded sources are documented, no `sessionId` leakage, no I/O. The analyzer is clean. No bugs, security issues, type mismatches, or contract violations found.

REVIEW_PASS
