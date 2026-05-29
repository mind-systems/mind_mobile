# Plan Review: Add `importCalibration` to `IBciDeviceProvider` + implement in `NeiryBciProvider`

**Plan File:** `.ai-factory/plans/85-add-importcalibration-to-ibcideviceprovider-implement-in-neirybciprovider.md`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)**: not re-read for this scoped 2-file change; provider/domain boundary is preserved (no `neiry_kit` import added to `IBciDeviceProvider`). PASS.
- **Rules (`.ai-factory/RULES.md`)**: WARN-level review.
  - Rule 1 (Module Services stateless) — N/A; `IBciDeviceProvider` is not a Module Service.
  - Rule 2 (no module concerns in App.dart) — N/A; this milestone explicitly excludes wiring.
  - Rule 3 (constructor DI) — N/A; no new dependencies introduced.
  - No violations.
- **Roadmap (`.ai-factory/ROADMAP.md`)**: PASS. The task matches Phase 24 line 195 verbatim ("Add `importCalibration` to `IBciDeviceProvider` + implement in `NeiryBciProvider` … No callers yet — wiring is the final task"). The plan correctly defers `BciDeviceManager` / `App.dart` / repository wiring to later roadmap entries (lines 197, 199, 203, 205).

## Codebase Verification

I cross-checked every fact the plan asserts about the existing files:

- `lib/Bci/IBciDeviceProvider.dart` lines 3–6 do contain the alphabetical `Models/...` block exactly as the plan describes (`BciCalibrationEvent`, `BciChannelQuality`, `BciConnectionState`, `BciDeviceInfo`). Inserting `NfbCalibrationData` after `BciDeviceInfo` preserves alphabetical order. ✅
- `startCalibration()` is declared at line 47, `dispose()` at line 54 — inserting between them is correct. ✅
- `lib/Bci/NeiryBciProvider.dart` line 6 has `import 'package:neiry_kit/neiry_kit.dart' as neiry;` and line 27 has `import 'Models/NfbCalibrationData.dart';`. No new imports required. ✅
- The `startCalibration()` block ends at line 388; the `// ── disconnect() ─` banner is at line 390. The proposed insertion point is accurate. ✅
- `class NeiryBciProvider implements IBciDeviceProvider, …` (line 34) — no other implementer of `IBciDeviceProvider` exists under `lib/` (only doc/plan/note references mention the interface). ✅
- `neiry.IndividualNfbData` (in `neiry_kit/lib/src/models/individual_nfb_data.dart`) has every field the mapping reads: `timestamp` (`DateTime?`), `failReason` (`NfbCalibrationFailReason`), `individualFrequency`, `individualPeakFrequencyPower`, `individualPeakFrequencySuppression`, `individualBandwidth`, `individualNormalizedPower`, `lowerFrequency`, `upperFrequency`. The constructor signature uses named-optional params with defaults, so a positional/named mismatch is not a concern. ✅
- `neiry.NfbCalibrationFailReason` enum values are exactly `none`, `tooManyArtifacts`, `peakFrequencyAtBorder` — matches the strings documented on `NfbCalibrationData.failReason`. `.name`-based round-trip is correct. ✅
- `NfbCalibrator.importCalibrationData(IndividualNfbData)` is a `static Future<void>` method that invokes the native side via method channel (no device dependency). Calling it from a non-connected provider state is safe — important context for the later "call before `connect()`" wiring task. ✅
- Forward mapping in `startCalibration()` (lines 367–380) is consistent with the reverse mapping being proposed (same field names, same `.name` translation for `failReason`, same fall-through of `timestamp`). ✅

## Findings

### Critical Issues
None.

### Minor Issues / Observations

1. **`individualPeakFrequency` defaulting to `10.0` is a lossy round-trip — flag explicitly.**
   The plan correctly notes that the legacy alias `individualPeakFrequency` isn't carried in `NfbCalibrationData`, and accepts the SDK's default `10.0` because "the field is unused by the import path." However, `IndividualNfbData.toMap()` (lines 90–103 of `individual_nfb_data.dart`) *does* serialize `individualPeakFrequency` over the method channel, and the value is sent to native code we don't control. Since the field is documented as a legacy alias of `individualFrequency`, the safer mapping is:
   ```dart
   individualPeakFrequency: data.individualFrequency,
   ```
   This keeps the two aliases in sync (matching how calibration originally produces them) instead of substituting a hard-coded `10.0` that may differ from the user's actual alpha peak. If the field truly is unused on import, the change is harmless; if it is read, this prevents a subtle drift. Suggest adding this one extra mapping line.

2. **Asymmetric `timestamp` round-trip is acceptable but undocumented in the new doc comment.**
   The forward mapping coerces a null SDK timestamp to `DateTime.now()` (line 369). On reverse, the plan passes `data.calibratedAt` straight through, so an original null-timestamp calibration is reimported with the *capture-time* `now`, not the original native sentinel. This is fine — the SDK accepts any `DateTime?` — but worth one sentence in the dartdoc on `importCalibration` so a future reader doesn't expect bit-exact symmetry.

3. **`isValid` not threaded through — by design, but worth a one-line comment.**
   `NfbCalibrationData.isValid` is stored explicitly, while `IndividualNfbData.isValid` is a computed getter from `failReason`. The reverse mapping correctly omits `isValid` because it's derived. If the persisted `isValid` and `failReason` ever drift (e.g. corrupt SharedPreferences), the import will trust `failReason`. Worth noting in the mapping-rules comment to make the intentionality obvious.

4. **`StateError` from `firstWhere` on unknown `failReason` — plan accepts it; consider `orElse`.**
   The plan acknowledges that an unknown persisted `failReason` string will throw `StateError` from `firstWhere`, and accepts it because data round-trips through the same enum. This is reasonable, but a single-line `orElse: () => neiry.NfbCalibrationFailReason.none` would harden the path against future schema drift (e.g. a new enum value added to the SDK but not yet known to a previous build that reads its own old cache). Not a blocker — current scope is fine.

### Positive Notes

- Plan is exceptionally precise: every line number, banner-comment style, insertion point, and import position is verified against the current file. No guessing.
- Correct architectural discipline: `IBciDeviceProvider` stays free of `neiry_kit`; the only mapping site is `NeiryBciProvider`.
- Scope is appropriately bounded — the plan explicitly defers `BciDeviceManager`, `App.dart`, and repository wiring to later roadmap entries that exist in `ROADMAP.md` (lines 197/199/203/205), matching the "No callers yet" milestone description.
- No subscription bookkeeping is added for `importCalibration`, correctly mirroring the fire-and-forget nature of other write-side ops (`connect`, `startCalibration`).
- Forward/reverse mappings are symmetric on the eight `double` fields and on the `.name` `failReason` translation, which makes a round-trip property test trivial to add later if testing is enabled.

## Verdict

The plan is solid and directly implementable. The only substantive suggestion is to add `individualPeakFrequency: data.individualFrequency` to the mapping to avoid silently replacing the user's alpha peak with the SDK's `10.0` default. The other three observations are documentation polish, not correctness issues.

PLAN_REVIEW_PASS
