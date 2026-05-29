## Code Review Summary

**Files Reviewed:** 1 plan + 7 referenced source files + 5 test fakes + spec note
**Risk Level:** 🟡 Medium

The plan mirrors `.ai-factory/notes/29-heart-rate-tick-source.md` "Milestone 4" almost verbatim, file paths and import styles match the existing siblings (`ClockTickService.dart`, `HeartRateTickService.dart`), and rule compliance is preserved (no `App.dart` mutations, constructor injection, dispose propagation). One real blocker, however: extending `ITickService` with new abstract members will break the build because five existing in-tree fakes implement the interface — none are listed in the plan's scope.

### Context Gates
- **ARCHITECTURE.md:** No violations. Layered architecture preserved; `SwitchableTickService` lives in `lib/BreathModule/` next to the other concrete tick services, with no domain leak into the package.
- **RULES.md:** No violations. Constructor injection only; no App.dart state; module Service rules don't apply (this is a tick-service facade, not a module Service).
- **ROADMAP.md:** Aligned with Phase 22 M4. Plan correctly defers wiring to M5 and VM/UI to M6/M7.
- **skill-context (`.ai-factory/skill-context/aif-review/SKILL.md`):** Not present — skipped (`WARN`, advisory).

### Critical Issues

**1. Extending `ITickService` will break five test files that the plan does not update.**

These fakes implement `ITickService` directly and will fail to compile the moment Task 1 lands:

- `test/BreathModule/Presentation/BreathSession/breath_session_state_machine_test.dart` — `class FakeTickService implements ITickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `class FakeTickService implements ITickService`
- `test/BreathModule/Presentation/BreathSession/breath_session_star_toggle_test.dart` — `class _FakeTickService implements ITickService`
- `test/BreathModule/Presentation/BreathSession/breath_animation_coordinator_restart_test.dart` — `class _FakeTickService implements ITickService`
- `test/BreathModule/Presentation/BreathSession/orb_animation_coordinator_resume_test.dart` — `class _ManualTickService implements ITickService`

The plan's Notes section explicitly bounds the scope to "exactly four files" and the Tasks list never touches `test/`. That is wrong: each of these fakes needs the same two no-op overrides as Tasks 2/3:

```dart
@override
Stream<TickSource> get sourceChanges => const Stream.empty();

@override
bool trySwitchTo(TickSource target) => false;
```

The first commit (Tasks 1–3) is exactly the commit that breaks the build, since the interface change ships in it and the test fakes are not updated. Add an explicit task between Task 3 and Task 4 — e.g. "Task 3b: Update five test fakes in `test/BreathModule/Presentation/BreathSession/*.dart` with the same two no-op overrides" — and include those five files in Commit 1's scope. Otherwise even running `flutter test` after Commit 1 fails.

This isn't a "testing is off" carveout — these fakes are part of the source tree. The plan's "Settings → Testing: no" excuses *not authoring new tests*, not letting existing test files fail to compile.

### Non-blocking observations

- **First-tick claim is conditional.** Task 4 / Notes assert the facade "starts producing ticks immediately on construction (no first-tick lag on switch-back from heart, since `clock.simulateTick()` is already running per Phase 22 M5)." That statement is only true once M5 has run; in this milestone in isolation, no caller invokes `simulateTick()`, so the eager `_clock.tickStream` subscription is just a pipe with no producer. This is fine because M4 doesn't wire the facade anywhere, but it's worth flagging that the claim only holds end-to-end after M5.
- **`_healthSub` initial fire is safe.** `_heart.hasActiveSourceStream` is `BehaviorSubject.stream`, so the subscription installed in the constructor fires immediately with the seeded value (initially `false`). The guard `_activeSource == TickSource.heartbeat` correctly prevents a spurious initial switch since `_activeSource` is set to `TickSource.timer` before the listener attaches. Good — but worth noting the constructor ordering matters: `_activeSource = TickSource.timer;` MUST execute before `_healthSub = _heart.hasActiveSourceStream.listen(...)`, as the plan's snippet correctly shows. Implementer should not reorder.
- **`dispose()` ordering rationale.** Plan correctly cancels `_activeSub` and `_healthSub` before closing controllers, then propagates `dispose()` to children. Worth tightening the comment: closing the heart child triggers `_tickController.close()` on heart, which would push a `done` to any active downstream subscription — having already cancelled `_activeSub` keeps this safe.
- **`StreamController.close()` future drop.** Plan explicitly notes `dispose` is sync per the interface and does not `await`. Consistent with `ClockTickService.dispose()` / `HeartRateTickService.dispose()`.
- **No new public API exported from `breath_module.dart` needed.** `SwitchableTickService` lives in `lib/`, not the package, so no export update required. Plan is correct to not touch it.
- **Order of operations in `_switchInternal`.** `_activeSub?.cancel()` runs before reassigning. Note that `cancel()` returns a `Future` which is intentionally not awaited — any in-flight `TickData` already queued by the previous child cannot land on the closed-over `_tickController.add` callback after cancel(), so the brief asynchronous tail is harmless. Good.
- **Auto-fallback is one-shot per silent transition.** If heartbeat is re-armed manually after a fallback, the user explicitly opts back in. That's documented in the spec and the plan's Notes — confirming the design is intentional, not a gap.

### Positive Notes

- Tight scope and explicit deferral of wiring to M5 / VM to M6 — no scope creep into `BreathModule.buildSession()` or `BreathViewModel`.
- Correct re-use of `ITickService` show clause for `TickSource` — Tasks 2/3 correctly avoid redundant imports.
- Central auto-fallback in `SwitchableTickService` (not duplicated in the VM) — matches spec, gives the VM a single sync point via `sourceChanges`.
- Ownership boundary clearly stated: facade disposes both children; heart's `dispose()` does not touch the shared `ActiveRrSource` owned by `App.shared`. This mirrors the existing contract and avoids double-dispose.
- Commit plan is sensibly split (interface + stubs, then facade), and matches the dependency arrows in the Tasks list.

### Required Plan Updates Before Implementation

1. Add a new task (recommend "Task 3b") before Task 4 that extends the five in-tree test fakes (`FakeTickService` / `_FakeTickService` / `_ManualTickService`) with the same two no-op overrides as Tasks 2/3.
2. Update Commit 1's scope description to include those five test files.
3. Strike or qualify the "this milestone touches exactly four files" claim in the Notes section so it reflects the actual file set (interface + 2 concretes + new facade + 5 test fakes = 9 files).

Once those are added, the plan is ready to execute.
