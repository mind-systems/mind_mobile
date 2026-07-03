## Plan Review: Typed `SessionTerminated(reason)` event

**Plan:** `.ai-factory/plans/24-typed-sessionterminated-reason-event.md`
**Files Reviewed:** 7 (ModuleStateEvent, BiometricStreamClient, KeepAliveCoordinator, BreathModuleStateChannel, MeditationModuleStateChannel, GlobalListeners, App.dart) + ARB/roadmap/spec
**Risk Level:** 🟢 Low

The plan faithfully implements spec note 26 and matches the roadmap contract line (ROADMAP.md:81). Line references were verified against the current code and are accurate (the plan correctly updates the stale `:86-106` reference from the note to the actual `:96-117` switch). Exhaustiveness analysis is complete: the only two exhaustive `switch (ModuleStateEvent)` sites are `BiometricStreamClient._onLifecycleEvent` and `KeepAliveCoordinator._onEvent` — both covered by Tasks 2–3. The adapters use `is`-checks (Tasks 4), not switches, so they don't gate compilation. `ModuleStateChannel`'s switches are over `state`/`whichEvent()`/`type`, not `ModuleStateEvent`, so they're unaffected. The dormant-event / compile-ordering strategy is sound.

### Context Gates

- **Architecture** — PASS. Change is additive to the sealed hierarchy; no boundary/dependency violations. `SessionTerminationReason` is a domain enum crossing into `GlobalListeners`, but only as a mapped enum value (App.dart does `.map((e) => e.reason)`), mirroring the existing `sessionAbandonedStream` wiring.
- **Rules** (`RULES.md`) — PASS. The App.dart edit adds a *global-listener* stream wiring in `MyApp.build`, byte-for-byte parallel to the existing `sessionAbandonedStream` line (App.dart:321) — this is global UI infrastructure, not module-specific state added to `initialize()`, so it does not violate the "no module concerns in App.dart" rule. `GlobalListeners` receives the stream via constructor (injection rule satisfied).
- **Roadmap** — PASS. Task maps to ROADMAP.md:81 under "Phase — Connection-lifecycle refactor (FSM + typed termination)"; governing spec `.ai-factory/notes/26-rootchild-typed-termination-reason.md` is consistent with every task. Both remaining Phase-65 impl tasks (lines 91–92) name note 26 as the substrate they build on — this task correctly ships the dormant type ahead of them.

### Critical Issues

None blocking.

### Issues / Improvements

1. **`whereType` needs an rxdart import in `App.dart` (Task 6).** The plan specifies `App.shared.moduleStateChannel.events.whereType<SessionTerminated>().map((e) => e.reason)`. `events` is a plain `Stream<ModuleStateEvent>` (`PublishSubject.stream`), and `Stream.whereType<T>()` is an **rxdart `StreamExtensions`** method — Dart core `Stream` has no `whereType` (only `Iterable` does). `App.dart` does **not** currently import `package:rxdart/rxdart.dart` (the adjacent `sessionAbandonedStream` line deliberately uses core `.where((e) => e is …).map(…)`). As written this won't compile. Fix: either add the rxdart import to `App.dart`, or keep it core-only —
   `events.where((e) => e is SessionTerminated).map((e) => (e as SessionTerminated).reason)`.
   Prefer the latter to match the existing precedent on the line right above it.

2. **`GlobalListeners` must import `ModuleStateEvent.dart` (Task 6).** The new `final Stream<SessionTerminationReason> sessionTerminatedStream` field references a type that lives in `lib/Core/Grpc/ModuleStateEvent.dart`; `GlobalListeners` currently imports only material/riverpod/GlobalKeys/mind_l10n/mind_ui. The plan doesn't mention the import. Trivial, but call it out so the implementer adds it.

3. **Task 2's bio reset is exhaustiveness-only dead code in production — flag for the downstream emitter.** In `App.dart:234`, `BiometricStreamClient` is always constructed **with** `rootIdChanges`, so `_rootSourced == true` and `_onLifecycleEvent` returns early at `:97` before any `case` runs. Adding `case … || SessionTerminated():` is correct and required for exhaustiveness, but that branch will **never execute at runtime** in the shipped configuration — the real bio reset on termination flows through `_onRootIdChanged(null)` when the registry clears the root. This is fine for this dormant task (compile-ordering only), and the plan already says "leave the `if (_rootSourced) return;` guard as-is." Recommend adding one sentence to Task 2 (or the note) making explicit that bio's actual whole-tree reset depends on the future reconnect impl also clearing the registry so `rootIdChanges` emits `null` — otherwise the emitter author (ROADMAP.md:91) may wrongly assume emitting `SessionTerminated` alone resets bio.

### Positive Notes

- Correctly keeps `ModuleSessionAbandoned` (per-child abandon) distinct from the whole-tree `SessionTerminated`, and leaves the existing `sessionAbandonedStream` snackbar path untouched — this is exactly what defeated the previous double-snackbar failure.
- Reset bodies in Tasks 2–4 are verified byte-identical to the existing terminal branches (bio: `_currentSessionId/_sessionConfirmed/_lastOpenAttempt/_replayRing.clear`; meditation: the 5 re-arm fields; breath: `reset()`).
- Reason-agnostic reset vs reason-switched snackbar split is clean; the ARB key + fallback mirror `_sessionAbandonedMessage()` precisely, and Task 5 correctly sequences l10n regeneration before Task 6 references the getter.
- Commit plan matches the compile-ordering constraint (type + all exhaustive consumers in commit 1; snackbar/copy in commit 2).

The plan is solid; the findings above are minor and mechanical. Fix finding #1 (compile blocker) and fold #2–#3 into the task text before handing to the orchestrator.
