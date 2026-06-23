# DevicePort + neiry adapter (A2, behavior-preserving)

**Date:** 2026-06-23
**Source:** Phase 55, layer A (unprinting), task A2. Always required (both scope branches).

## Key Findings

- The provider couples to the **concrete** `neiry.Device` (decl `neiry_kit/lib/src/api/device.dart:32`), obtained from `_locator.createDevice(serial)` (`lib/Bci/NeiryBciProvider.dart:158`).
- The device surface the provider actually calls: `connect()` (`:160`), `start()` (`:165`), `stopStream()` (`:518`, `:623`, `:662`), `disconnect()` (`:184`, `:556`, `:633`, `:668`), `dispose()` (`:185`, `:557`, `:639`, `:669`), `isStarted` (`:621`, `:661`), and three streams: `connectionStateStream` (`:195`), `resistanceStream` (`:200`), `batteryStream` (`:205`).

## Details

- Introduce a **narrow domain port** `DevicePort` in `lib/Bci/` with exactly that surface (5 methods + `isStarted` + 3 streams). A thin `NeiryDeviceAdapter implements DevicePort` wraps `neiry.Device`.
- `LocatorPort.createDevice` (`[[155-bci-locator-port]]`) returns a `DevicePort`; the locator adapter wraps the returned `neiry.Device` in `NeiryDeviceAdapter`. The two ports are a **co-dependent pair** and land together.
- The fake `DevicePort` exposes **test-controlled async** in `stopStream`/`disconnect`/`dispose` and controllable stream controllers, so characterization tests can drive the teardown ordering and the connection/resistance/battery streams.
- Same **architectural decision** as A1: narrow port + thin adapter; the fake implements the port, not the whole `neiry.Device` (reject the implicit-interface spaghetti-fake). See `[[155-bci-locator-port]]`.

## Guards

- **Behavior-preserving only** — default adapter = current construction; do not touch the gate (`_teardownComplete` `:38`, drains `:106`/`:151`/`:617`) or teardown ordering.
- Single-resource scope. **Anti-goal** — out of scope, do NOT fold in: domain latches `ModuleStateChannel._isPendingStart/_isPendingPause/_backoffConfirmed`, `Breath/MeditationModuleStateChannel._started/_ended`, `BiometricStreamClient._sessionConfirmed/_isReady`; and the `channel.events` `ModuleStateEvent` bus.
- Co-dependent with `[[155-bci-locator-port]]`; together they unblock `[[156-bci-characterization-locator-device]]`.

## Verify

- Production build unchanged (default adapter).
- A test injects a fake `DevicePort` (via the fake locator's `createDevice`) and drives `connect`/`start`/`stopStream`/`disconnect`/`dispose` + the three streams.
