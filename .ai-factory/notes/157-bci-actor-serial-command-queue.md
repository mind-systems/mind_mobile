# Actor / serial command queue refactor (green→green) (C1)

**Date:** 2026-06-23
**Source:** Phase 55, layer C (refactor), task C1. Depends on the green safety nets `[[156-bci-characterization-locator-device]]` (B1) + `[[161-bci-characterization-full-teardown]]` (B2); over the A-layer ports `[[155-bci-locator-port]]` / `[[158-bci-device-port]]` / `[[159-bci-classifier-factory-port]]`. Supersedes the point patches in `[[145-bci-locator-recreate-on-disconnect]]`.

## Key Findings

- The gate version serializes the shared mutable `_locator` (`lib/Bci/NeiryBciProvider.dart:35`, recreate `:468`) through three separate drain sites of `_teardownComplete` (`:38`, set `:513`; drained at scan `:106`, connect `:151`, disconnect `:617`) plus a `try/finally` around the recreate (`:561-562`). Smeared serialization, no single owner — H1/L1/L2 were each closed by a different patch.
- One **serial command queue (actor)** inside `NeiryBciProvider`, through which **all** locator/device ops flow (`scan` / `connect` / `disconnect` / teardown-after-drop / `dispose`), makes two operations physically unable to interleave on an `await` — H1/L1/L2 become **unrepresentable by construction**, not patched.
- **green→green:** the characterization suite(s) must stay green with no assertion edits; the gate machinery is then deleted.

## Details

All locator/device ops are submitted to one in-order executor; the executor runs one command to completion before the next. Removed once the queue owns ordering: `_teardownComplete` (field `:38`, set `:513`), the three drains (`:106` / `:151` / `:617`), and the `try/finally` around the recreate (`:561-562`).

### Design constraints (binding — not open questions)

**CONSTRAINT 1 — strictly one-directional dependency (resolves the deadlock risk).**
No command, while executing in the queue's single slot, may `await` another command enqueued in that same queue — that is exactly what self-deadlocks a serial executor. Concretely: teardown runs its native steps **inline** and never waits on an enqueued operation; auto-reconnect `scan()` (`BciDeviceManager._attemptReconnect()` `lib/Bci/BciDeviceManager.dart:274` → `_provider.scan()` `:277`) is **enqueued** and runs **after** teardown. The dependency is strictly `reconnect-scan → teardown`, never the reverse. The executor must not re-enter the task it is currently running.

**CONSTRAINT 2 — terminal poison-pill dispose (resolves the mid-queue cancellation risk).**
`dispose` is terminal: (a) closes the queue to new enqueues; (b) cancels/drops the tail so queued `scan`/`connect` that would spawn native resources do **not** run; (c) performs the final teardown; (d) does **not** recreate the locator (recreate on the terminal path = an orphaned locator, the L2 failure mode). Preserves the existing "terminal path disposes, never recreates" rule (`_doDispose()` `:658`, locator dispose `:675`).

**CONSTRAINT 3 — atomic command, preserved internal order (resolves the SDK-ordering risk).**
The queue serializes **between** commands; the order **inside** a command is hard-wired and never split or reordered. The `teardown` command is one atomic unit with the verified canonical SDK sequence: `stopStream()` (`:518`/`:623`/`:662`) → cancel the ten fan-in subscriptions (`:521-530`) → dispose the four classifiers (`:534-549`) → `device.disconnect()` (`:556`) → `device.dispose()` (`:557`) → `locator.dispose()` (`:463`) → recreate (`:468`, unless terminal). Never enqueue these steps individually. Canon: `neiry_kit/docs/guides/teardown.md`. This promotes note 145's intra-microtask-ordering "Open Question" into a hard constraint.

## Guards

- **No open questions** — the three risks (deadlock / mid-queue cancellation / SDK ordering) are resolved by the three constraints above; do not re-raise them.
- Keep the characterization suite(s) green with **no assertion edits** — a needed assertion change means the refactor changed observable behavior and is wrong.
- Single-resource actor around the BCI locator/device **only** — **not** an app-wide dispatcher. **Anti-goal** — out of scope, do NOT fold in: domain latches (single-writer, fed from one stream) `ModuleStateChannel._isPendingStart/_isPendingPause/_backoffConfirmed`, `Breath/MeditationModuleStateChannel._started/_ended`, `BiometricStreamClient._sessionConfirmed/_isReady`; and the cross-layer bus, the typed `ModuleStateEvent` stream on `channel.events`. Unifying those welds independent lifecycles and breaks the module boundary.
- Last in the chain.

## Verify

- The characterization suites (notes 156 + 161) are **green** after the refactor, unchanged.
- `_teardownComplete` and all three drain sites are gone; no `await`-in-the-middle recreate remains.
- A unit test enqueues two commands and asserts they run fully serialized (no interleave), and that a `dispose` mid-queue cancels the tail and does not recreate the locator.
