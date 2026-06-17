## Plan Review: BiometricBatcher and ActiveRrSource tests

**Plan:** `37-biometricbatcher-and-activerrsource-tests.md`
**Files Reviewed:** 1 plan + 7 source/convention files
**Risk Level:** 🟡 Medium

The plan is well-scoped, accurately targets the two silently-failing classes named in `ROADMAP_TESTS.md`, correctly identifies the injectable seams (`flushInterval`/`maxBatchSize` on the batcher; `clock`/`timerFactory` on `ActiveRrSource`), and follows the project's testing conventions (hand-written `Fake*` via implicit interface, `StreamController` injection, `Future.delayed(Duration.zero)` for broadcast delivery). The `switchable_tick_service_test.dart` implicit-interface pattern it cites is real and matches. Two findings need fixing before implementation, plus a few completeness notes.

### Context Gates
- **Architecture** (`ARCHITECTURE.md`): WARN — none. Test-only change, no boundary impact.
- **Rules** (`RULES.md`): PASS — rules concern Module Services / App.dart / DI; none apply to test files.
- **Roadmap** (`ROADMAP_TESTS.md`): PASS — directly fulfills the `[ ] BiometricBatcher and ActiveRrSource tests` milestone (line 19), with matching construction params and coverage areas.

### Critical Issues

**1. Wrong expected watchdog delay — the `800 ms → 1600 ms` case contradicts the code (Phase 2, Task 1).**
The plan's case `should schedule a watchdog using max(intervalMs * 2, silenceFloor)` asserts: *"emit 800 ms → captured timer delay is 1600 ms; emit 500 ms → delay is 2000 ms floor."*

`_restartWatchdog()` computes:
```dart
final window = Duration(milliseconds: (base * _silenceMultiplier).round()); // 800*2 = 1600ms
final effective = window > _silenceFloor ? window : _silenceFloor;          // 1600ms > 2000ms? NO → 2000ms
```
`_silenceFloor` is **2000 ms** and `_silenceMultiplier` is **2.0**. For `intervalMs = 800`, `window = 1600 ms`, which is **not** greater than the 2000 ms floor, so `effective = 2000 ms` — **not 1600 ms**. A test asserting 1600 ms will fail against correct code.

Worse, both of the plan's example intervals (800 ms and 500 ms) land on the floor, so the test never actually exercises the `window > floor` (multiplier) branch despite its title. To cover the multiplier path the interval must exceed 1000 ms — e.g. `emit 1500 ms → expect 3000 ms`. Recommended cases:
- `emit 1500 ms → 3000 ms` (multiplier branch, window > floor)
- `emit 500 ms → 2000 ms` (floor branch)

This is the headline correction; the implementer would otherwise either write a failing test or "fix" it to a wrong magic number.

**2. Size-flush tests use `flushInterval: 1 ms` without `fakeAsync` — latent flake (Phase 1, Task 1 & Task 4 partial).**
The plan prescribes one construction recipe (`flushInterval: 1 ms, maxBatchSize: 3`) for all of Phase 1, but only wraps Task 2/3 (and the last Task 4 case) in `fakeAsync`. The size-based and dispose tests run against the real event loop. `_onSample` arms a real `Timer(1 ms, _flushNow)`. A test that emits samples and then `await Future.delayed(Duration.zero)` to let the broadcast listener run can, under load (CI), let ≥1 ms of wall-clock elapse before the assertion — firing the deadline timer and producing an unexpected timer-flush. That breaks `should not flush when buffer has fewer than maxBatchSize` (expects empty `batches`) and `should flush remaining buffered samples on dispose` (could see 2 batches).

Fix: give the **size/dispose** tests a long, never-firing interval (e.g. `flushInterval: const Duration(seconds: 10)`) so only the explicit size/dispose path produces a batch, and reserve the 1 ms interval (or any value, since `fakeAsync` controls virtual time) for the `fakeAsync`-wrapped timer tests. The single-recipe instruction should be split per task.

### Minor / Completeness

- **Fakes must implement *all* public interface members, not just the ones named.** `implements BioStreamRouter` requires stubbing the five `register*` methods (e.g. empty or `UnimplementedError`) in addition to the `samples` getter. `implements BiometricStreamClient` requires `dispose()` as well as `sendBatch()`. The plan only mentions the members it exercises; the implementer should know the implicit interface demands the rest or the file won't compile.
- **`fake_async` is a transitive-only dependency.** The plan correctly notes it is present in `pubspec.lock` (confirmed). Importing a transitive dep works but is fragile — if `flutter_test`/`rxdart` stop pulling it, the tests break with no local declaration. Consider `flutter pub add --dev fake_async` (per project rule: never hand-edit `pubspec.yaml`) to make the dependency explicit. Non-blocking, but flag it.
- **`hasActiveSourceStream` is a seeded `BehaviorSubject(false)`.** Tests that count emissions (`one true`, `one false`) must account for the immediate seeded `false` a late subscriber receives on listen. The plan's wording ("one true", "one false") is fine as long as the implementer skips/expects the initial seeded value — worth an explicit note so the emission counts aren't off by one.
- **Failover does not re-emit `hasActiveSource`.** In `_onSilence`, a successful failover sets `_activeIndex = next` and restarts the watchdog but never touches `_hasActiveController` (it stays `true`). Task 4's `should failover…` correctly asserts active *index* change + new watchdog, not a `hasActiveSource` transition — good. Just confirm the implementer does not assert a spurious `true` emission on failover (there is none).
- **`_FakeTimer` spy ignores `cancel()` accounting for assertions.** The plan's `dispose`/silence cases rely on "invoke captured callback → no emission / no error". Since `_FakeTimer.cancel()` only flips a bool and the SUT still holds the captured `cb`, firing `timers.last.cb()` after dispose executes `_onSilence` against closed controllers. `_ensureHasActive` calls `_hasActiveController.add(false)` on a closed `BehaviorSubject`, which throws. Verify the "cancel the active watchdog on dispose" case either (a) does not fire a watchdog whose `_onSilence` would reach `.add` on a closed controller, or (b) expects/guards that. The real `Timer` would have been cancelled so its callback never runs; the spy must emulate that by **not** invoking `cb` for a cancelled timer (check `_FakeTimer.cancelled` before calling `timers.last.cb()`). This nuance should be called out so the dispose test reflects real cancellation semantics rather than firing a callback a real timer never would.

### Positive Notes
- Correct identification of why `ActiveRrSource` needs no `fake_async` (it has a `timerFactory` seam) while `BiometricBatcher` does (no timer seam) — accurate and matches the source.
- Test naming (`should <behavior> when <condition>`), FIFO-order and `List.unmodifiable` assertions, and buffer-clear-after-flush checks are precise and map cleanly to `_flushNow`/`_onSample`.
- Construction params, file paths (`test/Biometrics/…`), and the `SensorSource.neiry`/`RrInterval`/`BioSample` constructor shapes all verified against source — no incorrect API usage.
- Coverage decomposition (size vs timer vs lifecycle vs dispose for the batcher; initial/steal/silence/failover/dispose for the RR source) is thorough and matches the roadmap's stated scope.

Fix findings 1 and 2 (and ideally the `_FakeTimer.cancel` semantics note) before implementation; the rest are guard-rails for the implementer.
