# Plan: Remove the `rawDevice` downcast that defeats DevicePort (T5)

## Context
`NeiryClassifierFactory.build(DevicePort)` downcasts to `NeiryDeviceAdapter` and reads the public `rawDevice` getter, so any non-Neiry `DevicePort` (fake or second vendor) hits a `CastError`. This milestone removes the downcast and the `rawDevice` getter by changing the classifier-construction port shape, keeping `neiry_kit` quarantined and the existing test suites green.

## Settings
- Testing: yes (migrate existing Bci test fakes to the new port shape — mandatory per done-when; no new feature coverage)
- Logging: minimal
- Docs: no (update affected inline doc-comments only)

## Decision — Port Shape (Option 2 from spec note `169`)

The note offers two options and flags the choice as mine. **Chosen: Option 2** — *the adapter constructs its own classifier set*. Concretely:

- `DevicePort` gains `ClassifierSet buildClassifierSet()`.
- `NeiryDeviceAdapter.buildClassifierSet()` constructs `NeiryClassifierSet` from its **private** `_device` handle — no public vendor accessor.
- `NeiryClassifierFactory` and the `ClassifierFactory` port are **deleted** (their only job was extracting the handle via the downcast).
- `NeiryBciProvider.connect()` calls `_device!.buildClassifierSet()` directly; the `classifierFactory` constructor seam is removed (tests now control the set through their `DevicePort` fake).

**Why Option 2 over Option 1 (factory takes `neiry.Device`):** Option 1 requires the neiry handle to reach the factory, which only `NeiryLocatorAdapter.createDevice` holds — forcing `LocatorPort.createDevice`'s return shape to change and rippling into all 6 locator fakes *plus* every `classifierFactory:` injection. Option 2 leaves `LocatorPort` untouched, removes a redundant port, and keeps `neiry_kit` confined to the already-permitted adapter files. Both options delete `rawDevice`; Option 2 has the smaller, cleaner blast radius and genuinely changes the port shape as the note intends.

**Quarantine note:** after this change `neiry_kit` is imported only by `NeiryBciProvider`, `NeiryLocatorAdapter`, `NeiryDeviceAdapter`, and `NeiryClassifierSet`. `NeiryDeviceAdapter` already imports `neiry_kit`; it additionally imports `NeiryClassifierSet.dart` (also a permitted neiry file). The quarantine set shrinks by one file.

## Tasks

### Phase 1: Production port-shape change

- [x] **Task 1: Add `buildClassifierSet()` to the `DevicePort` port**
  Files: `lib/Bci/Ports/DevicePort.dart`
  Add `ClassifierSet buildClassifierSet();` to the interface and `import 'ClassifierSet.dart';`. `ClassifierSet` is neiry-free (domain-typed streams only), so the port stays vendor-clean. Add a doc-comment: "Builds the classifier set bound to this device; the device must be connected first."

- [x] **Task 2: Implement `buildClassifierSet()` in `NeiryDeviceAdapter`; remove `rawDevice`** (depends on Task 1)
  Files: `lib/Bci/Ports/NeiryDeviceAdapter.dart`
  Add `@override ClassifierSet buildClassifierSet() => NeiryClassifierSet(_device);` using the existing private `_device`. Add `import 'ClassifierSet.dart';` and `import 'NeiryClassifierSet.dart';`. Delete the `rawDevice` getter (`:29`) and its doc-comment referencing `NeiryClassifierFactory`. Update the class doc-comment to mention it now also builds the classifier set.

- [x] **Task 3: Route `connect()` through the device; drop the factory seam** (depends on Task 2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  At the build site (`:183`) replace `_classifierSet = _classifierFactory.build(_device!);` with `_classifierSet = _device!.buildClassifierSet();`. Remove the `_classifierFactory` field (`:44`), the `classifierFactory` constructor parameter and its initializer (`:52`, `:54`), and the imports of `Ports/ClassifierFactory.dart` (`:27`) and `Ports/NeiryClassifierFactory.dart` (`:31`). Keep the `DevicePort`/`ClassifierSet` imports. Update the class doc-comment list of quarantined files (`:38`) to drop `NeiryClassifierFactory`.

- [x] **Task 4: Delete the obsolete classifier-factory files and fix dangling doc references** (depends on Task 3)
  Files: `lib/Bci/Ports/ClassifierFactory.dart`, `lib/Bci/Ports/NeiryClassifierFactory.dart`, `lib/Bci/Ports/NeiryClassifierSet.dart`, `lib/Bci/Ports/ClassifierSet.dart`
  - Delete `ClassifierFactory.dart` and `NeiryClassifierFactory.dart`.
  - Remove the surviving dartdoc references to the deleted `NeiryClassifierFactory` symbol — these would otherwise leave dangling references **and** keep Task 8's `grep ClassifierFactory` non-empty (it matches the `NeiryClassifierFactory` substring):
    - `lib/Bci/Ports/NeiryClassifierSet.dart:21` — currently *"This is one of two files (with [NeiryClassifierFactory]) permitted to import `neiry_kit`."* Update to reflect that `NeiryClassifierSet` is now constructed by `NeiryDeviceAdapter` and is no longer paired with a separate factory file.
    - `lib/Bci/Ports/ClassifierSet.dart:9` — currently *"Production default: [NeiryClassifierFactory] (A3)."* Drop this line; construction now goes through `DevicePort.buildClassifierSet()` → `NeiryClassifierSet`.
  - Confirm no remaining references with a grep for `ClassifierFactory` / `NeiryClassifierFactory` across `lib/`.

### Phase 2: Test migration

**Shared migration pattern (applies to every device fake in Tasks 5–7):**
- Each `DevicePort` fake gains `@override ClassifierSet buildClassifierSet()`. Add `import 'package:mind/Bci/Ports/ClassifierSet.dart';` to any file that does not already import it.
- The fake **owns its own** `FakeClassifierSet` (constructed in the fake's field/constructor) and returns it from `buildClassifierSet()`. No set is shared across reconnect-vended devices — no existing test asserts shared-set identity across reconnects, so per-device ownership is the simpler, correct choice.
- Add an `int buildClassifierSetCallCount` counter (increment in the method) where a test needs the "built once per connect()" assertion.
- Add a `bool throwOnBuildClassifierSet` flag; when set, `buildClassifierSet()` throws (use `StateError`) to drive the connect-failure cleanup path that previously relied on the cast `TypeError`. The throw lands at the same point (after `device.connect()`, before `device.start()`), so cleanup `disconnect()`/`dispose()` counts stay 1.

- [x] **Task 5: Migrate the A3 classifier-port test** (depends on Task 4)
  Files: `test/Bci/neiry_bci_provider_classifier_port_test.dart`
  - Give `FakeDevicePort` a `FakeClassifierSet` field (this file already defines `FakeClassifierSet`), a `buildClassifierSetCallCount`, the `throwOnBuildClassifierSet` flag, and `buildClassifierSet()`. Constructor-inject or assign the shared `fakeSet` so the existing stream/dispose assertions can target it.
  - Delete `FakeClassifierFactory` and the `classifierFactory:` injection; remove the now-unused `ClassifierFactory` import. Wire `fakeSet` into `FakeDevicePort` instead.
  - Happy-path test: replace `fakeFactory.buildCallCount == 1` with `fakeDevice.buildClassifierSetCallCount == 1`; keep the "streams surface" and "dispose once" assertions retargeted onto the device-built set.
  - Rewrite the A2 regression group (`:351`–`:374`, currently asserts `TypeError` from the cast): assert the **positive** of T5 — a non-Neiry `FakeDevicePort` now completes `connect()` without a `CastError`. Keep the default-constructor smoke test (`:341`–`:349`): `NeiryBciProvider()` must still construct.
  - **Done sub-check:** this test file is green (the milestone's named done-when).

- [x] **Task 6: Migrate the passive DevicePort fakes** (depends on Task 4)
  Files: `test/Bci/neiry_bci_provider_locator_port_test.dart`, `test/Bci/neiry_bci_provider_device_port_test.dart`
  - **Neither file currently defines a `FakeClassifierSet` or imports `ClassifierSet.dart`.** Add a minimal `FakeClassifierSet` (the seven domain-typed `Stream` getters returning broadcast controllers + a `dispose()`) — or reuse the shape from the classifier-port test — and the `ClassifierSet.dart` import. Then add `buildClassifierSet()` to `_StubDevicePort` (locator_port) and `FakeDevicePort` (device_port).
  - `locator_port_test.dart`: `buildClassifierSet()` is never hit at runtime (tests exercise `scan()` only); the method only needs to compile, so return a fresh minimal `FakeClassifierSet`.
  - `device_port_test.dart`: the connect-cleanup test (`:138`–`:170`) relied on the downcast `TypeError` to enter the catch block. Set `throwOnBuildClassifierSet = true` on the fake so `connect()` fails after `device.connect()`; change the `expectLater(...)` matcher to the thrown type (`StateError`). All cleanup count assertions stay. Update the stale comment about `rawDevice`/A3-gating.

- [x] **Task 7: Migrate the gated/recording fakes and factory injections** (depends on Task 4)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`, `test/Bci/neiry_bci_provider_full_teardown_test.dart`, `test/Bci/neiry_bci_provider_command_queue_test.dart`
  - Add `buildClassifierSet()` to each gated device fake (`GatedFakeDevicePort`, `_GatedFakeDevicePort`). Each device fake **owns its own** `FakeClassifierSet` / `_FakeClassifierSet` instance (constructed in the fake, returned from `buildClassifierSet()`); the vending locators (`RecordingLocatorPort`, `_ThrowingDeviceLocatorPort`, `_RecordingLocatorPort`) keep constructing fresh device fakes — no per-call set injection needed.
  - Delete every `FakeClassifierFactory` / `_FakeClassifierFactory` class and each `classifierFactory: ...(fakeSet)` constructor injection.
  - Re-source the dispose-order/identity assertions from the device-owned set instead of the previously injected `fakeSet`. In particular, `_connectThenDrop` / `_DropSetup.classifierSet` (races test `:331`/`:368`, currently sourced from the injected `fakeSet`) must be re-sourced from the vended device fake's set.
  - Rework the "Phase 4 — partial L1" test (`:766`–`:812`) and `_ThrowingDeviceLocatorPort` (`:824`–`:833`): the failure was previously triggered by the default factory's cast `TypeError`. Trigger it now via a device fake whose `buildClassifierSet()` throws (set `throwOnBuildClassifierSet = true`, keep `throwOnDispose = true` to exercise the swallowed-dispose cleanup). Update the `throwsA(isA<TypeError>())` matcher to `StateError` and fix the explanatory comment.
  - Verify ordering/dispose-count assertions still hold against the device-built set.

### Phase 3: Verify

- [x] **Task 8: Verify no downcast remains and suites pass** (depends on Tasks 5–7)
  Files: (verification only)
  - Grep `lib/` and `test/` for `as NeiryDeviceAdapter`, `rawDevice`, `ClassifierFactory` — expect zero matches (outside historical `.ai-factory/reviews/` docs).
  - Run `flutter test test/Bci/` (Flutter at `/usr/local/bin/flutter`). All Bci suites — including the classifier-port test (A3) and B1/B2 characterization tests — must be green.

## Commit Plan
- **Commit 1** (after tasks 1–4): "Replace classifier factory downcast with DevicePort.buildClassifierSet"
- **Commit 2** (after tasks 5–8): "Migrate Bci test fakes to the buildClassifierSet port shape"
