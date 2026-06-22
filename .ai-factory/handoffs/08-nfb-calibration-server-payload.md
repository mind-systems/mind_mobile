# Handoff — NFB calibration server payload (what to persist after calibration)

## 1. Frame
A scoping/decision task: review what `mind_mobile` persists to the server after an NFB calibration and align it with what the neiry SDK actually needs to *re-import* a calibration (skip recalibration). Chat is compacted — the knowledge is in the files referenced here; rehydrate from them, don't trust memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `lib/Bci/NfbCalibrationGrpcApi.dart` — exactly what we send (`record()`, L9-22) and read back (`_recordToDomain()`, L36-51). **This is the whole subject.**
- `mind_mobile/proto/nfb_calibration.proto` — the wire contract (`NfbCalibrationRecord` L12-25, `RecordNfbCalibrationRequest` L33-44). **Note the gap in §3.**
- `lib/Bci/Models/NfbCalibrationData.dart` — the domain model (all 9 calibration floats + `isValid`/`failReason`/`calibratedAt`); field meanings documented at L13-29.

### Read on demand
- `lib/Bci/NeiryBciProvider.dart` — SDK→domain mapping of `CalibrationCompleted` (~L375-389) and the (currently unused) `importCalibration()` impl (~L404-420).
- `lib/Bci/NfbCalibrationRepository.dart` — local SharedPreferences cache + fire-and-forget server sync + `refreshFromServer`/`record`/`list` orchestration.
- `neiry_kit/example/lib/screens/calibration_screen.dart` (L349-380, "Use NFB Calibration" toggle) + `neiry_kit/example/lib/providers/nfb_calibration_provider.dart` — the reference feature the user is modelling against.
- `neiry_kit/official/Capsule v2.0.72/CapsuleAPI/Linux/Include/CNFBCalibrator.h` — native `clCIndividualNFBData` struct + `clCNFBCalibrator_ImportIndividualNFBData` (import takes the FULL struct).
- `mind_api/proto/nfb_calibration.proto` + the `NfbCalibration` service/entity/migration in `mind_api` — the server side (proto source of truth lives here, NOT in mobile).
- `docs/bci/nfb-calibration.md` — existing behaviour doc (local cache, server sync, "calibration always user-initiated per connect").

## 3. Current state

**Established this session (all code-verified):**
- **What we send today** (`NfbCalibrationGrpcApi.record`, L10-22): `deviceSerial`, `calibratedAt`, `isValid`, `failReason`, `individualFrequency`, `individualPeakFrequencyPower`, `individualPeakFrequencySuppression`, `individualBandwidth`, `individualNormalizedPower`, `lowerFrequency`, `upperFrequency`.
- **We do NOT send `individualPeakFrequency` at all.** The proto has `individual_peak_frequency_power` (a *different* field) but **no** `individual_peak_frequency`. So one of the two fields the user considers essential is **absent from the contract**.
- **The gap is already known:** `_recordToDomain` (L42-43) substitutes `individualPeakFrequency: r.individualFrequency` behind `// TODO(mind_api Phase 29): use r.individualPeakFrequency with the <=0 sentinel rule.` — i.e. on read-back peak-frequency is faked from base frequency.
- **`importCalibration` is never called in mind_mobile.** It is only *declared* (`IBciDeviceProvider.dart:64`) and *implemented* (`NeiryBciProvider`); `grep` finds no caller. So the "import stored calibration to skip recalibration" feature (the neiry toggle) is **not wired in our app** — we persist calibration but never re-import it. Persisting the "right" fields only pays off once import is wired (or for another consumer, e.g. mind_web).
- **Neiry SDK import takes the full struct.** `clCNFBCalibrator_ImportIndividualNFBData` consumes the whole `clCIndividualNFBData` (failReason, individualFrequency, individualPeakFrequency, individualPeakFrequencyPower, suppression, bandwidth, normalizedPower, lower, upper). So at the SDK level import accepts all fields — the user's "only freq + peakFreq are used" is a hypothesis to **verify**, not a settled fact.

**User's position (the thing to validate/act on):**
- Persist **only** `individualFrequency` + `individualPeakFrequency` — the params neiry's "Use NFB Calibration" toggle uses to import and skip recalibration.
- Stop sending the signal-power fields (`individualPeakFrequencyPower` etc.) — believed unnecessary.

**Calibration values look healthy** (user ran several runs, all `isValid: true`): e.g. `individualFrequency` ~8.8–9.9 Hz, `individualPeakFrequency` 7.5–10.2 Hz across full/quick × eyes open/closed. So the data is good; this task is purely about *which* fields cross the wire.

**Uncommitted working-tree state:** none for this task (handoff only). Prior committed work this session: Phases 52 & 53 in `ROADMAP.md` + notes 145/148/150 (BCI reconnect + retry-failed-calibration) — unrelated to this payload question, already committed as `Roadmap update`.

## 4. Next step
Decide the target payload, then act. Concretely, resolve in order:
1. **Confirm the minimal field set** the neiry SDK actually needs on import — inspect the example's "Use NFB Calibration" toggle (`calibration_screen.dart:349` → `nfb_calibration_provider.dart`) to see what it imports, and/or ask the neiry team. Hypothesis to confirm/refute: only `individualFrequency` + `individualPeakFrequency` matter; the rest are derived/ignored.
2. **Close the proto gap:** `individual_peak_frequency` is missing from `nfb_calibration.proto`. Adding it is a **`mind_api/proto`** change (proto is owned by mind_api — mobile must not author it). Order: change `mind_api/proto` → implement in `mind_api` (entity/migration/service) → copy proto into `mind_mobile/proto/` → `./scripts/gen_proto.sh` → update `NfbCalibrationGrpcApi`.
3. **Decide what to drop:** if only freq+peakFreq are needed, remove the power/suppression/bandwidth/normalizedPower/lower/upper fields from the contract (server + proto + mobile send/read) — or keep some for analytics. Product/decision call.
4. **Flag (separate):** import is unwired — decide whether wiring the skip-recalibration feature is in scope or a follow-up.

This is a **cross-project** task (mind_api proto+service, mind_mobile client, possibly mind_web). The user wants the *next agent* to drive it; the current pair will answer questions.

## 5. Working discipline
- **Discuss/decide before implementing.** The user repeatedly chose to settle the design first, then hand implementation to a separate agent. Do not start coding the payload change without confirming the field set.
- No auto-commit; show diff / confirm before committing. Roadmap commits use the exact message `Roadmap update` (amend if the last commit is an unpushed `Roadmap update`).
- All generated/edited files in English.
- **Proto ownership:** `mind_api/proto/` is the single source of truth. Mobile must never author or symlink `.proto`; it copies the updated file and regenerates (`./scripts/gen_proto.sh`). Any contract change starts in `mind_api`.
- Plan artifacts are the deliverable for planning steps — do not implement in the same session a plan is created.

## 6. Error log
- **Do not assume the proto already carries `individual_peak_frequency`.** It does not — it has `individual_peak_frequency_power`, a different field. Conflating the two is the central trap: the field the user wants is the one that is missing, and the similarly-named power field is the one he wants to drop.
- **Do not assume persisting fields does anything observable today.** `importCalibration` has no caller — the round-trip that would *use* the saved fields is not wired, so "fixing the payload" alone changes nothing user-visible until import is hooked up.

## 7. Orientation
- **`individualPeakFrequency` vs `individualPeakFrequencyPower` — two different fields, names one word apart.** Peak-frequency (Hz, e.g. 10.0) is what the user wants to *add*; peak-frequency-*power* (uV²/Hz, e.g. 3e-11) is what he wants to *remove*. The proto currently has the latter and not the former.
- **"record" (send) vs "list/import" (read back) are separate directions.** `record()` sends to server; `list()` + `_recordToDomain()` read back; `importCalibration()` would push domain data into the SDK. The peak-frequency substitution hack lives only on the read-back side.

## 8. Domain model spine
- **The proto contract is owned by `mind_api`.** Pointer: `mind_api/proto/nfb_calibration.proto`. Mobile's `mind_mobile/proto/nfb_calibration.proto` is a copy; regenerate after the source changes. Don't re-litigate "edit the mobile proto directly".
- **Calibration "identity" for skip-recalibration is (hypothesised) `individualFrequency` + `individualPeakFrequency`.** Treat as unconfirmed until the neiry example/team validates which fields the SDK import actually consumes. Pointer: `neiry_kit` example toggle + `CNFBCalibrator.h`.
