# Review 2: Extract capability mixins + clean `IBciDeviceProvider`

## Scope

Re-reviewed `git diff HEAD` after the changes from review-1 were addressed.

Same set of touched files as round 1:
- `lib/Biometrics/IHeartRateSource.dart`, `IRrIntervalSource.dart`, `IEegBandsSource.dart`, `IEmotionsSource.dart`, `IMotionSource.dart` (new)
- `lib/Bci/IBciDeviceProvider.dart` (capability getters removed)
- `lib/Bci/NeiryBciProvider.dart` (RR + MEMS wiring, six interfaces)
- `lib/Bci/BciDeviceManager.dart` (three capability sources via ctor)
- `lib/Core/App.dart` (single provider passed to four roles)

## Delta from review-1

Both round-1 findings are resolved:

- **`MEMSClassifier` construction moved into `connect()`'s try block** — `lib/Bci/NeiryBciProvider.dart:160` now sits alongside the other three classifier constructions inside the guarded section, matching the symmetry the previous review asked for.
- **`connect()`'s catch block now disposes `_memsClassifier`** — `lib/Bci/NeiryBciProvider.dart:174-177` mirrors the existing per-classifier cleanup pattern (try/empty-catch, then null the field), keeping the failure path leak-free.
- **`_subscribeDeviceStreams()` only subscribes now** — the MEMS classifier construction line was correctly removed from there, and the existing safety comment was widened to "All four classifiers are guaranteed non-null here".

Everything else still matches the plan exactly: capability interfaces declared correctly, `IBciDeviceProvider` trimmed to device-class concerns, `NeiryBciProvider` implements all six interfaces, RR/MEMS subscription + cancel + controller-close pairs are present, RR handler passes `isArtifact` through and uses SDK `rr.timestamp`, MEMS handler unrolls batches into per-sample `MotionData` with each sample's SDK `s.timestamp`, `BciDeviceManager` capability getters delegate to the new sources (RR and Motion intentionally bypass the manager per spec), and `App.dart` wires the single `bciProvider` instance into all four roles.

No new findings.

REVIEW_PASS
