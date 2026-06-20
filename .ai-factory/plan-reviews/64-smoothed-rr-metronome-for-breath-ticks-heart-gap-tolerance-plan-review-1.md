# Plan Review: Smoothed-RR metronome for breath ticks (heart gap tolerance)

**Plan:** `.ai-factory/plans/64-smoothed-rr-metronome-for-breath-ticks-heart-gap-tolerance.md`
**Files Reviewed:** 8 (plan, spec note 130, `HeartRateTickService`, `ActiveRrSource`, `SwitchableTickService`, `ClockTickService`, `BreathModule`, `switchable_tick_service_test.dart`, `App.dart`, `RrInterval`)
**Risk Level:** 🟡 Medium

The plan is well-researched and faithful to spec note 130. The ownership split (reusable `SmoothedRrSource` metric vs. breath-specific metronome/grace in `HeartRateTickService`), the "mirror `ClockTickService`" constraint, and the "real beats never emit ticks" double-count fix are all sound and correctly map to the existing code. File paths, the `ITickService` contract, `TickData(int)`, and the `App` wiring of `activeRrSource` all check out. However there is one **internal contradiction in the plan's own hard constraints** that will break a build, and one runtime edge case that should be designed for before implementing.

---

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — WARN: no `SmoothedRrSource`/`ActiveRrSource`/Biometrics entries found; nothing to violate. Placing `SmoothedRrSource` in `lib/Biometrics/` alongside `ActiveRrSource` is consistent with the existing layering.
- **Rules (`.ai-factory/RULES.md`)** — PASS with note. The rule *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only"* applies. `SmoothedRrSource` is a **general biometric metric** (mirrors `ActiveRrSource`, which already lives in `App`), not breath-module-specific state, so adding it to `App` is compliant. The rule *"All dependencies must be injected via constructor"* is honored (`SmoothedRrSource(ActiveRrSource)`, `HeartRateTickService({required SmoothedRrSource})`). Keep the framing as "biometric infrastructure," not "breath wiring," to stay on the right side of this rule.
- **Roadmap (`.ai-factory/ROADMAP.md`)** — WARN: this is `feat`/`fix`-class work but no matching milestone exists (latest is Phase 44). Add a roadmap entry/phase for this change so it has a linkage and a spec reference, consistent with how prior phases cite their `notes/` spec.

---

### Critical Issues

**1. The plan's own hard constraint "`switchable_tick_service_test.dart` must stay green untouched" is unsatisfiable as designed — a public `start()` method breaks that test's compile.**

`test/BreathModule/switchable_tick_service_test.dart` declares `class _FakeHeartRateTickService implements HeartRateTickService` (line 50). Because it `implements` the **concrete** class, Dart requires the fake to provide every public instance member of `HeartRateTickService`. Today the fake covers exactly the current surface (`tickStream`, `source`, `nominalIntervalMs`, `hasActiveSource`, `hasActiveSourceStream`, `sourceChanges`, `trySwitchTo`, `dispose`).

Task 3 adds a **new public method `start()`** ("a self-rescheduling timer started by a `start()` method") and Task 4 calls `..start()`. Adding `start()` to `HeartRateTickService` adds it to the implicit interface, so `_FakeHeartRateTickService` will no longer satisfy the interface → **the test file fails to compile → the test goes red.** This directly contradicts the constraint in the plan ("Hard constraints") and in the spec ("the existing test stays green untouched").

Note the precedent inside the same test: `ClockTickService` exposes the non-interface method `simulateTick()`, and `_FakeClockTickService` is forced to declare `@override void simulateTick() {}` (line 41). The heart fake will need the identical treatment for `start()`.

This is a genuine fork the implementer will hit. Resolve it explicitly in the plan, choosing one:
- **(a)** Accept a one-line edit to the test — add `@override void start() {}` to `_FakeHeartRateTickService` — and reword the constraint from *"green untouched"* to *"stays green (one no-op override added, mirroring `simulateTick`)"*. This is the lowest-risk option and matches the existing `simulateTick` precedent.
- **(b)** Start the metronome inside the constructor instead of a public `start()`, so no new public member is added and the test is truly untouched. This trades away the literal `..start()` symmetry with `ClockTickService` (the spec's "Decisions — do not re-open" prefers `..start()`), so it conflicts with a settled decision; (a) is the cleaner reconciliation.

Either way, the plan as written cannot deliver both "add `start()`" **and** "test untouched."

---

### Issues / Risks

**2. `BehaviorSubject.smoothedIntervalStream` replays its last value to each new subscriber — `HeartRateTickService` treating that replay as "a real beat arrived" can falsely activate heart for a full grace window.**

The plan specifies `smoothedIntervalStream` as a `BehaviorSubject<int>` and tells `HeartRateTickService` to, "on each emission (a real beat arrived) update `_currentPeriodMs`, set `_effectiveActive` true, and reset the grace timer." But a `BehaviorSubject` **synchronously replays its latest buffered value to every new listener**. Because `SmoothedRrSource` is an always-on App singleton, by the time a breath session subscribes the subject may already hold a *stale* value from an earlier-but-now-disconnected sensor.

Failure sequence: sensor connects → SMA warms → sensor disconnects → `ActiveRrSource.hasActiveSource` flips false (but `SmoothedRrSource` keeps its last SMA and the subject keeps its last item). User opens a breath session. `_effectiveActive` is correctly seeded `false` from `hasActiveSource`, but the constructor's subscription **immediately receives the replayed stale SMA**, runs the handler, sets `_effectiveActive` true, and arms a 10 s grace — with **no live sensor**. `trySwitchTo(heartbeat)` now succeeds against a phantom source, and the dot is driven by the metronome for up to 10 s before grace fires. This defeats the "matches today's behavior — feature isn't claimed without a source" guarantee in Task 3 / spec.

Fix to bake into the plan: in `HeartRateTickService`, ignore the initial replayed value (e.g. `.skip(1)`, or a "first emission is the replay, not a beat" flag), and rely solely on the constructor seed (`smoothedRrSource.hasActiveSource`) for the initial activation state. Real subsequent beats then drive activation as intended. (Alternatively, define `smoothedIntervalStream` as a non-replaying broadcast stream and keep `smoothedIntervalMs` as the pull-based current value — but then re-confirm nothing else wants the replay.)

**3. Metronome must use a self-rescheduling one-shot timer, not `Timer.periodic` — otherwise period changes won't take effect.**

The plan calls the metronome factory a "periodic/self-reschedule factory" (slightly ambiguous), then correctly describes the behavior: "on fire → add tick → reschedule at `_currentPeriodMs`." A fixed `Timer.periodic` cannot change its interval, so it would freeze the cadence at the first period and ignore later smoothed updates. Make the plan unambiguous: the metronome is a **one-shot timer that reschedules itself at the current `_currentPeriodMs` after each fire** (the grace timer is also one-shot). Only `dispose()` cancels it.

**4. Redundant artifact logging under a "minimal logging" setting.**

`ActiveRrSource._onInterval` already `logPrint`s every artifact (line 74). Task 1 also logs each skipped artifact in `SmoothedRrSource`. With `Logging: minimal`, that double-logs the same event per beat. Consider dropping the artifact log in `SmoothedRrSource` (it is a silent filter) or gating it, to honor the minimal-logging setting.

---

### Minor Notes

- **`nominalIntervalMs => 1000` retained** — correct and consistent with today; `SwitchableTickService.nominalIntervalMs` reads it only while heartbeat is active. Not a bug, just confirming the deliberate choice (the real cadence comes from `TickData(_currentPeriodMs)`, not `nominalIntervalMs`).
- **Broadcast `_tickController`** — keep it broadcast (as today). Ticks emitted before `SwitchableTickService` subscribes on switch-to-heartbeat are dropped, which matches `ClockTickService`'s free-running behavior. Good.
- **`dispose()` ownership** — plan correctly states neither `SmoothedRrSource` nor `HeartRateTickService` disposes `ActiveRrSource`/`SmoothedRrSource` (App-owned). Matches `App` having no teardown for `activeRrSource`. ✓
- **Grace armed at construction, metronome started at `start()`** — fine; grace is independent of the metronome. Just ensure the injected grace one-shot factory is available at construction time (it is, via constructor params).

---

### Positive Notes

- Excellent fidelity to the spec's settled decisions (SMA window 7, 10 s grace, no prime tick, no pause logic, never stop on grace) and accurate reading of *why* `ClockTickService` needs no pause logic (`BreathSessionStateMachine._onTick` gates ticks).
- Correctly identifies that `SwitchableTickService` needs **no** change because the metronome/grace logic sits above `hasActiveSourceStream`, preserving the single `sourceChanges` channel — verified against the actual `SwitchableTickService` source.
- The double-count root-cause analysis (beats adjust period, never emit ticks) is correct and is the right architectural fix.
- Commit plan is sensibly staged (metric+wiring, then rewrite, then docs) and each commit is independently coherent.
- Doc tasks correctly follow the repo's "describe behavior, not code" convention.

---

**Verdict:** Address Critical Issue #1 (the `start()` vs. untouched-test contradiction) and design in the fix for Issue #2 (BehaviorSubject replay) before implementing; tighten Issue #3's wording. The remaining items are minor. The plan is close and the architecture is right — it should not pass as-is because Issue #1 guarantees a red build under the plan's own constraints.
