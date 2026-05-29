## Code Review Summary

**Files Reviewed:** 9 files of code changes (`packages/breath_module/lib/src/ITickService.dart`, `lib/BreathModule/ClockTickService.dart`, `lib/BreathModule/HeartRateTickService.dart`, `lib/BreathModule/SwitchableTickService.dart`, 5 test files) + plan + spec note + 2 plan reviews
**Risk Level:** 🟢 Low

The implementation matches the plan and the spec (`.ai-factory/notes/29-heart-rate-tick-source.md` Milestone 4) line-for-line. `flutter analyze` returns no issues on both `lib/BreathModule/` and the touched test directory. `flutter test test/BreathModule/Presentation/BreathSession` passes (51/51) confirming the interface extension + test-fake updates ship atomically without breaking the existing suite.

### Context Gates

- **ARCHITECTURE.md:** No violations. `SwitchableTickService` lives in `lib/BreathModule/` next to the other concrete tick services; no domain leak into the package; the new interface members are added to the package-level `ITickService` where they belong.
- **RULES.md:** No violations. Constructor injection only (`clock`, `heart`); no `App.dart` mutations (concrete construction will land in M5 in `BreathModule.buildSession()`); the Module Service rules don't apply here (this is a tick-service facade, not a module Service).
- **ROADMAP.md:** Aligned with Phase 22 M4. Deferred wiring to M5 and VM/UI to M6/M7 as planned.

### Critical Issues

None.

### Correctness Analysis

I walked through the runtime semantics scenario-by-scenario.

**Constructor ordering (`SwitchableTickService.dart:13-21`).** `_activeSource = TickSource.timer` runs before `_heart.hasActiveSourceStream.listen(...)`. `hasActiveSourceStream` is the `BehaviorSubject.stream` from `ActiveRrSource` (seeded `false`). When the listener registers, it asynchronously receives the seeded value — by that point `_activeSource == TickSource.timer`, so the `_activeSource == TickSource.heartbeat` guard suppresses any spurious initial fallback. Correct.

**Auto-fallback path (`SwitchableTickService.dart:16-20`).** Only `(hasActive == false && _activeSource == heartbeat)` triggers `_switchInternal(TickSource.timer)`. No fallback firing on `true` events, no fallback firing when already on timer. One-shot per silence transition; re-arming heartbeat requires an explicit user tap. Matches spec.

**`trySwitchTo` rejection rule (`SwitchableTickService.dart:45-52`).** Returns `true` when already on target (no-op), returns `false` only when `target == heartbeat && !_heart.hasActiveSource`. Switching to `timer` always succeeds. Matches spec.

**`_switchInternal` cancellation/re-subscription (`SwitchableTickService.dart:54-60`).** `_activeSub?.cancel()` ignores its returned future; this is safe because `StreamSubscription.cancel()` stops further event delivery to the listener synchronously (any in-flight `add` already dispatched would have invoked the listener before `cancel` returns; subsequent events from the cancelled source never reach `_tickController.add`). `_activeSource` is updated before the new subscription is attached, so a re-entrant call from the new source's first event (broadcast streams don't replay, so this is theoretical anyway) would see consistent state. `_sourceChangesController.add(target)` fires *after* the new subscription is wired, so any downstream consumer reading `source` upon receiving the change event sees the new value.

**Dispose ordering (`SwitchableTickService.dart:63-70`).** `_activeSub.cancel()` and `_healthSub.cancel()` run first → no further events reach `_tickController` / no further fallback callbacks fire. `_tickController.close()` + `_sourceChangesController.close()` then close the facade's outbound streams (downstream listeners receive `done`). `_clock.dispose()` and `_heart.dispose()` propagate teardown into the children, which each cancel their own upstream subscription (clock's `Timer.periodic`, heart's `ActiveRrSource.stream` subscription) and close their own controllers. `_heart.dispose()` correctly does NOT touch `_activeRrSource` (`HeartRateTickService.dart:41` comment) — that one is owned by `App.shared`. No double-close, no use-after-close.

**`Stream.empty()` in `ClockTickService` / `HeartRateTickService` (`ClockTickService.dart:22`, `HeartRateTickService.dart:32`).** `const Stream.empty()` produces a stream that emits no events and completes immediately on subscription. The facade never subscribes to `_clock.sourceChanges` or `_heart.sourceChanges` (it owns its own `_sourceChangesController`), so this is purely for interface compliance. Downstream consumers that hold a non-facade `ITickService` (e.g. test fakes) and subscribe to `sourceChanges` will receive a `done` immediately — harmless and matches the documented contract ("never switches").

**Test-fake parity.** All five fakes (`breath_animation_coordinator_restart_test.dart:30-34`, `breath_session_enriched_state_test.dart:28-32`, `breath_session_star_toggle_test.dart:20-24`, `breath_session_state_machine_test.dart:19-23`, `orb_animation_coordinator_resume_test.dart:20-24`) carry the same two no-op overrides. Each file already imports `TickSource` via the existing `show` clause from `package:breath_module/breath_module.dart`, so no import edits are needed. `flutter test` confirms all 51 tests compile and pass.

### Non-blocking observations

- **`Stream<bool>` type-narrowing on `_healthSub`.** Declared as `StreamSubscription<bool>?`, the listener parameter `hasActive` is correctly inferred as `bool`. No nullability concern. Fine.
- **`hasActiveSource` race on `trySwitchTo`.** Reading `_heart.hasActiveSource` then calling `_switchInternal` is two synchronous steps; no async boundary can interleave a `BehaviorSubject` mutation between them. No TOCTOU bug.
- **Late events on cancelled subscriptions.** Already analysed above — `cancel()` blocks further delivery synchronously from the listener's perspective. The Future-not-awaited pattern is consistent with `HeartRateTickService.dispose()` and `ClockTickService.dispose()` in the same module.
- **No tickStream backpressure or replay.** A switch from heart → timer drops any in-flight tick on the floor (broadcast semantics). Matches the spec's "no backpressure / no buffering" stance from Milestone 1.
- **Eager clock subscription is benign in M4-only state.** Without `clock.simulateTick()` being invoked anywhere in this milestone, the eager subscription is just a pipe with no producer — as the plan flags explicitly. M5 will hook `simulateTick()` into `BreathModule.buildSession()`.
- **No new public exports from `breath_module.dart`.** `SwitchableTickService` lives in `lib/`, not the package — correct to leave the package barrel untouched.
- **Defensive default in `_switchInternal`.** `target == TickSource.timer ? _clock : _heart` defaults non-timer values to `_heart`. Today the enum has only two variants; if a third is ever added the conditional would silently pick `_heart`. Not a bug today but worth a future audit if the enum grows.

### Positive Notes

- Tight scope: nine files, no scope creep into `BreathModule.buildSession()`, `BreathViewModel`, `BreathSessionScreen`, `App.dart`, or any l10n / docs — wiring is correctly deferred to M5/M6/M7.
- Test-fake parity shipped in the same change as the interface extension — Commit 1 leaves the build and the test suite green (verified: 51/51 pass).
- Constructor body matches the spec's required ordering, with `_activeSource` set before the health listener attaches.
- Auto-fallback centralised in the facade (not duplicated in the VM); VM (M6) will get a single sync point via `sourceChanges`.
- Ownership boundary preserved: facade disposes its two children; neither child disposes the upstream `ActiveRrSource` owned by `App.shared`.
- Interface dartdoc added to `ITickService` is minimal and accurate (one-liner per member as the plan specified).

REVIEW_PASS
