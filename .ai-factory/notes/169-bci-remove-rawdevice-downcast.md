# Remove the `rawDevice` downcast that defeats the DevicePort abstraction (T5)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 3 — cleanup / altitude debt.

## Key Findings

- `NeiryClassifierFactory.build` (`lib/Bci/Ports/NeiryClassifierFactory.dart:18`) takes an abstract `DevicePort` but immediately downcasts: `final raw = (device as NeiryDeviceAdapter).rawDevice;` (`:19`), reading the public vendor accessor `NeiryDeviceAdapter.rawDevice` (`lib/Bci/Ports/NeiryDeviceAdapter.dart:29`).
- This defeats the port abstraction: a non-Neiry `DevicePort` (a test fake, or a second vendor's adapter) hits a `CastError` at runtime. The `ClassifierFactory` interface (`lib/Bci/Ports/ClassifierFactory.dart`) promises construction from any `DevicePort`, but the only implementation silently requires a `NeiryDeviceAdapter`.

## Details

**DECISION (port-shape choice) — pin one:**
- **Option 1 (recommended):** have `NeiryClassifierFactory` take a `neiry.Device` directly at the construction site (it already imports `neiry_kit`) and **drop the `rawDevice` getter** — the provider's `connect()` holds the concrete adapter, so it can hand the neiry device to the neiry factory without routing through the abstract `DevicePort`. This narrows the `ClassifierFactory.build` signature off `DevicePort`.
- **Option 2:** keep `build(DevicePort)` but pair the adapter and factory so the handle travels without a public vendor accessor (e.g. the adapter constructs its own classifier set), removing `rawDevice` from the public surface.

Either way the `rawDevice` public getter goes away. Note this **touches the `ClassifierFactory` port shape** — coordinate with the A3 fake used by the classifier-port test.

## Guards

- Behavior-preserving — same four classifiers from the same device.
- Keep `neiry_kit` quarantined to the provider + the four adapter files.
- Update the A3 classifier-port test's fake to the new shape.

## Verify

- No `as NeiryDeviceAdapter` / `rawDevice` remains; a non-Neiry `DevicePort` no longer risks a `CastError` (or the seam no longer accepts an abstract `DevicePort` at all under Option 1).
- Classifier-port test + B1/B2 green.

**Done-when:** the downcast and the `rawDevice` getter are gone per the chosen option, the port shape is consistent, suites green.
