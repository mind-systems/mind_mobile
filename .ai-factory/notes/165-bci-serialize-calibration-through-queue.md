# Serialize calibration through the queue + guard against dispose (T1)

**Date:** 2026-06-24
**Source:** Phase 56 (Phase 55 review follow-ups), Tier 1 — the only blocking correctness finding.

## Key Findings

- `startCalibration` (`lib/Bci/NeiryBciProvider.dart:275`), `startQuickCalibration` (`:311`) and `importCalibration` (`:339`) call `neiry.NfbCalibrator.*` **directly** and touch `_calibrationSub` (`:74`) / `_calibrationController` (`:63`) — they are **never** enqueued on `_queue` and have **no `_disposed` guard** (guards exist only at `:365`/`:371`/`:383` and the set at `:536`).
- **(a) Add-after-close crash.** `_doDispose` cancels `_calibrationSub` (`:549`) then awaits device + locator disposal (`:552`/`:559`, both yield) **before** closing `_calibrationController` (`:566`). A calibration event arriving in that window — or any `startCalibration` after dispose — calls `_calibrationController.add` (`:281`/`:298`/`:303`/`:329`/`:332`) on a closed controller → `Bad state: Cannot add event after closing`; the freshly-listened `_calibrationSub` also leaks.
- **(b) Lifecycle race.** An unexpected drop during calibration enqueues a teardown that `device.disconnect()`/`device.dispose()` (`:440-441`) the native device **concurrently** with the live calibrator (which runs outside the queue).

## Details

**DECISION (core choice of this task) — recommend A:**
- **A (recommended):** route all three calibration methods through `_queue.enqueue(...)` **and** add a `_disposed`/closed-controller guard. Serializing them behind the same queue closes **both** (a) and (b): calibration can no longer run concurrently with a teardown command, and a post-dispose enqueue is rejected by the closed queue.
- **B (minimal):** `_disposed` guard + guard every `_calibrationController.add` against `isClosed`. Closes (a) only — leaves the lifecycle race (b) open.

**Constraint 1 caveat for option A:** a calibration command must not `await` another enqueued command (the queue's no-self-deadlock rule). Calibration only awaits the static `neiry.NfbCalibrator.*` futures/stream, never another `_queue` op, so it is queue-safe.

## Guards

- **Preserve the resume-after-reconnect behavior:** `_teardownAfterUnexpectedDrop` deliberately does **not** cancel `_calibrationSub` (`:380` comment). Only `_doDispose` (terminal) cancels it. The fix must keep that — do not add a calibration-sub cancel to the drop path.
- Keep the B1/B2 characterization suites green; do not touch the queue's three CONSTRAINTs.
- The 11-field neiry↔domain mapping duplicated across the three methods is extracted separately in `[[171-bci-extract-calibration-mapping]]` — best landed in the same change.

## Verify

- After dispose, a calibration event (or a `startCalibration` call) no longer throws `Bad state: Cannot add event after closing`; no leaked `_calibrationSub`.
- An unexpected drop mid-calibration does not interleave native device teardown with a live calibrator (option A).
- B1/B2 suites still green.

**Done-when:** all three calibration methods are queue-serialized + dispose-guarded (option A) or guarded (option B per the ruling), the add-after-close crash is gone, and the suites pass.
