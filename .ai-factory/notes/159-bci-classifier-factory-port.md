# ClassifierFactory port + adapter (A3, behavior-preserving)

**Date:** 2026-06-23
**Source:** Phase 55, layer A (unprinting), task A3.

## Key Findings

- After `connect()`, the provider builds **four** channel-backed classifiers inline from the device: `neiry.NfbClassifier(_device!)` (`lib/Bci/NeiryBciProvider.dart:161`), `neiry.CardioClassifier(_device!)` (`:162`), `neiry.EmotionsClassifier(_device!)` (`:163`), `neiry.MEMSClassifier(_device!)` (`:164`); fields at `:40-43`. `NfbClassifier` decl is a concrete channel-backed class (`neiry_kit/lib/src/api/classifiers/nfb_classifier.dart:37`).
- They expose **seven** streams the provider subscribes to: nfb `stateStream` (`:212`) + `errorStream` (`:217`); cardio `stateStream` (`:222`) + `rrStream` (`:227`); emotions `stateStream` (`:232`) + `errorStream` (`:237`); mems `memsStream` (`:242`). Each classifier is `dispose()`-d on every teardown path (connect-failure `:168-180`, unexpected-drop microtask `:534-549`, disconnect `:590-608`).
- This classifier surface is what makes the full connect-teardown chain large; it is **not** needed to characterize the locator/device races (H1/L2). Only the full-L1/teardown-ordering coverage needs it.

## Details

- Introduce a `ClassifierFactory` port + a `ClassifierSet` port covering only the called surface: build the four classifiers from a `DevicePort`, expose the seven streams, and `dispose()` each. A thin `NeiryClassifierFactory` adapter wraps the real `neiry.*Classifier(device)` constructions.
- The fake `ClassifierSet` exposes **controllable stream controllers** and a **throwable `dispose()`** (and the fan-in subscriptions cancel-able with a controllable throw) so `[[161-bci-characterization-full-teardown]]` can assert the L1 path (a thrown `cancel()`/`dispose()` in the chain still reaching recreate) and the classifier-disposal ordering.
- Same **architectural decision** as A1/A2: narrow port + thin adapter; fake implements the port, not the four vendor classes. See `[[155-bci-locator-port]]`.

## Guards

- **Behavior-preserving only** — default adapter = current inline construction; classifier build/dispose order unchanged; do not touch the gate or teardown ordering.
- Depends on `[[158-bci-device-port]]` (classifiers are built from a `DevicePort`).
- Single-resource scope. **Anti-goal** — domain latches and the `channel.events` bus are out of scope (see `[[155-bci-locator-port]]`).

## Verify

- Production build unchanged (default adapter).
- A test injects a fake `ClassifierSet` and drives the seven streams + throwable disposes; precedes `[[161-bci-characterization-full-teardown]]`.
