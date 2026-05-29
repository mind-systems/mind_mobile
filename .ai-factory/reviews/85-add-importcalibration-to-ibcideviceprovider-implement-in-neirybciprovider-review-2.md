# Code Review (Round 2): Add `importCalibration` to `IBciDeviceProvider` + implement in `NeiryBciProvider`

**Plan:** `.ai-factory/plans/85-add-importcalibration-to-ibcideviceprovider-implement-in-neirybciprovider.md`
**Prior review:** `.ai-factory/reviews/85-…-review-1.md`
**Files changed:**
- `lib/Bci/IBciDeviceProvider.dart` — new import + new abstract method (unchanged since Round 1)
- `lib/Bci/NeiryBciProvider.dart` — new `importCalibration()` implementation (one line added since Round 1)

## What changed since Round 1

The Round-1 review flagged one actionable issue:

> Finding 1: `individualPeakFrequency` is silently set to the SDK default `10.0` on import — pass `data.individualFrequency` instead so the legacy alias mirrors the actual peak.

Round-2 diff for `lib/Bci/NeiryBciProvider.dart` now includes:

```dart
individualFrequency: data.individualFrequency,
individualPeakFrequency: data.individualFrequency,   // ← added
individualPeakFrequencyPower: data.individualPeakFrequencyPower,
```

That fix is exactly the recommendation from Round 1. The legacy alias now travels the method channel with the user's real alpha peak instead of the SDK's hard-coded `10.0` default. (The plan markdown still describes the old "do not populate `individualPeakFrequency`" behaviour, but since the milestone instructions live in the roadmap and the plan, not in the code, this is a documentation drift inside the plan file rather than a code defect. Worth tightening the plan text in a future edit but not in scope for code review.)

## Verification

- Read both changed files in full (`IBciDeviceProvider.dart` 68 lines, `NeiryBciProvider.dart` only the new block at lines 388–409 plus the surrounding context already audited in Round 1).
- Confirmed `NeiryBciProvider implements IBciDeviceProvider` (line 34) — the new abstract method is concretely satisfied.
- No other class implements `IBciDeviceProvider` in the codebase, so no additional adapter needs updating.
- Architectural boundary still holds: `IBciDeviceProvider.dart` imports only domain models; the sole `neiry_kit` import remains inside `NeiryBciProvider.dart`.
- Mapping is now field-for-field complete relative to `neiry.IndividualNfbData`'s wire format (`toMap()` in `neiry_kit/lib/src/models/individual_nfb_data.dart` lines 90–103): every key that `toMap()` serializes — `ts`, `failReason`, `individualFrequency`, `individualPeakFrequency`, `individualPeakFrequencyPower`, `individualPeakFrequencySuppression`, `individualBandwidth`, `individualNormalizedPower`, `lowerFrequency`, `upperFrequency` — is now populated by the import path either directly or via the alpha-peak mirror.
- No new logging, no subscription bookkeeping, no `dispose()` impact. Fire-and-forget call matches the project pattern for write-side provider operations.
- `RULES.md` not violated (no stateful Module Service, no `App.dart` change, no constructor-injection break).
- No security surface: no user input, no persistence, no new IPC beyond a single method-channel write to an already-trusted SDK.

## Outstanding observations (non-blocking, deferred from Round 1)

These two items were called out in Round 1 as observations, not blockers; they remain unchanged and are restated only so the trail is complete. Neither needs a fix in this PR.

- `firstWhere` on `neiry.NfbCalibrationFailReason.values` throws `StateError` if the SDK ever adds a new enum value that an older build then encounters in its own previously-written cache. The plan accepts this; the eventual wiring task should wrap the import call or add an `orElse`.
- The forward mapping in `startCalibration()` coerces a null SDK timestamp to `DateTime.now()`, while `importCalibration` passes `data.calibratedAt` straight through. The asymmetry is benign but undocumented in the new dartdoc.

## Verdict

The single actionable finding from Round 1 has been addressed. No new findings. The change is small, correct, architecturally clean, and consistent with the surrounding code.

REVIEW_PASS
