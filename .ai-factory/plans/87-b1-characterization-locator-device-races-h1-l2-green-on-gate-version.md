# Plan: B1 · Characterization: locator/device races H1 + L2 (green on gate version)

## Context
Pin the H1 (auto-reconnect hang) and L2 (orphan locator leak) properties of `NeiryBciProvider`'s locator/device lifecycle as an executable, behavioral characterization suite that is **green on the current gate version**, driven entirely through the A1/A2 `LocatorPort`/`DevicePort` seams. The suite becomes the contract that the C1 actor refactor (`[[157-bci-actor-serial-command-queue]]`) must preserve with no assertion edits.

## Settings
- Testing: yes (the deliverable IS a test suite; no production code unless a red probe forces a gate fix)
- Logging: minimal
- Docs: no

## Background (already in place — do not re-create)
- `NeiryBciProvider` (`lib/Bci/NeiryBciProvider.dart`) is fully port-injectable:
  - `LocatorPort Function() _locatorFactory` constructor arg (`:42`, `:52`) — `_locator` field is mutable (`:41`) and re-read at every call site; constructor calls `_locatorFactory()` once at `:54` to create the initial locator (`L0`).
  - `ClassifierFactory _classifierFactory` constructor arg (`:43`, `:53`).
  - `DevicePort? _device` obtained via `_locator.createDevice(serial)` (`:167`).
- Gate mechanism to characterize (assert its **observable effects**, never its field names):
  - `scan()` async\* gates on `try { await _teardownComplete; } catch (_) {}` (`:118`) before `yield* _locator.requestDevices(...)` (`:153`) — `_locator` read at yield time.
  - `connect()` also gates on `await _teardownComplete` (`:160`) before reading `_device`.
  - Unexpected drop: `_onConnectionStatus(BciLinkStatus.down)` (`:254-262`) calls `_teardownAfterUnexpectedDrop()` (`:375`) only when `_device != null` (idempotency guard `:257`); the heavy teardown runs in `_teardownComplete = Future.microtask(...)` (`:404`) ending in `finally { _resetLocatorSession() }` (`:438`).
  - `_resetLocatorSession()` (`:357`): `await _locator.dispose()` (`:360`, wrapped — double-dispose throws `StateError`) then `_locator = _locatorFactory()` (`:365`); no-op once `_disposed`.
  - `disconnect()` (`:474`) gates on `await _teardownComplete` (`:475`) then **unconditionally** calls `_resetLocatorSession()` (`:502`) — i.e. `disconnect()` always resets the session, even after a drop already reset it.
  - `connect()` failure cleanup calls `_device?.disconnect()` + `_device?.dispose()` (`:178-179`) then `_resetLocatorSession()` (`:182`). Note: it does **not** call `stopStream()`.
  - Device streams (incl. `connectionStateStream`) are subscribed in `_subscribeDeviceStreams()` (`:189`) which runs only **after** a fully successful `connect()` (`:185`); the failure path never subscribes.
- Existing fakes to mine for patterns (do NOT modify those files): `FakeLocatorPort`/`_ControlledLocatorPort`, `FakeDevicePort` (with controllable `Completer`s on `stopStream`/`disconnect`/`dispose`), `FakeClassifierFactory`/`FakeClassifierSet` in `test/Bci/neiry_bci_provider_{locator,device,classifier}_port_test.dart`.
- Reconnect trigger context (H1's real-world entry): `BciDeviceManager._attemptReconnect()` (`lib/Bci/BciDeviceManager.dart:274`) → `_provider.scan()` (`:277`), fired from the connection-state listener (`:68-74`) only when a `BciActive` device drops.

## Decision rule (applies to every probe)
The phase is promoted, so a **red** probe is NOT a promote-vs-gate signal — it is a **real bug in the gate version**. Fix it in the gate code **inside this task**, then the probe must go green. The gate version is expected to be correct, so probes should be green after (at most) small fixes.

**Churn-is-not-a-leak caveat (critical — prevents a spurious gate change):** a redundant-but-properly-paired `dispose()`+create is **expected behavior**, not a leak. `disconnect()` legitimately resets the locator session every call (`:502`), so a drop→disconnect cycle performs **two** paired resets — that is correct. A probe is only red-for-a-real-bug when it observes **`creates − disposes > 1`** (two live locators at once) or a **replace-without-dispose** (a locator overwritten while still live). Never "fix" the gate to collapse a redundant paired reset.

## Tasks

### Phase 1: Characterization harness

- [x] **Task 1: Build the locator/device-race fake harness**
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart` (new)
  Create one self-contained characterization test file. Add the controllable fakes B1 needs (model them on the existing port-test fakes, but enriched for interleaving control):
  - `RecordingLocatorRegistry` + a `locatorFactory` closure that **vends a fresh `RecordingLocatorPort` on every call** and records creation order in a list. This is the core L2/H1 instrument: it lets the suite count total creates/disposes across a cycle (`createdCount`, `sum of disposeCount`) and identify *which* locator instance `requestDevices()` ran on. Expose registry-level helpers: `liveCount` (`created − disposed`) and an `assertNoOrphan()` that checks no locator was overwritten while still live.
  - `RecordingLocatorPort implements LocatorPort`: per-instance `requestDevicesCallCount`, `createDeviceCallCount`, `disposeCallCount`; `dispose()` increments and throws `StateError` on a second call (mirrors the real adapter's double-dispose contract so `_resetLocatorSession`'s try/catch is exercised); a **gated `dispose()`** via a replaceable `Completer` so teardown can be held in-flight; `requestDevices()` returns a controllable stream; `createDevice()` **vends a fresh `GatedFakeDevicePort` per call** (matching fresh-locator→fresh-device; a single shared device whose `dispose()` closes its broadcast controllers would break Task 4's reconnect — plan-review #3) and is itself gateable via a `Completer` (for the connect-racing-drop probe).
  - `GatedFakeDevicePort implements DevicePort`: replaceable `Completer`s on `stopStream`/`disconnect`/`dispose` (default pre-completed), call counters, **`throwOnDisconnect`/`throwOnDispose` flags (the `Completer`s gate *timing* only — these flags make the call *throw*, required by Task 6's swallow check)**, and an `emitConnection(BciLinkStatus)` helper to fire the unexpected drop on `connectionStateStream` (broadcast).
  - Reuse a minimal `FakeClassifierFactory`/`FakeClassifierSet` (copy the shape from `neiry_bci_provider_classifier_port_test.dart`) purely as a `connect()`-enabler so `_device` becomes non-null and a subsequent drop reaches `_teardownAfterUnexpectedDrop()`.
  - A `connectThenDrop` test helper that: constructs the provider with the recording factory + fake classifier factory, drives `connect(serial)` to success (so `_subscribeDeviceStreams()` at `:189` runs and the drop handler is live), then emits `BciLinkStatus.down` to start an unexpected-drop teardown — with the device teardown `Completer`s left open so the test controls when teardown finishes.
  - Add a sanity smoke test: a clean `connect()` → success leaves exactly one live locator (`liveCount == 1`) and zero orphans.

### Phase 2: L2 — orphan locator leak

- [x] **Task 2: L2 orphan-invariant probes (pure drop, and drop racing concurrent disconnect)** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`
  Characterize that locator resets never leak a locator. Split the count assertions by scenario so the suite never goes red on a *correct* redundant reset:
  - **Pure drop (no `disconnect()`)** — the tight-count case. Ctor creates `L0`; after the drop teardown completes, assert `L0.disposeCount == 1`, exactly **one** fresh locator created by `_resetLocatorSession` (`:360`/`:365`), `liveCount == 1`, zero orphans.
  - **Drop racing concurrent `disconnect()`** (both orderings: (a) drop first, `disconnect()` called while teardown in-flight; (b) `disconnect()` first, drop arriving during it). Here `disconnect()`'s unconditional reset (`:502`) legitimately performs a **second** paired dispose+create, so do **NOT** assert a tight one-dispose/one-create count. Assert **only** the behavioral orphan invariants (these survive `_teardownComplete` removal *and* the redundant reset):
    - At every observed point `liveCount = creates − disposes ≤ 1` (never two live locators at once).
    - Every locator that gets replaced was disposed **before** being overwritten (no locator abandoned without a `dispose()`).
    - The dropped locator (`L0`) is disposed exactly once; the final still-live locator is never disposed until `provider.dispose()`.
  If a probe shows `liveCount > 1` or a replace-without-dispose, apply the decision rule — that is a real gate bug; fix it, then green. A merely-redundant paired reset is **not** a bug (see churn caveat).

### Phase 3: H1 — auto-reconnect hang

- [x] **Task 3: H1 wait-and-fresh-locator probes (provider-level)** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`
  Characterize that `scan()` started while a teardown is in flight **waits** (gate at `:118`) and never calls `requestDevices()` (`:153`) on the locator being torn down — it runs only on the **fresh** locator created by `_resetLocatorSession()` (`:365`):
  - **Determinism:** `_onConnectionStatus` runs as a microtask after `emitConnection(down)`, and `_teardownComplete` is assigned inside it — so let one event-loop turn elapse (`await Future<void>.delayed(Duration.zero)`) after emitting the drop **before** calling `scan()`, else the gate at `:118` may not yet observe a pending teardown (plan-review #4).
  - Start an unexpected-drop teardown with the device and locator-dispose `Completer`s held open. Call `provider.scan().listen(...)`. While teardown is in-flight, assert the **old** (dropped) locator's `requestDevicesCallCount == 0` (no call on the stale locator — the H1 hang signature) and no scan items emitted yet.
  - Complete the held teardown `Completer`s. Assert teardown finishes, exactly one fresh locator now exists, the **fresh** locator's `requestDevicesCallCount == 1`, and the old locator's stays `0`. The scan stream becomes live (emits when the fresh locator's `requestDevices` stream emits) — i.e. no permanent hang in the scanning state.

- [x] **Task 4: H1 reconnect integration probe (`BciDeviceManager`-level)** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`
  Drive the same H1 property through the real reconnect entry point, `BciDeviceManager._attemptReconnect()` (`:274` → `_provider.scan()` `:277`). This task is carved out separately because `BciDeviceManager`'s constructor needs six dependencies and there is **no existing manager test to mine** — enumerate the full wiring:
  - **Provider:** a `NeiryBciProvider` built with the recording `locatorFactory` + fake classifier factory satisfies `provider` + `cardioSource` + `eegBandsSource` + `emotionsSource` (one instance implements all four interfaces).
  - **`BciDeviceRepository`:** its constructor takes the **concrete** `BciDevicesGrpcApi` (`BciDeviceRepository.dart:9-14`), **not** `IBciDevicesGrpcApi` — a fake declared `implements IBciDevicesGrpcApi` is not assignable and fails to compile (plan-review #1). Declare the fake `implements BciDevicesGrpcApi` (Dart implicit interface — override only the three public methods `listDevices`/`register`/`delete`; the private `_client` is not part of the interface). Plus `SharedPreferences` via `SharedPreferences.setMockInitialValues({})` + `await SharedPreferences.getInstance()`.
  - **`NfbCalibrationRepository`:** construct with a fake `NfbCalibrationGrpcApi` — no interface, but Dart's implicit interface allows `implements NfbCalibrationGrpcApi`; mirror the existing `FakeNfbCalibrationGrpcApi` in `nfb_calibration_repository_test.dart` — plus the same mocked `SharedPreferences`.
  - **Precondition:** first drive `connectDevice(serial)` to success so `_state` reaches `BciActive` (e.g. `BciImpedance`) and `_connectedSerial` is set — only then does the connection-state listener (`:68-74`) fire `_attemptReconnect()` on a drop.
  - **Assertion (behavioral, not coupled to manager internals):** after forcing the unexpected drop, completing the held teardown, and emitting the device from the fresh locator's scan stream, the manager reconnects via a scanning→connect flow on the **fresh** locator (old locator `requestDevicesCallCount == 0`) rather than hanging in `BciScanning`.

### Phase 4: adversarial interleavings + partial L1

- [x] **Task 5: Adversarial locator/device-sufficient interleaving probes** (depends on Tasks 2, 3)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`
  Add the interleaving probes the note calls out, each needing only locator/device control:
  - **dispose between scan's gate-await and `requestDevices()`**: arrange a teardown to complete (swapping the locator) in the window after `scan()` passes `await _teardownComplete` (`:118`) — assert `requestDevices()` still lands on a live (non-disposed) locator, never on a disposed one.
  - **double unexpected-drop reassigning the in-flight teardown**: fire a second `BciLinkStatus.down` while the first teardown microtask is in-flight; assert the second is a no-op against an already-null `_device` (idempotency guard `:257`) and does not spawn a second teardown / extra reset — `liveCount ≤ 1`, no orphan.
  - **drop-before-subscribe is inert** (replaces the unfireable "drop mid-connect" probe): a `BciLinkStatus.down` emitted on the device's `connectionStateStream` **before** `_subscribeDeviceStreams()` runs (`:189`) has no subscriber, so it cannot trigger `_onConnectionStatus`. Characterize exactly that: gate `createDevice()`/`connect()` open, emit `down` mid-connect, then let connect finish — assert **no teardown ran** (no extra reset, `liveCount == 1`, device drop counters unchanged from the clean-connect baseline). This documents that the connect path is not racing teardown — the meaningful connect-vs-teardown ordering is the `_teardownComplete` gate (`:118`/`:160`), already covered.
  Apply the decision rule (with the churn caveat) to any red probe.

- [x] **Task 6: Partial L1 — thrown teardown on no-completed-connect paths** (depends on Task 1)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`
  Cover the slice of L1 that needs no completed `connect()`: a teardown/cleanup chain where a device-side call **throws** on a path that never reached a successful `connect()` — specifically the `connect()` failure cleanup (`:172-184` → `_resetLocatorSession()` `:182`). **Enter the `:172` catch** by constructing the provider with the **default `NeiryClassifierFactory`** (its cast throws `TypeError` on a fake device — proven by `neiry_bci_provider_device_port_test.dart:140`), so `connect()` fails after `createDevice` and reaches the cleanup. **Make the cleanup throw** via the `GatedFakeDevicePort` `throwOnDisconnect`/`throwOnDispose` flags from Task 1 — gate the throw on **`disconnect()` or `dispose()`** (the calls that path actually makes at `:178-179`) — **not** `stopStream()`, which the failure path does not call. Assert the locator is still reset cleanly (old disposed, one fresh created, `liveCount == 1`, no orphan) and the thrown error is swallowed per the gate's try/catch. Add a comment marking that full L1 (thrown `cancel()` in the classifier-teardown chain after a completed connect) is out of scope here and lives in `[[161-bci-characterization-full-teardown]]`.

### Phase 5: green-up

- [x] **Task 7: Run the suite, resolve red probes, confirm green + behavioral** (depends on Tasks 2-6)
  Files: `test/Bci/neiry_bci_provider_locator_device_races_test.dart`, `lib/Bci/NeiryBciProvider.dart` (only if a red probe forces a gate fix)
  - Run `/usr/local/bin/flutter test test/Bci/neiry_bci_provider_locator_device_races_test.dart`.
  - For each red probe: decide bug-vs-expected per the decision rule **and the churn caveat**. Only `creates − disposes > 1` or a replace-without-dispose is a real gate bug to fix in `NeiryBciProvider`; a redundant paired reset is expected. Do not weaken an assertion to hide a real bug, and do not edit the gate to collapse a correct redundant reset.
  - Audit every assertion: it must reference only **observable** dispose/create counts and wait-ordering (via the recording registry / call counters), never `_teardownComplete` or any gate field name — so the suite survives `_teardownComplete`'s removal in the C1 actor refactor.
  - Final: full file green; run the broader `test/Bci/` group once to confirm no regression in the existing port suites.

## Commit Plan
- **Commit 1** (after tasks 1-4): "Add locator/device race characterization harness with H1 and L2 probes"
- **Commit 2** (after tasks 5-7): "Cover adversarial interleavings and partial L1, green on gate version"
