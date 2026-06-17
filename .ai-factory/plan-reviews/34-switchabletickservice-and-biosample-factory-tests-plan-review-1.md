## Plan Review: SwitchableTickService and BioSample factory tests

**Plan:** `34-switchabletickservice-and-biosample-factory-tests.md`
**Files Reviewed:** 8 (plan + 7 source/model files)
**Risk Level:** 🟢 Low

### Verification Against Codebase

Every factual claim in the plan was checked against the actual source. All correct:

- **Constructor signature** — `SwitchableTickService({required ClockTickService clock, required HeartRateTickService heart})` demands the *concrete* types, exactly as the plan's "critical" note states. A fake `implements ITickService` would indeed fail to type-check. The recommendation to `implements ClockTickService` / `implements HeartRateTickService` is correct (Dart implicit-interface; private members like `_tickController`/`_timer` are not part of the cross-library interface, so fakes need only the public surface). ✓
- **ClockTickService public surface** — `tickStream`, `source => TickSource.timer`, `simulateTick()`, `sourceChanges => const Stream.empty()`, `trySwitchTo => false`, `dispose()`. Plan's stub list matches exactly, including the non-`ITickService` method `simulateTick()`. ✓
- **HeartRateTickService public surface** — `tickStream`, `source => TickSource.heartbeat`, `hasActiveSource`, `hasActiveSourceStream`, `sourceChanges`, `trySwitchTo`, `dispose()`. Plan lists all of them. The fake does not need an `ActiveRrSource` (implementing a class does not invoke its constructor). ✓
- **Active-source/auto-fallback logic** — constructor subscribes clock as initial active source and listens to `_heart.hasActiveSourceStream`; fallback fires only when `!hasActive && _activeSource == TickSource.heartbeat`. The Phase-4 test cases (including the timer-active guard case) map precisely onto `_switchInternal` and the guard. ✓
- **`trySwitchTo` semantics** — early `return true` with no `sourceChanges` emission when `target == _activeSource`; `return false` when target is heartbeat and `!hasActiveSource`. Phase-3 cases match the implementation line-for-line. ✓
- **dispose propagation** — cancels both subs, closes both controllers, calls `dispose()` on both delegates. Phase-5 cases match. ✓
- **BioSample factories** — all five encoders confirmed: `fromCardio` (hrv sub-map gated on `cardio.hrv != null`, six indices `rmssd/sdnn/pnn50/lf/hf/lfhf`), `fromRr` (`isArtifact` forwarded, no filtering), `fromNfb`/`fromEmotions` (source hard-coded `'neiry'`), `fromMotion` (source via `.name`). Field names in `data` maps (`ax/ay/az`, `gx/gy/gz`, etc.) verified. ✓
- **Domain model shapes** — `SensorSource { neiry, garmin, polar, appleHealth }`; `MotionData.accelerometer`/`gyroscope` are `({double x, double y, double z})` records; all `CardioHrvIndices`, `BciNfbData`, `BciEmotionsData` fields nullable; timestamps are `DateTime`. All match the plan's Implementation Notes. ✓
- **File paths** — SUT imports (`package:mind/BreathModule/SwitchableTickService.dart`, `package:mind/Biometrics/BioSample.dart`) exist. Target test paths are valid: `test/BreathModule/` exists; `test/Biometrics/` does not yet but is a correct new-file location. ✓
- **Test conventions** — existing tests (`breath_session_notifier_test.dart`) use `package:flutter_test/flutter_test.dart` and the same `implements`-based fake pattern, confirming the plan's approach is idiomatic for this repo. ✓

### Context Gates

- **Architecture (ARCHITECTURE.md present):** No boundary issues — these are pure unit tests of existing units, no new dependencies or layer crossings introduced. WARN: none.
- **Rules (RULES.md present):** No conflicts observed with the test approach.
- **Roadmap (ROADMAP_TESTS.md present):** Both units are tracked in the test roadmap; this plan advances it. Linkage present. WARN: none.

### Critical Issues

None. The plan is implementable as written.

### Minor Notes (non-blocking)

- **Phase 5, "stop reacting to hasActiveSourceStream after dispose":** After `dispose()`, `_sourceChangesController` is closed, so any attempt by the listener to add to it would throw — but `_healthSub` is cancelled first, so the listener never fires. The test should subscribe to `sourceChanges` *before* dispose (it will receive `done`) and assert no further `TickSource` event arrives after pushing to the fake's `hasActiveSourceStream`. The plan's intent is correct; just ensure the assertion is framed around "no emission / no throw" rather than expecting a live stream post-dispose.
- **Broadcast-stream timing:** The plan already calls this out (subscribe-before-push, `addTearDown` cleanup). Worth keeping strict — both `tickStream` and `sourceChanges` are broadcast and will silently drop events emitted before subscription.

### Positive Notes

- The "fake typing constraint (critical)" section preempts the single most likely implementation mistake (fakes against `ITickService`) — excellent, accurate foresight.
- Test-case naming is behavior-driven and specific (e.g. distinguishing per-sample SDK timestamp from wall-clock), which will catch the exact regressions the source comments warn about (`DateTime.now()` collapse for motion batches).
- Correctly identifies that both units are testable with no infra refactor, and that BioSample factories need no fakes at all.

PLAN_REVIEW_PASS
