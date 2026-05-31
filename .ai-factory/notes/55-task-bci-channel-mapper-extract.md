# Task Spec — Extract the duplicated BCI channel-quality mapper into `lib/BciModule/`

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 44 E1 (note 39 Area E)

## Current state
`_mapLevel(BciSignalLevel)→BciSignalQuality` and the `BciChannelQuality→BciChannelQualityDTO` list-map are duplicated verbatim in `lib/BciModule/BciPairingService.dart` and `lib/BciModule/BciDataService.dart`. (Verified identical: green→good, yellow→fair, red→poor — no logic drift.)

## Target
- Create `lib/BciModule/BciChannelQualityMapping.dart` with:
  - top-level `BciSignalQuality mapBciSignalLevel(BciSignalLevel level)`;
  - top-level `List<BciChannelQualityDTO> mapBciChannelQualities(List<BciChannelQuality> channels)`.
- Both services import and call it; delete the local `_mapLevel` copies and the inline list-maps.

## Guards
- It MUST live in `lib/BciModule/` (the delivery layer that already imports both the domain model and the package DTOs) — NOT in `packages/bci_module/`, because the package cannot import the domain `BciSignalLevel` enum.

## Files
- new `lib/BciModule/BciChannelQualityMapping.dart`
- `lib/BciModule/BciPairingService.dart`
- `lib/BciModule/BciDataService.dart`
