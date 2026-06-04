# Plan: Add `impedanceOhm` to `BciChannelQualityDTO` and mapper

## Context
Expose the per-channel impedance value across the domain → module boundary so the BCI pairing UI can later display it. Currently `BciChannelQualityDTO` carries only `channelName` and `quality`, and the mapper drops `impedanceOhm`.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Assumptions (spec deviations — resolved against actual code)
- The spec note (`74-bci-channel-quality-impedance-dto.md`) describes a `mapChannel(BciChannelQuality)` helper, but the real mapper file uses `mapBciChannelQualities(List<BciChannelQuality>)` with inline per-channel construction (`channels.map((c) => BciChannelQualityDTO(...))`) and `mapBciSignalLevel(c.level)`. Apply the change inside that existing inline map — do not introduce a new `mapChannel` method.
- The spec/milestone says add `final int? impedanceOhm`, but the domain field `BciChannelQuality.impedanceOhm` is **`double`** (non-nullable), not `int`. To avoid a lossy/invalid `double → int?` assignment, declare the DTO field as **`final double? impedanceOhm`** and pass `c.impedanceOhm` through directly with no conversion. Keep it nullable (constructor param optional) per the spec's intent that hardware may not always report a meaningful value, even though the domain currently always supplies one.

## Tasks

### Phase 1: DTO + mapper

- [x] **Task 1: Add `impedanceOhm` field to `BciChannelQualityDTO`**
  Files: `packages/bci_module/lib/src/BciPairing/Models/BciChannelQualityDTO.dart`
  Add `final double? impedanceOhm;` to the class and an optional `this.impedanceOhm,` parameter to the `const` constructor (after the existing `required` params). Do not make it `required` — existing call sites that omit it must still compile.

- [x] **Task 2: Pass `impedanceOhm` through the mapper** (depends on Task 1)
  Files: `lib/BciModule/BciChannelQualityMapping.dart`
  In `mapBciChannelQualities`, add `impedanceOhm: c.impedanceOhm,` to the inline `BciChannelQualityDTO(...)` construction inside `channels.map(...)`. No type conversion — `c.impedanceOhm` (double) maps 1:1 to the nullable DTO field.

## Notes
No UI change. `BciImpedanceSection` does not yet read the new field — that is a separate future task. After these two edits, run `flutter analyze` (full path `/usr/local/bin/flutter`) on the affected packages to confirm no call sites break.
