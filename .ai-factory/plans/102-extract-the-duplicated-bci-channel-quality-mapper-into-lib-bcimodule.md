# Plan: Extract the duplicated BCI channel-quality mapper into `lib/BciModule/`

## Context
The `_mapLevel(BciSignalLevel)→BciSignalQuality` helper and the `BciChannelQuality→BciChannelQualityDTO` inline list-map are duplicated verbatim in `BciPairingService.dart` and `BciDataService.dart`. This milestone extracts them into a single shared file in `lib/BciModule/`, removing the duplication without any behavior change.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Extract shared mapper

- [x] **Task 1: Create the shared mapping file**
  Files: `lib/BciModule/BciChannelQualityMapping.dart`
  Create a new file with two top-level functions (no class). It must live in `lib/BciModule/` — NOT in `packages/bci_module/` — because it imports the domain enum `BciSignalLevel`, which the package cannot reference.
  - Imports: `package:bci_module/bci_module.dart` (for `BciSignalQuality`, `BciChannelQualityDTO`) and `package:mind/Bci/Models/BciChannelQuality.dart` (for `BciSignalLevel`, `BciChannelQuality`).
  - `BciSignalQuality mapBciSignalLevel(BciSignalLevel level)` — switch mapping copied verbatim from the existing `_mapLevel`: `green → BciSignalQuality.good`, `yellow → BciSignalQuality.fair`, `red → BciSignalQuality.poor`.
  - `List<BciChannelQualityDTO> mapBciChannelQualities(List<BciChannelQuality> channels)` — maps each channel to `BciChannelQualityDTO(channelName: c.channelName, quality: mapBciSignalLevel(c.level))` and returns `.toList(growable: false)`, matching the existing inline list-maps exactly.

- [x] **Task 2: Use the shared mapper in `BciPairingService`** (depends on Task 1)
  Files: `lib/BciModule/BciPairingService.dart`
  - Add `import 'package:mind/BciModule/BciChannelQualityMapping.dart';`.
  - In the `BciSignalQualityUpdated` case of `_reduce`, replace the inline `channels.map(...).toList(growable: false)` with `mapBciChannelQualities(channels)`.
  - Delete the local `BciSignalQuality _mapLevel(BciSignalLevel level)` method and the `// ── Helpers ──` section header if it becomes empty.

- [x] **Task 3: Use the shared mapper in `BciDataService`** (depends on Task 1)
  Files: `lib/BciModule/BciDataService.dart`
  - Add `import 'package:mind/BciModule/BciChannelQualityMapping.dart';`.
  - In the `BciSignalQualityUpdated` case of `_reduce`, replace the inline `channels.map(...).toList(growable: false)` with `mapBciChannelQualities(channels)`.
  - Delete the local `BciSignalQuality _mapLevel(BciSignalLevel level)` method and the `// ── Helpers ──` section header if it becomes empty.

- [x] **Task 4: Verify analyzer is clean** (depends on Tasks 2, 3)
  Files: (none)
  Run `/usr/local/bin/flutter analyze lib/BciModule/` and confirm no new warnings/errors — in particular no unused imports (e.g. `BciChannelQuality.dart` may still be needed in the services for other references; verify before removing). Fix any unused-import lint introduced by the change.
