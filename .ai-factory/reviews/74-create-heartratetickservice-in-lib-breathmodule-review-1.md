## Code Review: Create `HeartRateTickService` in `lib/BreathModule/`

**Plan:** `.ai-factory/plans/74-create-heartratetickservice-in-lib-breathmodule.md`
**New file under review:** `lib/BreathModule/HeartRateTickService.dart`

### Scope of Changes

`git status` shows three staged additions:
- `.ai-factory/plan-reviews/74-…-plan-review-1.md` — review artifact, not code.
- `.ai-factory/plans/74-…-create-heartratetickservice-in-lib-breathmodule.md` — plan artifact, not code.
- `lib/BreathModule/HeartRateTickService.dart` — the only production-code change.

No edits to `App.dart`, `BreathModule.buildSession()`, `BreathViewModel`, ARB files, or any UI — consistent with the plan's "scope discipline" note (M5–M7 land in later milestones).

### Verification Against Surrounding Code

- **`ITickService` contract** (`packages/breath_module/lib/src/ITickService.dart`): requires `Stream<TickData> get tickStream`, `TickSource get source`, `void dispose()`. All three are implemented with matching signatures. ✓
- **`TickData`**: single positional `int intervalMs`. `TickData(rr.intervalMs)` passes `int` from `RrInterval.intervalMs` — type match. ✓
- **`TickSource`**: enum with `heartbeat`, `timer`. `TickSource.heartbeat` is correct. ✓
- **`ActiveRrSource`** (`lib/Biometrics/ActiveRrSource.dart`): exposes `Stream<RrInterval> get stream` (broadcast), `bool get hasActiveSource`, `Stream<bool> get hasActiveSourceStream` (BehaviorSubject — late subscribers get the current value). All three proxies bind to the correct names. ✓
- **`ActiveRrSource` ownership**: constructed in `App.initialize()` (verified in `lib/Core/App.dart:195`, field at line 90). The "do not dispose `_activeRrSource`" guard rail in `dispose()` correctly preserves the App-scoped lifetime. ✓
- **Precedent — `ClockTickService`** mirrors the same `dart:async` + show-clause import pattern, the same fire-and-forget `_tickController.close()` inside a `void` `dispose()`, and the same omission of awaiting the close future. Consistent with established style. ✓
- **`RULES.md`** "Module Services must be stateless" applies to concrete implementations of package `IXxxService` interfaces consumed directly by ViewModels. `ITickService` is an internal tick-source adapter contract; the precedent (`ClockTickService`) already owns a `StreamController` and a `dispose()`. No rule violation. ✓
- **Cross-folder import** uses `package:mind/Biometrics/ActiveRrSource.dart`, matching the convention in `lib/Core/App.dart` and `lib/Bci/NeiryBciProvider.dart`. ✓

### Runtime Correctness

- **Field initialization order:** `_activeRrSource` is set in the initializer list before the constructor body runs; `_tickController` is a field initializer (created before body); `_sub` is assigned in the body after both are ready. Safe. ✓
- **Listener wiring:** `_activeRrSource.stream` is a broadcast `StreamController<RrInterval>`, so the synchronous `listen` in the constructor cannot fail with "Stream has already been listened to" even across multiple `HeartRateTickService` instances. ✓
- **Late subscribers to `tickStream`:** broadcast controller — RR intervals delivered before a subscriber attaches are dropped on the floor. This is the documented contract in the spec ("No backpressure / no buffering — broadcast controller, late ticks drop on the floor"). Acceptable. ✓
- **Late subscribers to `hasActiveSourceStream`:** delegates to `ActiveRrSource`'s `BehaviorSubject<bool>`, so late subscribers receive the current value immediately — required for `SwitchableTickService` (M4) to read the boolean without an explicit `valueOrNull` check. ✓
- **`dispose()` idempotency:** not guarded — calling `dispose()` twice would re-close `_tickController` (`StateError`). The precedent (`ClockTickService.dispose()`) is equally unguarded; both are session-scoped and disposed once by their owner. No risk in current usage; out of scope to harden here.
- **Memory:** `HeartRateTickService` holds a strong ref to `ActiveRrSource` (intended) and a subscription on its stream (cancelled in `dispose`). `ActiveRrSource` does not back-reference the tick service. No cycle. ✓
- **Concurrency:** single-threaded Dart event loop; no shared mutable state beyond the controller. No race conditions. ✓

### Spec Conformance

Cross-checked with `.ai-factory/notes/29-heart-rate-tick-source.md` "Milestone 3". The implemented file matches the spec snippet line-for-line in structure, naming, and comments. No deviations.

### Security / Migration / Type-System Concerns

- No persisted state, no migrations, no network surface, no PII flowing through this file. The `intervalMs` integers are non-sensitive.
- No nullable dereferences without guards.
- No dynamic types or unchecked casts.

### Minor Observations (non-blocking, not recorded as findings)

- `StreamSubscription? _sub;` could be typed `StreamSubscription<RrInterval>?` for explicit clarity. Not a correctness issue — the parameter type on `.listen` already gives the closure its `RrInterval` typing. Matches surrounding-file pragmatism.
- `_tickController.close()` returns `Future<void>` discarded in a synchronous `void dispose()`. Identical to `ClockTickService`; the interface forces this shape.

### Conclusion

The change is a minimal, correct, single-file adapter that faithfully implements Phase 22 Milestone 3 per the spec. Contracts are honored, lifetime ownership is respected, no cross-file edits leak in, no runtime hazards identified.

REVIEW_PASS
