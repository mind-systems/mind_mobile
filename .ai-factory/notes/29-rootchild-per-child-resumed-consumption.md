# Root/child — per-child RESUMED consumption (concurrent-duplicate closure)

**Date:** 2026-07-04
**Source:** conversation context (milestone-rescue of task 26); mind_api confirmation that per-child RESUMED is live

## Key Findings

- Task 26 (note 19) left one residue open: the **rare concurrent duplicate**. With ≥2 live children under one root, the server historically emitted a single collapsed reconnect frame (`soleChild ?? root`, `activity-engine.service.ts:639`) — with two children `soleChild` is null so the **root** frame arrived, and the second child never got its own typed RESUMED. That child's pending-start was never cleared → after the settling window a same-token resend fired → past the ~10s dedup window the server created a **duplicate child**.
- **The API dependency is now satisfied.** mind_api commit `47e6914` ("Emit a RESUMED session:state per live child on reconnect"): `module-state.grpc.controller.ts:183-202` loops `listChildren` and emits a **per-child RESUMED**, each carrying its own `activity_type` / `isPaused` (mind_api note 44 asserts "2 RESUMED frames, one per child id"). So in the ≥2-children reconnect case both `breath`-RESUMED and `meditation`-RESUMED now physically arrive as separate frames. This task is **unblocked**, not gated.
- Client work: ensure reconcile-by-arrival (note 20) actually **consumes both** per-child RESUMED frames so **both** pending-starts clear on their own `activity_type` — no resend, no duplicate. The single-child path already works; this closes the concurrent path.
- **Lands on the note-28 chokepoint / explicit states** — the per-child RESUMED arrival is another resolution trigger that clears/adopts pending starts and feeds the settling window's adopt-vs-resend decision; it must route through the note-28 chokepoint, not add a fourth hand-guarded site. Depends on note 28.

## Details

### Current state (exact)
- Reconcile-by-arrival lives in the reconnect/settling path (note 20): `_resolveSettling` `ModuleStateChannel.dart:~530-570` consults `childOfType` for adopt-vs-resend; the reconcile sweep evicts non-re-arrived cached children before adopt.
- Pending-start clear: `_clearPendingStart` on ACTIVE/RESUMED of the exact `activity_type`.
- Server now emits N per-child RESUMED frames on reconnect (mind_api `47e6914`) instead of one collapsed frame — the client will start receiving 2 frames where it previously received 1.

### Change
- On a ≥2-child reconnect, each arriving per-child RESUMED clears **its own type's** pending-start via the note-28 chokepoint (adopt/confirm path), so the settling window's adopt-vs-resend sees **both** children as arrived → **zero** resend for the second child.
- Verify the arrival ordering / settling-window interaction: both frames must land (or be reconciled) before the window's resend decision, so neither child is treated as absent.

### Guards
- Never resend a start whose child the server already resumed (the per-child RESUMED must clear it first) — this is the whole point; the past-dedup-window duplicate must not reappear.
- Route through the note-28 chokepoint — no new hand-guarded resolution site.

### Verify (RED scenario first)
- Extend `start_race_contract_test.dart` (SC-1 concurrent shape): two live children (breath + meditation), drop + reconnect, server emits **2** per-child RESUMED frames; assert **both** pending-starts cleared and **zero** resend for either type. Write it RED against the pre-consumption behaviour, then green it.
