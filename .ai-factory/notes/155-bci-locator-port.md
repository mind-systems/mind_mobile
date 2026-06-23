# LocatorPort + neiry adapter (A1, behavior-preserving)

**Date:** 2026-06-23
**Source:** Phase 55, layer A (unprinting), task A1. Always required (both scope branches). Consolidates `[[145-bci-locator-recreate-on-disconnect]]`.

## Key Findings

- The provider couples to the **concrete** `neiry.DeviceLocator` (decl `neiry_kit/lib/src/api/device_locator.dart:35`), constructed inline at `lib/Bci/NeiryBciProvider.dart:35` and recreated at `:468`. With construction hard-wired to the real SDK the locator lifecycle cannot be driven deterministically from a test.
- The surface the provider actually calls on the locator is small: `requestDevices(type:, searchTime:)` (`:142`), `createDevice(serial)` (`:158`), `dispose()` (`:463`, `:675`).

## Details

- Introduce a **narrow domain port** `LocatorPort` in `lib/Bci/` exposing exactly that surface: `requestDevices({type, searchTime})`, `createDevice(serial)`, `dispose()`. `createDevice` returns a `DevicePort` (the port from `[[158-bci-device-port]]`), so A1 and A2 are a co-dependent pair landing together.
- A thin `NeiryLocatorAdapter implements LocatorPort` wraps `neiry.DeviceLocator` (and wraps the returned `neiry.Device` in the device adapter). The provider holds `LocatorPort _locator`, constructor-injected, **defaulting to `NeiryLocatorAdapter()`** so production is byte-identical.
- **Architectural decision (not a swap-factory):** the seam is a narrow port under *only* the called surface + a thin adapter. The fake implements the 3-method port, not the whole vendor class. The vendor classes are plain Dart, so a fake *could* `implements neiry.DeviceLocator` via the implicit interface — **rejected**: that forces a spaghetti-fake across the entire vendor surface. Port the surface you call.
- The fake exposes **test-controlled async** in `dispose()`/`createDevice()`/`requestDevices()` so the characterization tests can schedule interleavings.

## Guards

- **Behavior-preserving only** — default adapter = current construction; do not touch the gate (`_teardownComplete` `:38`, drains `:106`/`:151`/`:617`) or teardown ordering.
- Single-resource scope (the BCI locator of this provider). **Anti-goal** — out of scope, do NOT fold in: domain latches `ModuleStateChannel._isPendingStart/_isPendingPause/_backoffConfirmed`, `Breath/MeditationModuleStateChannel._started/_ended`, `BiometricStreamClient._sessionConfirmed/_isReady`; and the `channel.events` `ModuleStateEvent` bus.
- Co-dependent with `[[158-bci-device-port]]`; precedes `[[156-bci-characterization-locator-device]]`.

## Verify

- Production build unchanged (default adapter).
- A test constructs the provider with a fake `LocatorPort` and observes/await-gates its calls — minimal smoke test asserts the fake (not a real SDK locator) is used.
