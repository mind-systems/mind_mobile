# Characterization: full teardown chain — L1 + classifier-disposal ordering (B2)

**Date:** 2026-06-23
**Source:** Phase 55, layer B (characterization), task B2. Depends on `[[159-bci-classifier-factory-port]]`; encodes L1 from `[[145-bci-locator-recreate-on-disconnect]]`.

## Key Findings

- **L1** lives in the full connect-teardown chain: the unexpected-drop microtask cancels **ten** fan-in subscriptions (`lib/Bci/NeiryBciProvider.dart:521-530`) — the seven classifier streams created at `:212-242` plus connection/resistance/battery — then disposes the four classifiers (`:534-549`), then `device.disconnect()` (`:556`) → `device.dispose()` (`:557`), and the locator recreate is appended in the `finally` (`:561-562` → `_resetLocatorSession()` `:463`/`:468`). A thrown `cancel()`/`dispose()` anywhere in that chain must still reach the recreate.
- Covering this requires driving the classifier streams and throwable disposes — i.e. the classifier (A3) port. It is larger than B1, which needs only the locator/device ports.

## Details

### Suite (green on the current gate version, via the A3 port)
- **L1 (skipped recreate):** inject a **throwing** `cancel()`, classifier `dispose()`, **or `device.disconnect()`/`device.dispose()`** (`:556`/`:557`) — anywhere in the chain (`:521-557`) — and assert the `try/finally` (`:561-562`) still runs the recreate: no orphan, no skipped reset. For the **pure-drop** scenario that is exactly one create; if a probe races `disconnect()`, apply the **churn caveat** below (a redundant paired dispose+create from `disconnect()`'s `:502` reset is not a leak — assert `liveCount ≤ 1` + no replace-without-dispose, not a tight count).
- **Classifier-disposal ordering probes:** assert the canonical SDK teardown order holds as one unit — `stopStream()` (`:518`) → cancel fan-in (`:521-530`) → dispose classifiers (`:534-549`) → `device.disconnect()` (`:556`) → `device.dispose()` (`:557`) → `locator.dispose()`+recreate — and is never split/reordered under interleaving.
### Decision rule
Same as B1: a **red** probe = a real gate-version bug → fix it **in this task**, then it must stay green.

### Harness constraints (inherited from B1 — reuse, do not re-derive)
- Build on B1's harness (`[[156-bci-characterization-locator-device]]`): the recording locator + `GatedFakeDevicePort` with `throwOnDisconnect`/`throwOnDispose`, plus the throwable classifier `dispose()` on the A3 `FakeClassifierSet`. Add throw-injection on the **subscription `cancel()`** path too (the `:521-530` chain) so "thrown anywhere still recreates" is fully covered — `cancel`, classifier `dispose`, and device `disconnect`/`dispose` are all chain links.
- The recording locator **vends a fresh device per `createDevice`** — a shared device whose `dispose()` closes broadcast controllers breaks any reconnect leg.
- **Determinism:** after `emitConnection(down)`, let one event-loop turn elapse (`await Future<void>.delayed(Duration.zero)`) before asserting on the teardown — `_onConnectionStatus`/`_teardownComplete` are assigned on a microtask.
- **Churn caveat** (same as B1): only `creates − disposes > 1` or a replace-without-dispose is a real bug; never collapse a correct redundant reset to satisfy a tight count.

## Guards

- Tests only (+ any gate-version fix a red probe forces); no actor here.
- **Assertions stay behavioral** (dispose/create counts, ordering of the teardown unit), not coupled to gate field names — survive `_teardownComplete` removal.
- Depends on `[[159-bci-classifier-factory-port]]`. Together with `[[156-bci-characterization-locator-device]]` it is the full contract `[[157-bci-actor-serial-command-queue]]` must preserve.
- Single-resource scope. **Anti-goal** — domain latches and the `channel.events` bus are out of scope (see `[[155-bci-locator-port]]`).

## Verify

- Suite green on the current gate version (after any red probe is fixed), committed as the contract the actor refactor must keep green with no assertion edits.
