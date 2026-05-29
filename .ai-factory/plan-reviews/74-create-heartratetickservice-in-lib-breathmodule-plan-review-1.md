## Plan Review: Create `HeartRateTickService` in `lib/BreathModule/`

**Plan:** `.ai-factory/plans/74-create-heartratetickservice-in-lib-breathmodule.md`
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md**: PASS. The plan places the new adapter as a sibling of `ClockTickService.dart` in `lib/BreathModule/`, matching the established "concrete service in `lib/`, interface in `packages/breath_module/`" boundary.
- **RULES.md**: PASS. The "Module Services must be stateless" rule applies to concrete implementations of package `IXxxService` interfaces consumed by ViewModels. `HeartRateTickService` implements `ITickService` (the existing tick-source adapter contract) — the precedent (`ClockTickService`) already owns a `StreamController`, `Timer`, and `dispose()`. The other rules (no module state in `App.dart`, constructor injection) are honored: `activeRrSource` is injected via constructor, no `App.dart` edits.
- **ROADMAP.md**: PASS. Plan corresponds 1-to-1 to the unchecked Phase 22 item on line 167 ("Create `HeartRateTickService` in `lib/BreathModule/`"). Scope discipline note correctly defers `BreathModule.buildSession()` wiring to M5.

### Spec Conformance

Cross-checked against `.ai-factory/notes/29-heart-rate-tick-source.md` "Milestone 3". The plan reproduces the spec verbatim in structure: same constructor signature, same subscription wiring, same `TickSource.heartbeat`, same proxy getters, same dispose semantics with the matching "do not dispose `_activeRrSource`" guard rail. No deviations.

### Codebase Verification

- `lib/BreathModule/ClockTickService.dart` exists and uses the exact import pattern the plan asks `HeartRateTickService` to mirror (`package:breath_module/breath_module.dart` show-clause). ✓
- `packages/breath_module/lib/src/ITickService.dart` declares `Stream<TickData> get tickStream`, `TickSource get source`, `void dispose()` — Task 2's override list is complete and signatures match (note `dispose()` is `void`, not `Future`, even though Task 4's body invokes `_tickController.close()` which returns a `Future` — fire-and-forget is consistent with `ClockTickService` precedent). ✓
- `lib/Biometrics/ActiveRrSource.dart` exposes the exact public surface the plan relies on: `Stream<RrInterval> get stream`, `bool get hasActiveSource`, `Stream<bool> get hasActiveSourceStream`. ✓
- `package:mind/...` absolute imports are the established convention in `lib/Core/App.dart` and elsewhere, validating the Task 1 import guidance. ✓
- `ActiveRrSource` is constructed in `App.initialize()` per Phase 22 M2 (line 165 of ROADMAP, already `[x]`), so the dependency that the constructor will eventually receive in M5 already exists. ✓

### Critical Issues

None.

### Minor Observations (non-blocking)

- The plan never names `dart:async` explicitly, but the snippets clearly require it (`StreamController`, `StreamSubscription`). Implementer will add it — same import is present in `ClockTickService.dart`. Worth keeping in mind but not worth blocking on.
- `ActiveRrSource.dispose()` returns `Future<void>`, while `ITickService.dispose()` is `void`. The plan correctly notes the adapter must NOT call `_activeRrSource.dispose()`, so the signature mismatch is moot here.
- No tests are requested per project policy; consistent with "Testing: no" header.

### Positive Notes

- Clean scope: single file, no wiring, no UI, no tests — exactly what M3 should be.
- Explicit rationale for not disposing `_activeRrSource` prevents a foot-gun.
- Proxy getters are correctly described as pure delegations (no caching) — matches the "one source of truth" principle.
- Forward-compatible with M4: the `hasActiveSourceStream` getter is exactly what `SwitchableTickService` will subscribe to.

PLAN_REVIEW_PASS
