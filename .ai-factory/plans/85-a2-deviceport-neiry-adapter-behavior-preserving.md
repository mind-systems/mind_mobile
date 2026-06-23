# Plan: A2 · DevicePort + neiry adapter (behavior-preserving)

## Context
The narrow `DevicePort` seam and its `NeiryDeviceAdapter` already landed as production code in the A1 commit (`54b320c`) — `DevicePort`, `NeiryDeviceAdapter`, and `LocatorPort.createDevice` returning a `DevicePort` exist and are wired into `NeiryBciProvider` (the A1/A2 pair is co-dependent and shipped together). The **only remaining half of A2's Done-when** is the test side: a *controllable* fake `DevicePort` that is injectable via the fake locator and a characterization-lite test that drives the device lifecycle and the three streams. The A1 test currently injects only a no-op `_StubDevicePort` (`test/Bci/neiry_bci_provider_locator_port_test.dart:17`), which does not satisfy spec note 158's Verify clause.

Production must stay byte-identical (behavior-preserving guard). **Hard constraint to design around:** `NeiryBciProvider.connect()` casts `(_device as NeiryDeviceAdapter).rawDevice` (`lib/Bci/NeiryBciProvider.dart:171`) to build the four classifiers, so a fake `DevicePort` throws a `CastError` mid-`connect()` and routes into the catch/cleanup path. A full `connect()` happy-path with a fake is only unblocked by A3 (ClassifierFactory port) and full characterization is B1/B2's job — this task asserts only the reachable seam plus the port contract.

## Settings
- Testing: yes (the test + injectable fake IS the deliverable)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Test double

- [x] **Task 1: Add a controllable `FakeDevicePort` test double**
  Files: `test/Bci/neiry_bci_provider_device_port_test.dart` (new)
  Implement `class FakeDevicePort implements DevicePort` mirroring the seam style of the existing `FakeLocatorPort` (`test/Bci/neiry_bci_provider_locator_port_test.dart:50`). It must, per spec note `.ai-factory/notes/158-bci-device-port.md`:
  - Back the three streams with `StreamController`s: `connectionStateStream` (`StreamController<BciLinkStatus>`), `resistanceStream` (`StreamController<List<BciChannelQuality>>`), `batteryStream` (`StreamController<int>`) — with `emitConnection(...)`, `emitResistance(...)`, `emitBattery(...)` helpers. Use broadcast controllers (the provider subscribes once; broadcast keeps the test robust).
  - Expose test-controlled async on `stopStream()`, `disconnect()`, `dispose()` (e.g. gate each on a `Completer` the test can complete, or return immediately by default) so teardown ordering can be driven later.
  - Track call counts / order for `connect`, `start`, `stopStream`, `disconnect`, `dispose`.
  - Expose a settable `isStarted` (default `false`; flips to `true` after `start()`).
  - Never import `neiry_kit` — it implements only the 3-method-plus-streams port surface (`lib/Bci/Ports/DevicePort.dart`).

### Phase 2: Tests

- [x] **Task 2: Test that the provider routes device lifecycle through the injected `DevicePort`** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_device_port_test.dart`
  Inject via `NeiryBciProvider(locatorFactory: () => fakeLocator)` where the fake locator's `createDevice` returns the `FakeDevicePort` (extend/reuse the `FakeLocatorPort` pattern; have it hand back the controllable fake instead of a stub). Assert the reachable seam of `connect(serial)`:
  - `createDevice` is invoked exactly once and the provider holds the fake (`createDeviceCallCount == 1`, fake's `connect()` called).
  - Because `connect()` hits the `(_device as NeiryDeviceAdapter)` cast at `lib/Bci/NeiryBciProvider.dart:171` with a fake, the call throws — wrap in `expect(() => provider.connect('X'), throwsA(...))` and assert the cleanup path ran (`disconnect()` + `dispose()` called on the fake per the catch block `lib/Bci/NeiryBciProvider.dart:194-198`).
  - Add an inline comment documenting that the full `connect()` happy path is A3-gated (classifier construction still needs the raw device) so the assertion is intentionally scoped to the seam, not full characterization.

- [x] **Task 3: Drive the three streams + lifecycle methods through the fake to lock the port contract** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_device_port_test.dart`
  Add focused tests proving the controllable fake fully exercises the `DevicePort` surface the provider depends on (so it is ready for B1/B2 characterization):
  - `emitConnection(BciLinkStatus.up/.down)`, `emitResistance([...])`, `emitBattery(n)` flow through the fake's stream controllers to listeners.
  - `isStarted` reflects `start()` / `stopStream()`.
  - `stopStream()`, `disconnect()`, `dispose()` are awaitable and call-counted, and their test-controlled async completes deterministically.
  - Keep the existing `default constructor uses real adapter` smoke check spirit: add one assertion that `NeiryBciProvider()` (no `locatorFactory`) still constructs `returnsNormally`, confirming the default real adapter path is untouched.
  Run `/usr/local/bin/flutter test test/Bci/` and confirm both the new file and the existing A1 file pass.
