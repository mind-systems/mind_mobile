# Extract the triplicated teardown sequence into one shared helper (T6)

**Date:** 2026-06-24
**Source:** Phase 56, Tier 3 — cleanup / altitude debt. Protects the Phase 55 invariant.

## Key Findings

- The canonical teardown sequence — `stopStream` → cancel ×10 fan-in subs → dispose classifiers → `device.disconnect()` → `device.dispose()` → recreate (unless terminal) — is **duplicated three times** in `lib/Bci/NeiryBciProvider.dart`:
  1. `_teardownAfterUnexpectedDrop` enqueued command (`:382-459`; cancel chain `:420-429`, classifier dispose `:433`, device `:440-441`, recreate via `finally` `:445-446`),
  2. `disconnect()` (`:492-525`) + `_cancelDeviceSubscriptions` (`:461-489`; cancel chain `:462-480`, classifier dispose `:484`),
  3. `_doDispose` (`:535-572`; `:545-559`, **no** recreate).
- A future reorder must edit all three or they **silently diverge** — reintroducing exactly the ordering races (H1/L1/L2) Phase 55 fixed. This is CONSTRAINT 3 (atomic teardown order) living in triplicate.

## Details

- Extract **one** teardown helper that owns the canonical order, parameterized over the two real axes of variation:
  1. **field source:** capture-into-locals (drop path — fields nulled synchronously before the async body) **vs** read-fields (disconnect/terminal).
  2. **recreate:** reset the locator afterwards (drop/disconnect) **vs** no-recreate (terminal `_doDispose`).
- The drop path keeps its synchronous field-capture + null **before** delegating to the helper (so reconnect sees a clean slate); the helper runs the ordered async teardown. `disconnect()` and `_doDispose` call the same helper with their respective flags.

## Guards

- **Load-bearing, behavior-preserving** — the order must be byte-for-byte the canonical sequence; this is the invariant Phase 55 established. Keep B1/B2 (incl. the ordering probes) **green with no assertion edits**.
- Preserve the drop path's deliberate non-cancel of `_calibrationSub` (`:380`) and the terminal-path's no-recreate.
- Do not alter the queue or the three CONSTRAINTs; this is a code-shape change only.

## Verify

- One helper; the three call sites delegate to it. The B1/B2 ordering/recreate/leak assertions pass unchanged.
- A deliberate reorder in the helper now fails the suite once (proving single-source-of-truth).

**Done-when:** the teardown order exists in exactly one place, the three sites delegate, suites green with no assertion edits.
