# Code Review — Remove the `rawDevice` downcast that defeats DevicePort (T5)

**Scope:** `git diff HEAD` — 6 production files (2 deleted), 5 test files.
**Verification:** `flutter test test/Bci/` → **70/70 pass**; `flutter analyze lib/Bci test/Bci` → **no issues**.

## Summary

The change implements the plan's chosen Option 2 faithfully: `DevicePort` gains `ClassifierSet buildClassifierSet()`, `NeiryDeviceAdapter` builds `NeiryClassifierSet` from its private `_device` handle, the `rawDevice` getter and both `ClassifierFactory`/`NeiryClassifierFactory` files are gone, and `NeiryBciProvider.connect()` now calls `_device!.buildClassifierSet()` directly. The downcast that caused `CastError` for any non-Neiry `DevicePort` is eliminated.

## Correctness checks performed

- **Downcast removed, semantics preserved.** `connect()` (`NeiryBciProvider.dart:175-184`) calls `buildClassifierSet()` at the same point the old `_classifierFactory.build(_device!)` ran — after `device.connect()`, before `device.start()`. The surrounding catch block (`:185-197`) is unchanged, so a throwing `buildClassifierSet()` lands in the same cleanup path (`_classifierSet?.dispose()` is null-safe, device disconnect/dispose run, locator resets, error rethrows). Verified by the migrated failure-path tests.
- **No remaining references.** Grep across all `*.dart` for `rawDevice`, `ClassifierFactory`, `classifierFactory`, `FakeClassifierFactory`, `buildCallCount` → **zero matches**. The two deleted files have no surviving importers.
- **Dangling doc-comments fixed** (the plan-review-1 critical issue): `NeiryClassifierSet.dart:21` and `ClassifierSet.dart:9` no longer reference the deleted `NeiryClassifierFactory`, so the plan's grep gate stays clean and no dartdoc points at a deleted symbol.
- **No import cycle / quarantine intact.** `DevicePort` now imports `ClassifierSet`, which imports only domain/Biometrics models (no back-edge to `DevicePort`) — confirmed neiry-free. `neiry_kit` is imported by exactly `NeiryBciProvider`, `NeiryLocatorAdapter`, `NeiryDeviceAdapter`, `NeiryClassifierSet` (4 files, down from 5).
- **Test seam relocation is sound.** The shared-set-identity cases that mattered (classifier_port stream/dispose assertions; full_teardown disposal ordering) correctly pass the same set instance into the device fake (`FakeDevicePort(fakeSet)`) or re-source it from the vended device (`device.classifierSet`). Per-device-owned sets are used only where no cross-reconnect identity is asserted — matches the plan's stated choice.
- **TypeError→StateError migrations** in `device_port_test`, `locator_device_races_test` (Phase 4 / `_ThrowingDeviceLocatorPort`), and the classifier_port A2→T5-positive rewrite all assert the new failure source and keep the cleanup count assertions (disconnect/dispose == 1). The races test correctly sets both `throwOnBuildClassifierSet` and `throwOnDispose` so the dispose-swallow + locator-reset behavior is still exercised.

## Findings

None. The implementation matches the plan, removes the downcast and `rawDevice`, keeps `neiry_kit` quarantined, and the full Bci suite plus analyzer are green.

REVIEW_PASS
