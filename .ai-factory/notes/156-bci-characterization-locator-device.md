# Characterization: locator/device races H1 + L2 (green on the gate version) (B1)

**Date:** 2026-06-23
**Source:** Phase 55, layer B (characterization), task B1. Always required. Depends on `[[155-bci-locator-port]]` + `[[158-bci-device-port]]`; encodes races from `[[145-bci-locator-recreate-on-disconnect]]`.

## Key Findings

- H1 and L2 are properties of the **locator/device** lifecycle alone — they need only `LocatorPort` + `DevicePort`, no classifiers/calibrator. So they characterize via the locator/device ports alone, without the larger classifier unprinting.
- **Characterization-first, not red-green:** the gate version is already correct, so these tests are **green now**; their job is to survive the actor refactor (`[[157-bci-actor-serial-command-queue]]`) unchanged (green→green).

## Details

### Suite (green on the current gate version, via the A1/A2 ports)
- **L2 (orphan leak):** split by scenario. A **pure drop** (`_teardownAfterUnexpectedDrop()` `lib/Bci/NeiryBciProvider.dart:478`, no `disconnect()`) ⇒ **exactly one** `LocatorPort.dispose()` (`:463`) and **one** locator create (`:468`), `liveCount == 1`. A **drop racing `disconnect()`** (`:616`) does **NOT** assert a tight count — `disconnect()`'s unconditional reset (`:502`) legitimately performs a **second** paired dispose+create; assert only the behavioral orphan invariants: `liveCount = creates − disposes ≤ 1` at every point, and every replaced locator disposed **before** being overwritten. **Churn caveat:** only `creates − disposes > 1` or a replace-without-dispose is a real bug — never "fix" the gate to collapse a correct redundant reset.
- **H1 (hang):** auto-reconnect `scan()` — reached via `BciDeviceManager._attemptReconnect()` (`lib/Bci/BciDeviceManager.dart:274` → `_provider.scan()` `:277`) — does **not** call `requestDevices()` (`:142`) on the old locator while teardown is in flight; it **waits** (today `await _teardownComplete`) and runs on the fresh locator (no permanent hang in `BciScanning`).
- **Adversarial interleaving probes** that need only locator/device: e.g. `dispose` arriving between a scan's gate-await and `requestDevices()`; a double unexpected-drop reassigning the in-flight teardown; **drop-before-subscribe is inert** — a `down` emitted before `_subscribeDeviceStreams()` (`:189`) has no subscriber, so it triggers no teardown (replaces the unfireable "connect racing a drop" probe).

### Decision rule (changed from the Preview framing)
The phase is promoted, so probes no longer decide promote-vs-gate. A **red** probe = a **real bug in the gate version** → fix it **inside this task** in the gate code, after which it must stay green.

### Harness constraints (resolved in plan-review — bake into the suite)
- **Device fake** needs `throwOnDisconnect`/`throwOnDispose` flags (the timing `Completer`s do not throw) for the partial-L1 swallow check at `:177-180`; the **initial** failure that enters the `:172` catch is induced by the default `NeiryClassifierFactory` (its cast throws `TypeError` on a fake device).
- The recording locator **vends a fresh device per `createDevice`** — a shared device whose `dispose()` closes broadcast controllers breaks the reconnect probe.
- The **manager-level** H1 probe wires six deps: a fake `implements BciDevicesGrpcApi` (the **concrete** type — `BciDeviceRepository` does not take the interface), a fake `implements NfbCalibrationGrpcApi`, `SharedPreferences.setMockInitialValues({})`, and a `connectDevice → BciActive` precondition before a drop fires reconnect.
- **Determinism:** after `emitConnection(down)`, let one event-loop turn elapse (`await Future<void>.delayed(Duration.zero)`) before reading the scan gate — `_onConnectionStatus`/`_teardownComplete` are assigned on a microtask.

## Guards

- Tests only (+ any gate-version fix a red probe forces); no actor here.
- **Assertions stay behavioral** — observable dispose/create counts and wait-ordering, **not** coupled to `_teardownComplete` or other gate field names, so they survive its removal in `[[157-bci-actor-serial-command-queue]]`.
- Single-resource scope. **Anti-goal** — domain latches and the `channel.events` bus are out of scope (see `[[155-bci-locator-port]]`).
- L1 (a thrown `cancel()` in the classifier-teardown chain) is **only partially** covered here — on paths without a completed `connect()`. Full L1 lives in `[[161-bci-characterization-full-teardown]]`.

## Verify

- Suite green on the current gate version (after any red probe is fixed in gate code), committed as the contract `[[157-bci-actor-serial-command-queue]]` must preserve with no assertion edits.
