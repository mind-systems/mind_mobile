## Code Review Summary

**Files Reviewed:** 1 (plan) — verified against `BioStreamRouter.dart`, `BiometricStreamClient.dart`, `BioSample.dart`, `.ai-factory/notes/28-biometric-stream-pipeline.md` Milestone 8, and `.ai-factory/RULES.md`.
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** No conflict. The plan follows the documented Router → Batcher → Client pipeline. The new file lives in `lib/Biometrics/`, which is the dedicated location for hardware-agnostic biometric streaming components, consistent with the module boundary.
- **Rules (`.ai-factory/RULES.md`):** PASS. Rule #3 (constructor injection, class manages its own subscription) is explicitly honored — `_sub = _router.samples.listen(_onSample)` is set up inside the constructor body, dependencies come in via constructor only. Rule #2 (no module-specific state in `App.dart`) is irrelevant here — the batcher is infrastructure, and wiring is intentionally deferred to Milestone 9.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS — this is Phase 21 Milestone 8 work.

### Critical Issues
None.

### Cross-checks against current code

- **`BioStreamRouter.samples` signature** — returns `Stream<BioSample>` as broadcast; the plan's `StreamSubscription<BioSample>? _sub` matches exactly.
- **`BiometricStreamClient.sendBatch(List<BioSample> samples)`** — exists with this exact signature (`lib/Biometrics/BiometricStreamClient.dart:67`), silently drops on no-session/paused, and the plan's `List<BioSample>.unmodifiable(_buffer)` is assignable to that parameter type.
- **`BiometricStreamClient.dispose()`** — returns `Future<void>`; the plan's mirror (`Future<void> dispose() async`) is correct.
- **Imports** — `BioSample.dart`, `BioStreamRouter.dart`, and `BiometricStreamClient.dart` are siblings in `lib/Biometrics/`; the plan's relative-import choice matches `BioStreamRouter.dart`'s own style. `dart:async` is needed for `Timer` and `StreamSubscription` — correctly listed.
- **Register-before-subscribe invariant** — the plan calls this out explicitly and defers the responsibility to Milestone 9's `App.initialize()`, which matches the router's documented contract.
- **Timer policy** — `_flushTimer ??= Timer(...)` correctly fixes the deadline to the first sample of a batch (matching Milestone 8 spec and avoiding the "delay the last sample past 250 ms" failure mode).
- **`_flushNow` ordering** — snapshot → clear → cancel timer → null out → send. The plan correctly nulls out `_flushTimer` even when the timer itself invokes `_flushNow`, so the next `_onSample` re-arms a fresh timer. Empty-buffer early return covers both the timer-after-cancel race and the dispose-with-empty-buffer case.
- **`dispose` ordering** — cancel subscription first, then timer, then final flush. This is the correct sequence: stopping incoming samples before flushing prevents a late `_onSample` from re-arming a timer after teardown.

### Minor observations (non-blocking)

- The plan keeps `_router` as a stored field even though it is only used in the constructor. This is harmless and consistent with the existing pipeline classes; no need to change.
- `_flushNow` runs `_client.sendBatch(snapshot)` synchronously inside a `Timer` callback. `sendBatch` is fully try/catch-wrapped in the existing implementation, so no uncaught exception can escape into the root zone. The plan is safe as-written.
- The plan asks for a dartdoc comment block referencing Milestone 8 and `// ── Section ──` separators — this exactly mirrors the style of `BiometricStreamClient.dart`. Consistent.

### Positive Notes
- The plan is a near-verbatim faithful implementation of Milestone 8 from note 28, with extra rationale woven in for the subtler points (timer `??=` semantics, dispose ordering, empty-buffer early return as a dual-purpose guard).
- API surface verified against the actual existing classes — no mismatched signatures or hallucinated members.
- Constructor-side subscription with no external wiring honors RULES.md rule #3 cleanly.
- Disposal flow correctly mirrors `BiometricStreamClient.dispose()` shape (`Future<void>`).

PLAN_REVIEW_PASS
