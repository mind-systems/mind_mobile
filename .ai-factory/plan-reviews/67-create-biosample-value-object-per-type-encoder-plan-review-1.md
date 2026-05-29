# Plan Review: Create `BioSample` value object + per-type encoder

**Plan file:** `.ai-factory/plans/67-create-biosample-value-object-per-type-encoder.md`
**Target:** `lib/Biometrics/BioSample.dart` (new file)

## Code Review Summary

**Files Reviewed:** 1 plan + 7 codebase files (CardioData, CardioHrvIndices, RrInterval, MotionData, SensorSource, BciNfbData, BciEmotionsData) + 2 supporting notes (28-biometric-stream-pipeline.md, 32-biosample-sdk-timestamps.md) + 1 generated proto file
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`ARCHITECTURE.md`):** OK — `lib/Biometrics/` is the correct producer-side location; this milestone introduces a pure data type with no I/O, no streams, no domain-leaking dependencies. Aligns with the layered architecture (Repository → Notifier → Service → ViewModel) without violating any boundary.
- **Rules (`RULES.md`):** OK — none of the three rules apply (this is a pure data class, not a module Service, not App.dart wiring, no DI surface). No violations.
- **Roadmap (`ROADMAP.md`):** Implicit linkage via the explicit reference to "Milestone 5" in note `28-biometric-stream-pipeline.md`. WARN-level only: the plan does not name the roadmap milestone/phase ID directly in its `Context` block — adding "Phase 21, Milestone 5" would make the linkage explicit, but the note reference is enough to trace.

### Correctness Verification (field-by-field, against actual codebase)

Every field/method referenced in the plan was checked against the source-of-truth model files:

| Plan reference | Actual source | Match |
|---|---|---|
| `cardio.timestamp / heartRate / metricsAvailable / hasArtifacts / source / hrv` | `Models/CardioData.dart` | ✓ |
| `cardio.hrv!.rmssd / sdnn / pnn50 / lf / hf / lfhf` | `Models/CardioHrvIndices.dart` (all `double?`) | ✓ |
| `rr.timestamp / intervalMs / isArtifact / source` | `Models/RrInterval.dart` | ✓ |
| `nfb.delta / theta / alpha / smr / beta / timestamp` | `Bci/Models/BciNfbData.dart` (bands `double?`, timestamp required) | ✓ |
| `emotions.attention / relaxation / cognitiveLoad / cognitiveControl / selfControl / timestamp` | `Bci/Models/BciEmotionsData.dart` | ✓ |
| `motion.accelerometer.{x,y,z} / gyroscope.{x,y,z} / timestamp / source` | `Models/MotionData.dart` (record types) | ✓ |
| `source.name` (Cardio, RR, Motion) | `Models/SensorSource.dart` enum (`neiry, garmin, polar, appleHealth`) | ✓ |
| Import path `Models/CardioData.dart` | Relative path resolves correctly from `lib/Biometrics/BioSample.dart` | ✓ |
| Import path `package:mind/Bci/Models/BciNfbData.dart` etc. | Confirmed file location | ✓ |

All five SDK timestamp readings (`cardio.timestamp`, `rr.timestamp`, `nfb.timestamp`, `emotions.timestamp`, `motion.timestamp`) are now valid — note `32-biosample-sdk-timestamps.md` confirms each domain model carries a SDK-decoded `DateTime`. The plan correctly absorbs this correction (no leftover `DateTime.now()` calls anywhere).

### Critical Issues

None.

### Minor Observations (non-blocking)

1. **Name collision with generated proto class — future-milestone concern, not this one.**
   `lib/Core/Grpc/generated/module_biometric_stream.pb.dart` already defines `class BioSample` (the wire type) and `class BioSampleBatch`. Note 28 pseudo-named the wire class `BioSampleProto`, but in reality the generated name is `BioSample`. This milestone (M5) only creates the domain class and is not affected — but when Milestone 7 (`BiometricStreamClient`) lands, the implementer will need an `import ... as proto;` alias (or rename the domain class). The current plan does not need to do anything about this; flagging it so the next milestone planner is aware.

2. **Map-typed `data` has reference equality.**
   `Map<String, dynamic>` does not implement value equality, so two `BioSample` instances with identical contents will not be `==`. This is acceptable per note 28 ("no client-side dedup") and per Milestone 8 (batcher just buffers and flushes), so the plan does not need `==`/`hashCode`. Worth keeping in mind if a future caller ever wants to put `BioSample` in a `Set`.

3. **Mixed import styles.**
   Plan instructs to use `package:mind/Bci/Models/...` (absolute) for BCI models and `Models/...` (relative) for Biometrics models. The mix is justified (cross-feature vs. same-feature) and matches the convention used by existing files in `lib/Biometrics/Models/` (`import 'SensorSource.dart';`). No action required.

4. **Class-level doc comment scope.**
   The plan asks for a doc comment noting "no `sessionId` by design" and "timestamps from SDK clocks." Good — this preempts the most likely future misreading. Consider also noting that `data` carries a `'source'` key on every sample (uniform invariant across all five factories) — useful for downstream consumers reading the map.

### Architectural Alignment

- **Hardware-agnostic** ✓ — the value object is unaware of Neiry / Garmin / Polar specifics; the `'source'` field is the only carrier of origin.
- **Session-agnostic** ✓ — `sessionId` deliberately absent; injected at wire-encoding time (note 28 §"Why no sessionId on BioSample").
- **Pure data** ✓ — no streams, no I/O, no Flutter imports needed.
- **Module-system compliance** ✓ — file lives in `lib/Biometrics/`, never in `packages/`. UI cannot reach it (and per note 28 §"App.shared is not exposed to UI", does not need to).

### Positive Notes

- The plan correctly identifies and embeds the timestamp fix from note 32, eliminating all three `DateTime.now()` calls from the original note 28 sketch. The rationale for using SDK timestamps on `motion` (batch collapse risk) is preserved in the plan text.
- Hard-coded `'source': 'neiry'` for `nfb`/`emotions` is justified inline with a clear forward-migration plan ("when a non-Neiry EEG provider lands, add `source` to the domain model and read from there"). Matches note 28's documented stance.
- The plan deliberately forwards `isArtifact` ("the server decides filtering") rather than client-side filtering — respects the architectural contract that analytics decisions live server-side.
- All file paths, import paths, and field accessors verified against actual source files — no API drift.

### Conclusion

The plan is accurate, scoped, and faithfully encodes both the M5 specification (note 28) and the timestamp correction (note 32). No missing steps, no wrong codebase assumptions, no architectural mistakes, no security concerns, no migration gaps. Field-by-field verification against the actual model files passed cleanly.

PLAN_REVIEW_PASS
