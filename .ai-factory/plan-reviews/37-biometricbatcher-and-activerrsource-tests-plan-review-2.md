## Plan Review (Round 2): BiometricBatcher and ActiveRrSource tests

**Plan:** `37-biometricbatcher-and-activerrsource-tests.md`
**Files Reviewed:** 1 plan + 8 source/convention files + round-1 review
**Risk Level:** 🟢 Low

This is the second-round review. The plan has been revised to address every finding raised in round 1, and the technical claims now verify cleanly against the source. No blocking issues remain.

### Context Gates
- **Architecture** (`ARCHITECTURE.md`): WARN — none. Test-only change; no module-boundary, DI, or dependency-direction impact.
- **Rules** (`RULES.md`): PASS — all three rules concern Module Services / `App.dart` / constructor injection; none apply to test files.
- **Roadmap** (`ROADMAP_TESTS.md`): PASS — fulfills the `BiometricBatcher and ActiveRrSource tests` milestone. Construction params and coverage areas match the targeted classes.

### Round-1 Findings — Verification

All round-1 items are resolved:

1. **Watchdog delay math (was Critical #1)** — FIXED. The plan now uses `emit 1500 ms → 3000 ms` (multiplier branch, `window > floor`) and `emit 500 ms → 2000 ms` (floor branch). Verified against `_restartWatchdog`: `_silenceFloor = 2000 ms`, `_silenceMultiplier = 2.0`. For 1500 ms, `window = 3000 ms > 2000 ms → effective 3000 ms`; for 500 ms, `window = 1000 ms`, not `> 2000 ms → effective 2000 ms`. Both branches are now genuinely exercised, and the named constants (lines 106–108) match the code exactly.
2. **Size-flush flake with 1 ms interval (was Critical #2)** — FIXED. The plan now splits the construction recipe per task: size/dispose tests use `flushInterval: const Duration(seconds: 10)` (never-firing) on the real event loop; timer tests use `fakeAsync` + `1 ms` with the SUT built inside the zone and `async.flushMicrotasks()`/`async.elapse()` for delivery. This removes the latent CI flake.
3. **Fakes must implement all public interface members** — FIXED. Conventions (line 20) and the per-phase Fakes blocks now spell out that `_FakeBioStreamRouter` must stub all five `register*` methods plus `samples`, and `_FakeBiometricStreamClient` must stub both `sendBatch` and `dispose`. Verified the public surface of both concrete classes matches that list.
4. **`fake_async` transitive-only** — FIXED. Plan now prescribes `flutter pub add --dev fake_async` (honoring the never-hand-edit-`pubspec.yaml` rule). Confirmed it is currently transitive-only in `pubspec.lock`.
5. **Seeded `BehaviorSubject(false)` emission count** — FIXED. Explicit note (line 98) tells the implementer to expect `[false, true]` or `.skip(1)`. Matches `_hasActiveController = BehaviorSubject<bool>.seeded(false)`.
6. **Failover does not re-emit `hasActiveSource`** — FIXED. Task 4 note (line 124) instructs asserting the active-source change + new watchdog only, not a spurious transition. Verified `_onSilence`'s failover branch sets `_activeIndex`/restarts watchdog and returns without touching `_hasActiveController`.
7. **`_FakeTimer.cancel()` semantics** — FIXED. The spy note (line 95) now requires emulating real cancellation (skip firing a cancelled timer's callback), with the correct rationale that firing `_onSilence` against a closed `BehaviorSubject` would throw. Verified against `dispose()` (cancels `_watchdog`, closes both controllers) and `_ensureHasActive` (`.add` on a closed subject throws).

### Critical Issues
None.

### Minor / Completeness
- **Priority-steal setup ordering (Phase 2, Task 2, second case).** "source[1] active first, then source[0] emits" relies on source[1] being the first emitter so `_activeIndex` initializes to 1 (`_activeIndex == null` branch), after which `0 < 1` steals to source[0]. The plan's wording implies this, and the mechanism is correct — just ensure the implementer emits from source[1] *before* source[0]. Non-blocking.
- **Failover freshness window (Phase 2, Task 4, first case).** Because `_lastSeenAt[index]` is recorded at the top of `_onInterval` for *every* source (before the active-only forward guard), a non-active source[1] emission does register its timestamp — so the failover-within-floor path is reachable. The plan's "advance `_now` modestly so source[1] is within the 2 s floor" is sound; the implementer must order emissions/clock advances so source[0]'s watchdog window is exceeded while source[1] stays within `_silenceFloor`. The plan already flags this; just a precision note.
- **`data: const {}` typing.** The sample helper `BioSample(timestampMs: i, sampleType: 'rr', data: const {})` is fine — `const {}` infers to `Map<String, dynamic>` against the constructor's declared parameter type. No action needed.

### Positive Notes
- Every round-1 finding was addressed substantively, not cosmetically — the watchdog cases now exercise both branches, and the construction recipe is correctly split by execution model (real loop vs `fakeAsync`).
- The `fake_async`-vs-`timerFactory` distinction (batcher has no timer seam → needs virtual time; `ActiveRrSource` has a `timerFactory` seam → captured-callback spy, no `fake_async`) is accurate and matches the source.
- Constructor shapes (`RrInterval`, `BioSample`, `SensorSource.neiry`), file paths, and the implicit-interface fake pattern (mirroring `switchable_tick_service_test.dart`) all verified against source — no incorrect API usage.
- Coverage decomposition (size / timer / lifecycle / dispose for the batcher; initial / steal / silence / failover / dispose for the RR source) is thorough and maps cleanly to the methods under test.

The plan is solid and ready for implementation.

PLAN_REVIEW_PASS
