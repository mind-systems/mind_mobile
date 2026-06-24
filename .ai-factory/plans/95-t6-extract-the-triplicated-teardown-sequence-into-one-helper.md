# Plan: Extract the triplicated teardown sequence into one helper

## Context
The canonical BCI teardown order (`stopStream → cancel ×10 fan-in subs → dispose classifiers → device.disconnect → device.dispose → recreate`) is duplicated across three call sites in `lib/Bci/NeiryBciProvider.dart`; a future reorder must edit all three or they silently diverge, reintroducing the H1/L1/L2 ordering races Phase 55 fixed. This milestone collapses the order into one shared, parameterized helper while preserving behavior exactly.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Background — the three current sites (read before editing)

All in `lib/Bci/NeiryBciProvider.dart`:

1. **Drop path** — `_teardownAfterUnexpectedDrop` (`:398-480`). Synchronous prefix captures `_device`, `_classifierSet`, and the 10 fan-in subs into locals and nulls those fields (clean slate for reconnect); then an `unawaited(_queue.enqueue(...))` body (wrapped in `.catchError`) runs the ordered async teardown: `stopStream` (unconditional, swallow-silent), cancel 10 subs, classifier dispose, `device.disconnect()` + `device.dispose()` in **one** try block, and `_resetLocatorSession()` in a `finally` (recreate). Deliberately does **not** touch `_calibrationSub`.
2. **disconnect()** (`:513-546`) + helper `_cancelDeviceSubscriptions()` (`:482-510`). `stopStream` guarded by `_device?.isStarted == true` (logs `stopStream error`); `_cancelDeviceSubscriptions()` cancels the 10 subs reading fields + nulls each + disposes classifier + nulls it; `device.disconnect()` and `device.dispose()` in **separate** try blocks; `_device = null`; `_resetLocatorSession()` (recreate); emit `BciLinkStatus.down`. Does not touch `_calibrationSub`.
3. **_doDispose()** (`:556-593`). After `_disposed = true`, `_queue.close()`, `await _queue.idle`: `stopStream` guarded (swallow-silent); `_cancelDeviceSubscriptions()`; **`_calibrationSub` cancel + null** (terminal only); `device.disconnect()` + `device.dispose()` in **one** try block; `_device = null`; **no recreate** — disposes `_locator` directly and closes the 9 stream controllers.

The 10 fan-in subs, in canonical cancel order: `_connectionSub`, `_resistanceSub`, `_batterySub`, `_nfbSub`, `_nfbErrorSub`, `_cardioSub`, `_rrSub`, `_emotionsSub`, `_emotionsErrorSub`, `_memsSub`.

## Behavior constraints (must hold — load-bearing)

- **Canonical order is byte-for-byte preserved.** The B2 ordering probe (`test/Bci/neiry_bci_provider_full_teardown_test.dart`, "pure drop") asserts the exact step list `['stopStream','cancelFanIn','classifierDispose','deviceDisconnect','deviceDispose','locatorDispose','locatorCreate']` and the "drop + concurrent disconnect" probe asserts that block is contiguous. The B1 races suite (`test/Bci/neiry_bci_provider_locator_device_races_test.dart`) pins the disconnect sequence and the no-orphan/recreate invariants. **No assertion edits allowed** in any test.
- **Drop path keeps its synchronous capture-and-null prefix** before delegating, so reconnect's `connect()` sees nulled fields.
- **Terminal path does not recreate** the locator (`_doDispose` disposes `_locator` itself; `_resetLocatorSession` early-returns when `_disposed`, so it cannot be reused for terminal locator disposal).
- **Drop path's non-cancel of `_calibrationSub`** is preserved; only the terminal path cancels it.
- **stopStream variation preserved:** drop calls it unconditionally (native may be gone), disconnect/dispose guard on `isStarted`.
- The queue/`unawaited`/`.catchError` wrapper on the drop path, the post-`idle` terminal teardown, and the `BciLinkStatus.down` emit after `disconnect()` all stay where they are — the helper owns only the ordered async teardown unit, not the enqueue/idle/emit scaffolding around it.

## Tasks

### Phase 1: Introduce the shared helpers

- [x] **Task 1: Add a field capture-and-null helper**
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add a private method that captures `_device`, `_classifierSet`, and the 10 fan-in sub fields into locals, nulls all 12 of those fields, and returns the captured values (e.g. via a record `(DevicePort? device, ClassifierSet? classifierSet, List<StreamSubscription<dynamic>?> subs)`, with `subs` in canonical cancel order). It must **not** touch `_calibrationSub` or `_device`-adjacent controllers. This consolidates the capture/null logic that the drop path does inline and that `_cancelDeviceSubscriptions` does field-by-field. Do not wire it yet.

- [x] **Task 2: Add the ordered teardown helper** (depends on Task 1)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Add a private async method that performs the canonical ordered sequence on **passed-in locals** (never reading instance fields), parameterized over exactly two axes plus the stopStream guard:
  - inputs: `DevicePort? device`, `ClassifierSet? classifierSet`, `List<StreamSubscription<dynamic>?> subs`
  - `bool forceStopStream` — `true` (drop): `try { await device?.stopStream(); } catch (_) {}` unconditionally; `false` (disconnect/dispose): only when `device?.isStarted == true`, wrapped in try/catch.
  - `bool recreate` — `true`: call `_resetLocatorSession()` in a `finally`; `false`: skip (terminal owns its own locator disposal).
  Sequence: (1) stopStream per `forceStopStream`; (2) cancel each sub in `subs` order; (3) `classifierSet?.dispose()` in try/catch with `logPrint`; (4) `device?.disconnect()` then `device?.dispose()` in **one** combined try/catch with `logPrint`; (5) `finally` → `if (recreate) await _resetLocatorSession();`. Keep error logging via `logPrint` (uniform message is acceptable — no test inspects log text). Do not wire it yet.

### Phase 2: Migrate the three call sites

- [x] **Task 3: Migrate the drop path** (depends on Tasks 1-2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `_teardownAfterUnexpectedDrop`, replace the inline capture/null block with the Task 1 helper (still synchronous, before the enqueue, preserving the clean-slate guarantee). Replace the inline async body inside `unawaited(_queue.enqueue(() async {...}))` with a single `await` of the Task 2 helper using `forceStopStream: true, recreate: true` and the captured locals. Keep the surrounding `_disposed` early-return, the `enqueue`, the `unawaited`, and the existing `.catchError` wrapper (with its `QueueClosedException` handling) exactly as-is. Confirm `_calibrationSub` is still untouched.

- [x] **Task 4: Migrate disconnect()** (depends on Tasks 1-2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  Inside the existing `_queue.enqueue` slot, replace the stopStream + `_cancelDeviceSubscriptions()` + disconnect/dispose + `_device = null` + `_resetLocatorSession()` block with: Task 1 capture-and-null helper, then `await` Task 2 helper with `forceStopStream: false, recreate: true`. Keep the trailing `_connectionStateController.add(BciLinkStatus.down)` emit. Note: this aligns disconnect()'s device disconnect/dispose error handling with the canonical combined-try behavior (the only error-path edge covered by tests is the drop path, which already uses the combined form) — verify the suite stays green in Task 6.

- [x] **Task 5: Migrate _doDispose() and remove dead code** (depends on Tasks 1-2)
  Files: `lib/Bci/NeiryBciProvider.dart`
  In `_doDispose`, keep `_disposed = true`, `_queue.close()`, and `await _queue.idle` exactly as-is. Replace the stopStream + `_cancelDeviceSubscriptions()` + device disconnect/dispose block with: Task 1 capture-and-null helper, then `await` Task 2 helper with `forceStopStream: false, recreate: false`. Preserve the terminal `_calibrationSub?.cancel(); _calibrationSub = null;` (its position relative to device disconnect is behavior-neutral — no shared state, not covered by any ordering probe; place it adjacent to the helper call). Keep the direct `_locator.dispose()` (try/catch) and the nine `*.close()` controller calls afterward. Once disconnect() and `_doDispose()` no longer call `_cancelDeviceSubscriptions`, **delete `_cancelDeviceSubscriptions`** if it has no remaining callers.

### Phase 3: Verify single source of truth

- [x] **Task 6: Run the BCI teardown suites and the reorder probe** (depends on Tasks 3-5)
  Files: (no source changes unless a regression is found)
  Run `/usr/local/bin/flutter test test/Bci/` and confirm all suites pass with **no assertion edits** — especially the B2 canonical-order and contiguous-block probes and the B1 races/no-orphan/recreate invariants. Then temporarily reorder two adjacent steps inside the Task 2 helper (e.g. swap classifier dispose and device disconnect), re-run, and confirm the suite now fails in exactly one place — proving the order is single-sourced — then revert the deliberate reorder. Leave the helper in canonical order.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add shared BCI teardown capture and ordered-sequence helpers"
- **Commit 2** (after tasks 3-5): "Delegate all three BCI teardown sites to the shared helper"
- **Commit 3** (after task 6): "Verify single-source teardown order against BCI suites"
