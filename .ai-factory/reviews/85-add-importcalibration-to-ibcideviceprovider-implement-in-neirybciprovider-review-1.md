# Code Review: Add `importCalibration` to `IBciDeviceProvider` + implement in `NeiryBciProvider`

**Plan:** `.ai-factory/plans/85-add-importcalibration-to-ibcideviceprovider-implement-in-neirybciprovider.md`
**Files changed:**
- `lib/Bci/IBciDeviceProvider.dart` — new import + new abstract method
- `lib/Bci/NeiryBciProvider.dart` — new `importCalibration()` implementation

## Scope verification

- Both code files were read in full (`IBciDeviceProvider.dart` 67 lines; `NeiryBciProvider.dart` mostly unchanged outside the inserted block at lines 388–408).
- The `neiry_kit` side of the contract was verified by reading `neiry_kit/lib/src/models/individual_nfb_data.dart` (the `IndividualNfbData` constructor + `toMap()`) and the existing `firstWhere`-style enum mapping used in the forward direction (`startCalibration()` lines 366–380 of `NeiryBciProvider.dart`).
- No other `implements IBciDeviceProvider` exists in the codebase, so the new abstract method only needs the one concrete site that was updated.
- Doc comment correctly cross-references `BciCalibrationCompleted`, which is reachable via the existing `Models/BciCalibrationEvent.dart` import on line 3 of `IBciDeviceProvider.dart`.
- The architectural rule that only `NeiryBciProvider.dart` may import `neiry_kit` is preserved: the new interface import is `Models/NfbCalibrationData.dart`, which is pure-Dart and has no `neiry_kit` dependency.
- Project `RULES.md` is not violated (no stateful Module Service added, no `App.dart` change, no constructor-injection violation).

## Findings

### 1. `individualPeakFrequency` is silently set to the SDK default `10.0` on import — flagged by the plan review and not addressed

The plan-review for this milestone (`.ai-factory/plan-reviews/85-…-plan-review-1.md`, Finding 1) explicitly recommended adding `individualPeakFrequency: data.individualFrequency` to the `IndividualNfbData` constructor call, with reasoning quoted here:

> `IndividualNfbData.toMap()` (lines 90–103 of `individual_nfb_data.dart`) *does* serialize `individualPeakFrequency` over the method channel, and the value is sent to native code we don't control. Since the field is documented as a legacy alias of `individualFrequency`, the safer mapping is `individualPeakFrequency: data.individualFrequency`.

I re-confirmed against `neiry_kit/lib/src/models/individual_nfb_data.dart`:

- Line 17: constructor defaults `individualPeakFrequency = 10.0`.
- Lines 35–36: dartdoc states `Legacy alias for [individualFrequency], in Hz`.
- Line 95 of `toMap()`: `'individualPeakFrequency': individualPeakFrequency` — the field IS serialized into the method-channel payload and sent to native code.

The current implementation calls `neiry.IndividualNfbData(...)` without passing `individualPeakFrequency`, so the default `10.0` is what crosses the platform boundary. For a real user whose actual alpha peak is e.g. `9.2` Hz, the native calibrator receives `9.2` as `individualFrequency` and `10.0` as `individualPeakFrequency`. Whether this matters depends on whether the native side ever reads `individualPeakFrequency` from the import payload — but the field is in the wire format precisely because some code path can read it, and we should not assume otherwise from our side of the channel.

**Recommended fix** (one extra line in `lib/Bci/NeiryBciProvider.dart`, inside the new constructor call):

```dart
final neiryData = neiry.IndividualNfbData(
  timestamp: data.calibratedAt,
  failReason: neiry.NfbCalibrationFailReason.values
      .firstWhere((e) => e.name == data.failReason),
  individualFrequency: data.individualFrequency,
  individualPeakFrequency: data.individualFrequency,   // ← add
  individualPeakFrequencyPower: data.individualPeakFrequencyPower,
  ...
);
```

This is consistent with the forward mapping's behaviour: `startCalibration()` reads `data.individualFrequency` from the SDK but does not need to record the alias because, by the SDK's own documentation, the two represent the same physical quantity. Mirroring `individualFrequency` into `individualPeakFrequency` on import keeps them in sync and avoids substituting a hard-coded `10.0` for the user's measured peak.

This was a known concern at plan time and was not adopted in the implementation. Treating it as the one substantive finding of this review.

### 2. Unknown `failReason` string throws `StateError` — acceptable as documented, but a one-line `orElse` would harden against SDK enum drift

The implementation matches the plan exactly:

```dart
failReason: neiry.NfbCalibrationFailReason.values
    .firstWhere((e) => e.name == data.failReason),
```

`firstWhere` with no `orElse` throws `StateError` if no element matches. The plan acknowledges this and accepts it on the grounds that persisted data round-trips through the same enum. That holds today, but the failure mode if `neiry_kit` adds a new enum value (say, `signalLost`) is that an older build that imports its own previously-written cache would suddenly throw at the call site, taking down whatever wiring eventually calls `importCalibration` (typically during connect / cold-start).

This isn't a blocker for this milestone — no caller is wired yet — but it's worth recording so the eventual wiring task adds either an `orElse: () => neiry.NfbCalibrationFailReason.none` or an explicit try/catch at the caller. No fix required in this PR.

### 3. Doc-comment polish: asymmetric `timestamp` semantics

The forward mapping in `startCalibration()` coerces a null SDK timestamp with `data.timestamp ?? DateTime.now()` (line 369). On reverse, `importCalibration` passes `data.calibratedAt` straight through to `IndividualNfbData.timestamp`. This means an original null-timestamp calibration is not preserved as null on reimport — it gets the wall-clock from completion time. This is acceptable (the SDK accepts any `DateTime?`), but neither side documents the asymmetry. Optional one-sentence note in the dartdoc on `importCalibration` to make this obvious to a future reader. Not a correctness issue.

## Positive notes

- Implementation matches the plan line-for-line: import position, banner-comment style, insertion point, and field-by-field mapping.
- Architectural boundary preserved: `IBciDeviceProvider` stays free of any `neiry_kit` reference; the new domain-model import is the only change.
- No subscription bookkeeping added — correctly modelled as fire-and-forget, mirroring how `connect()` and `startCalibration()` already work in this file.
- `_calibrationSub`, `disconnect()`, `_doDispose()` are correctly left untouched.
- No security implications: no new user input handling, no new persistence, no new IPC surface beyond a single method-channel write to a vendor SDK that the project already trusts.
- Doc comment on the new interface method is precise and reiterates the "no plugin types may leak" invariant.

## Verdict

One actionable finding: passing `individualPeakFrequency: data.individualFrequency` in the `IndividualNfbData` constructor (Finding 1) — same rationale flagged by the plan-review and not yet applied. Findings 2 and 3 are observations for follow-up work and do not require changes in this PR.
