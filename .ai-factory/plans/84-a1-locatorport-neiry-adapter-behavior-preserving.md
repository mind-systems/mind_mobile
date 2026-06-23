# Plan: A1 · LocatorPort + neiry adapter (behavior-preserving)

## Context
Introduce a narrow `LocatorPort` (the surface `NeiryBciProvider` actually calls on `neiry.DeviceLocator` — `requestDevices`, `createDevice`, `dispose`) plus a thin `NeiryLocatorAdapter`, so the locator can be driven from a fake in tests while production stays byte-identical. First seam of the Phase 55 characterization-first refactor.

## Settings
- Testing: yes (minimal smoke test — milestone Done-when requires an injectable fake `LocatorPort`)
- Logging: minimal
- Docs: no

## Co-dependency with A2 (read before implementing)
Per `.ai-factory/notes/155-bci-locator-port.md` and the roadmap, **A1 and A2 are a co-dependent pair that land in the same change.** `LocatorPort.createDevice(serial)` returns a `DevicePort` (the device seam owned by A2, `.ai-factory/notes/158-bci-device-port.md`). Consequences for this plan:

- A1 **declares** the `DevicePort` interface (the abstract contract) so `LocatorPort` is typeable. A2 provides the concrete `NeiryDeviceAdapter`, the device fake, and migrates the provider's `_device` field to `DevicePort`.
- The provider will only fully compile once A2's `_device` migration lands. Implement A1 → A2 back-to-back and commit them together. Do **not** expect a green build from A1 in isolation; verification below is at the joint A1+A2 level.
- Classifier construction (`neiry.NfbClassifier(_device!)`, etc.) still consumes a raw `neiry.Device` and is **out of scope** for A1 (it belongs to A3). Do not touch it here.

## Hard guards (behavior-preserving)
- Default = current construction. `NeiryBciProvider()` with no arguments must build a real `NeiryLocatorAdapter` and behave exactly as today (`lib/Core/App.dart:193` stays unchanged).
- Do **not** touch the teardown gate (`_teardownComplete` field `:38`; drains at `:106` / `:151` / `:617`), the `try/finally` recreate (`:561-562`), or teardown ordering.
- The fake implements the **3-method port only**, never the whole `neiry.DeviceLocator` (reject the implicit-interface spaghetti-fake).
- Single-resource scope (this provider's BCI locator). Do NOT fold in domain latches or the `ModuleStateEvent` bus.

## Tasks

### Phase 1: Define the port contracts

- [x] **Task 1: Declare the `DevicePort` interface (seam type for `createDevice`)**
  Files: `lib/Bci/Ports/DevicePort.dart`
  Declare `abstract interface class DevicePort` with the surface from note 158: `Future<void> connect()`, `Future<void> start()`, `Future<void> stopStream()`, `Future<void> disconnect()`, `Future<void> dispose()`, `bool get isStarted`, and `Stream<...> connectionStateStream / resistanceStream / batteryStream`. **Declaration only** — no neiry imports, no implementation. A2 implements `NeiryDeviceAdapter` and the device fake against this contract. Keep stream element types domain/port-level where a wrapper already exists; otherwise leave a clear `// A2:` marker so A2 finalizes element types when it wires `NeiryDeviceAdapter`. This file exists so `LocatorPort.createDevice` is typeable.

- [x] **Task 2: Add port-level scan device-type enum**
  Files: `lib/Bci/Ports/LocatorPort.dart`
  Define a tiny port-level enum `BciScanDeviceType { headband }` (extend only if a second value is genuinely used) so `LocatorPort.requestDevices` carries the `type` parameter without leaking `neiry.NeiryDeviceType` across the seam. Co-locate it in the `LocatorPort.dart` file.

- [x] **Task 3: Declare the `LocatorPort` interface** (depends on Task 1, Task 2)
  Files: `lib/Bci/Ports/LocatorPort.dart`
  Declare `abstract interface class LocatorPort` with exactly the called surface:
  - `Stream<List<BciDeviceInfo>> requestDevices({BciScanDeviceType type = BciScanDeviceType.headband, int searchTime = 5})` — returns the **already-mapped** domain `BciDeviceInfo` list (the `.map` currently inline at `NeiryBciProvider.dart:143-144` moves into the adapter, so the port never exposes `neiry.DeviceInfo`).
  - `Future<DevicePort> createDevice(String serial)`.
  - `Future<void> dispose()`.
  No neiry imports in this file. Import `Models/BciDeviceInfo.dart` and `DevicePort.dart`.

### Phase 2: Real adapter + provider wiring

- [x] **Task 4: Implement `NeiryLocatorAdapter`** (depends on Task 3)
  Files: `lib/Bci/Ports/NeiryLocatorAdapter.dart`
  `class NeiryLocatorAdapter implements LocatorPort`, wrapping a `neiry.DeviceLocator` constructed identically to today (`neiry.DeviceLocator()`). Implement:
  - `requestDevices(...)` → calls `_locator.requestDevices(type: <map BciScanDeviceType→neiry.NeiryDeviceType>, searchTime: searchTime)` and applies the existing `.map((list) => list.map((d) => BciDeviceInfo(serial: d.serial, name: d.name)).toList())` (relocated from the provider, byte-identical mapping).
  - `createDevice(serial)` → `await _locator.createDevice(serial)` then wrap the returned `neiry.Device` in A2's `NeiryDeviceAdapter` and return it as `DevicePort`. (`NeiryDeviceAdapter` is delivered by A2 — this line co-lands with A2.)
  - `dispose()` → `_locator.dispose()`.
  This is the **only** new file permitted to import `neiry_kit`, consistent with the existing rule on `NeiryBciProvider`.

- [x] **Task 5: Wire `LocatorPort` into `NeiryBciProvider` via injected factory** (depends on Task 4)
  Files: `lib/Bci/NeiryBciProvider.dart`
  - Replace the field `neiry.DeviceLocator _locator = neiry.DeviceLocator();` (`:35`) with `late LocatorPort _locator;` plus a stored `final LocatorPort Function() _locatorFactory;`.
  - Add a constructor: `NeiryBciProvider({LocatorPort Function()? locatorFactory}) : _locatorFactory = locatorFactory ?? (() => NeiryLocatorAdapter()) { _locator = _locatorFactory(); }`. A factory (not a single instance) is required because the locator is **recreated** on reset — see next bullet. Default keeps `NeiryBciProvider()` byte-identical, so `lib/Core/App.dart:193` needs no change.
  - In `_resetLocatorSession()` replace the recreate `_locator = neiry.DeviceLocator();` (`:468`) with `_locator = _locatorFactory();`. Keep the surrounding `_disposed` guards and `_locator.dispose()` (`:463`) call exactly as-is (now routed through the port).
  - In `_doDispose()` keep `await _locator.dispose();` (`:675`) — now a port call.
  - In `scan()` replace the inline `.map(...)` (`:141-144`) with `yield* _locator.requestDevices(type: BciScanDeviceType.headband, searchTime: 5);` (mapping now lives in the adapter). Leave the permission/teardown-drain logic above it untouched.
  - **Do not** migrate the `_device` field here (A2). Leave classifier construction and all device-method call sites unchanged. Expect the file to compile only after A2 lands.

### Phase 3: Fake + smoke test

- [x] **Task 6: Fake `LocatorPort` + injectable-seam smoke test** (depends on Task 5)
  Files: `test/Bci/neiry_bci_provider_locator_port_test.dart`
  Add a `FakeLocatorPort implements LocatorPort` (3 methods only) with test-controlled async (e.g. a completer-gated `dispose()`/`createDevice()` and a controllable `requestDevices` stream) — it must **not** implement `neiry.DeviceLocator`. Add a minimal smoke test that constructs `NeiryBciProvider(locatorFactory: () => fake)`, drives `scan()`, and asserts the emitted `List<BciDeviceInfo>` comes from the fake (proving the real SDK locator is not used and the factory seam is injectable). For `createDevice`, the fake may return a trivial stub `DevicePort`; full device-driven characterization is B1's job, not this task.

## Commit Plan
- **Commit 1** (tasks 1-6, landed jointly with milestone A2): "Introduce LocatorPort seam and neiry locator adapter" — A1 and A2 are committed together so the working tree compiles (A2 supplies `NeiryDeviceAdapter` and the `_device` migration that `LocatorPort.createDevice` depends on).

## Verify (joint A1+A2)
- `NeiryBciProvider()` default path constructs a real `NeiryLocatorAdapter`; production behavior byte-identical (no change at `lib/Core/App.dart:193`).
- A fake `LocatorPort` is injectable via the constructor factory; the smoke test confirms `scan()` is served by the fake, not a real SDK locator.
