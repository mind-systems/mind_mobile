# Code Review — Milestone 8: `BiometricBatcher`

**Files reviewed:**
- `lib/Biometrics/BiometricBatcher.dart` (new, 64 lines)

**Cross-referenced:**
- `lib/Biometrics/BioStreamRouter.dart`
- `lib/Biometrics/BiometricStreamClient.dart`
- `lib/Biometrics/BioSample.dart`
- `.ai-factory/notes/28-biometric-stream-pipeline.md` (Milestone 8)
- `.ai-factory/plans/70-implement-biometricbatcher.md`
- `.ai-factory/RULES.md`

**Risk level:** 🟢 Low

---

## Plan adherence

Every numbered step in the plan maps cleanly to code:

| Plan step | Code location |
|---|---|
| Task 1 — constants, fields, constructor, subscribe inside body | `BiometricBatcher.dart:14-31` |
| Task 2 — `_onSample` append / size-flush / `??=` timer | `BiometricBatcher.dart:35-42` |
| Task 3 — `_flushNow` empty-guard / snapshot / clear / cancel-null timer / send | `BiometricBatcher.dart:46-53` |
| Task 4 — `dispose` cancel-sub / null sub / cancel-null timer / final flush | `BiometricBatcher.dart:57-63` |

The constants, fields, dartdoc, import order, and `// ── Section ──` separators match the style of `BiometricStreamClient.dart` / `BioStreamRouter.dart` as the plan required.

## Correctness checks

- **Sub-typing:** `_router.samples` is `Stream<BioSample>` (broadcast), so `StreamSubscription<BioSample>? _sub = _router.samples.listen(_onSample)` type-checks.
- **`sendBatch` signature:** `BiometricStreamClient.sendBatch(List<BioSample>)` (`BiometricStreamClient.dart:67`) accepts the unmodifiable `snapshot`. The client iterates with `.map(...).toList()`, which works on unmodifiable lists.
- **Size threshold:** `_buffer.add` runs before the `>= _maxBatchSize` check, so flush triggers exactly at 25 — not 26 — matching the spec.
- **Timer policy:** `_flushTimer ??= Timer(...)` fixes the deadline to the first sample of a batch. When the timer fires, `_flushNow` runs `_flushTimer = null` so the next sample re-arms a fresh timer. Cycle is leak-free.
- **Empty-buffer guard:** `_flushNow` early-returns when `_buffer.isEmpty`, covering both the dispose-with-empty-buffer case and an edge race where the timer fires immediately after a size-triggered flush (timer would normally have been cancelled but cancellation is non-reentrant-safe at the source). Idempotent.
- **Dispose ordering:** cancel subscription → null it → cancel timer → null it → flush remainder. This is the correct order: stopping new samples before the final flush prevents a late `_onSample` from re-arming a timer after teardown, and the empty-buffer guard makes double-dispose a no-op.
- **Single-threaded Dart:** no concurrency hazards. `_flushNow` is reentrant-safe because the buffer is cleared before `sendBatch`, and `sendBatch` is synchronous-returning (per the existing client).

## Rules compliance

- **RULES.md #3** (constructor injection, class manages its own subscription) — honored. `_sub = _router.samples.listen(_onSample)` is set up inside the constructor body; no external wiring required.
- **RULES.md #2** (no module-specific state in `App.dart`) — N/A here; the batcher is infrastructure. Milestone 9 will wire it in `App.initialize()`.
- **RULES.md #1** (stateless module services) — N/A; the batcher is not a module Service.

## Register-before-subscribe invariant

The batcher subscribes immediately in the constructor. Per the documented `BioStreamRouter.samples` contract, all sources must be registered before the first subscriber reads `samples`. Milestone 9 places `BioStreamRouter` source registrations before the `BiometricBatcher` constructor call in `App.initialize()`, which honors this invariant. The plan calls this out explicitly and the implementation matches.

## Runtime risks considered

- **Stream errors from `_router.samples`:** `listen(_onSample)` has no `onError` handler. Underlying capability sources errors would propagate to the Zone error handler. The spec/Milestone 8 does not require error handling here, and the upstream sources do not currently emit errors. Acceptable for this milestone; would be a follow-up if `cardioStream`/`rrStream`/etc. start surfacing errors.
- **Sample arrival between `dispose()`'s `_sub.cancel()` await and `_flushNow()`:** subscription cancellation is in-flight; the underlying broadcast stream may still deliver one queued event before the cancel completes. The `await` on `_sub?.cancel()` ensures the cancel future completes before `_flushNow` runs, so any in-flight events have either been delivered (and are now in `_buffer`) or are dropped. Final `_flushNow` ships whatever is in the buffer — best-effort, as documented.
- **Timer firing after `dispose`:** the dispose cancels the timer before the final flush; even if the timer somehow fires (it cannot in single-threaded Dart between `_flushTimer?.cancel()` and the next event loop turn), `_flushNow` re-runs on an empty buffer and no-ops.
- **`List<BioSample>.unmodifiable` overhead:** allocates a defensive copy on every flush. Negligible at ≤25 samples per flush; matches the spec verbatim.

## Minor observations (non-blocking)

- `_router` is stored as a field but used only in the constructor. Harmless and consistent with the rest of the file style; no need to elide.
- `_sub = null` after `await _sub?.cancel()` in `dispose()` is a defensive idempotency hook that wasn't strictly required by the spec; it makes double-dispose safe and costs nothing.

## Positive notes

- Verbatim faithful to Milestone 8 spec.
- Style matches the two sibling files in `lib/Biometrics/` (dartdoc, section separators, import grouping).
- Dispose ordering is correct and idempotent.
- No type, signature, or import mismatches against the actual existing classes.
- No unused imports; no dead code; no leaked side-effects.

REVIEW_PASS
