## Plan Review (Round 2): Typed `SessionTerminated(reason)` event

**Plan:** `.ai-factory/plans/24-typed-sessionterminated-reason-event.md`
**Files Reviewed:** 7 (ModuleStateEvent, BiometricStreamClient, KeepAliveCoordinator, BreathModuleStateChannel, MeditationModuleStateChannel, GlobalListeners, App.dart) + ARB + round-1 review
**Risk Level:** 🟢 Low

This revision resolves all three findings from round 1. Every line reference in the plan was re-verified against the current source and is accurate. The dormant-event / compile-ordering strategy is sound and the exhaustiveness analysis is complete.

### Round-1 findings — all addressed

1. **`whereType` compile blocker (was the only real blocker)** — FIXED. Task 6 now specifies core-`Stream` `.where((e) => e is SessionTerminated).map((e) => (e as SessionTerminated).reason)` and explicitly forbids rxdart's `.whereType<T>()`, matching the adjacent `sessionAbandonedStream` precedent at `App.dart:321`. Verified: `App.dart` imports `ModuleStateEvent.dart` (`:52`) but not `package:rxdart`, so the core-only form is correct and will compile.
2. **`GlobalListeners` missing `ModuleStateEvent.dart` import** — FIXED. Task 6 now instructs adding `import 'package:mind/Core/Grpc/ModuleStateEvent.dart';`, correctly noting the file currently imports only material/riverpod/GlobalKeys/mind_l10n/mind_ui.
3. **Bio reset is exhaustiveness-only dead code** — FIXED. Task 2 now carries an explicit Note: `_rootSourced == true` in the shipped config (`App.dart:234` always passes `rootIdChanges`), so `_onLifecycleEvent` returns early at `:97` and the new branch never executes at runtime; the real whole-tree bio reset flows through `_onRootIdChanged(null)`, and the downstream emitter (ROADMAP.md:91) must also clear the registry root. This correctly warns the emitter author.

### Context Gates

- **Architecture** — WARN (informational only). No `.ai-factory/ARCHITECTURE.md` boundary violations: the change is purely additive to the sealed `ModuleStateEvent` hierarchy. `SessionTerminationReason` crosses into `GlobalListeners` only as a mapped enum value, mirroring the existing `sessionAbandonedStream` wiring — no domain model leaks.
- **Rules** — PASS. The `App.dart` edit is global-UI stream wiring inside `MyApp.build`, byte-parallel to the existing `sessionAbandonedStream` line — global infrastructure, not module state added to `initialize()`. `GlobalListeners` receives the stream by constructor injection.
- **Roadmap** — PASS. Maps to the "Connection-lifecycle refactor (FSM + typed termination)" phase; the two remaining impl tasks (ROADMAP.md:91–92) name this dormant type as their substrate, so shipping type + exhaustive consumers ahead of the emitter is correct sequencing.

### Correctness verification against current code

- **Task 1** — `ModuleStateEvent.dart` is a `sealed class` with 6 variants; adding `SessionTerminated` + the enum is correct and makes the two exhaustive switches non-exhaustive until Tasks 2–3, exactly as claimed.
- **Task 2** — `BiometricStreamClient._onLifecycleEvent` switch confirmed at `:98–116` (plan cites `:96–117`); merging `SessionTerminated()` into the existing `ModuleSessionEnded() || ModuleSessionAbandoned()` terminal branch is byte-correct. Guard at `:97` verified.
- **Task 3** — `KeepAliveCoordinator._onEvent` switch confirmed at `:47–60` (plan cites `:46–60`); `ModuleSessionAbandoned()` body is `await _foregroundKeepAlive.stop();` — adding `case SessionTerminated():` with the same body restores exhaustiveness.
- **Task 4** — Breath guard confirmed at `:53` (`if (event is ModuleSessionAbandoned) reset();`); Meditation inline reset confirmed at `:35–41` resetting exactly `_started/_ended/_moduleSessionId/_previousStatus/_clientActivityId`. Both are `is`-checks, not switches, so they don't gate compilation — consistent with the plan.
- **Task 5** — `sessionAbandoned` exists at line 11 in both ARB files as a plain string key with no `@`-metadata block; adding `sessionMovedToAnotherDevice` as a plain key (no placeholders → no metadata needed) is consistent. Regeneration sequenced before Task 6.
- **Task 6** — `GlobalListeners` switch over `SessionTerminationReason` lists all three cases (`movedToAnotherDevice`, `abandoned`, `rootDeath`) → exhaustive. The `abandoned`/`rootDeath` → `_sessionAbandonedMessage()` fallback ("ended unexpectedly") is a sensible reuse. Existing `sessionAbandonedStream` path left untouched, preserving the fix for the prior double-snackbar failure.

### Exhaustiveness cross-check (independent)

Swept all `switch`/`is`-check sites touching `ModuleStateEvent`. Only two exhaustive `switch (event)` statements are over `ModuleStateEvent` — `BiometricStreamClient:98` and `KeepAliveCoordinator:47` — both covered by Tasks 2–3. Other `switch (event)` sites (`McpService`, `BciDeviceManager`, `NeiryBciProvider`, `BciDataService`, `BciPairingService`, `HomeViewModel`, `ProfileViewModel`, `McpViewModel`) switch over unrelated event types. `HomeService:60` and `App.dart:321` use `is`-check filters, not switches. `ModuleStateChannel`'s switches are over `state`/`whichEvent()`/`type`. The compile-ordering claim holds.

### Critical Issues

None.

### Positive Notes

- Cleanly separates reason-agnostic reset (Tasks 2–4) from reason-switched snackbar (Task 6); keeps per-child `ModuleSessionAbandoned` distinct from whole-tree `SessionTerminated`.
- Reset bodies verified byte-identical to the existing terminal branches in every consumer.
- Commit plan matches the compile-ordering constraint (type + all exhaustive consumers in commit 1; copy/snackbar in commit 2).

PLAN_REVIEW_PASS
