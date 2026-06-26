# Plan: Re-decompose the cadence path into `ITickCadenceSource` + selector (behavior-preserving, RR only)

## Context
Split the entangled smoothing / staleness / metronome concerns in `SmoothedRrSource` + `HeartRateTickService` into a clean `ITickCadenceSource` contract: an `RrTickCadenceSource` that owns RR staleness (smoothing + 10 s grace), a priority `TickCadenceSelector`, and a gutted `HeartRateTickService` that becomes a dumb metronome. With a single RR source wired, runtime behavior is byte-for-byte equivalent to today.

**Byte-for-byte note:** the contract includes a **synchronous** `int? get currentPeriodMs` accessor (resolving plan-review Issue 2) so the metronome can seed `_currentPeriodMs` at construction exactly as today (`HeartRateTickService.dart:46`, `smoothedRrSource.smoothedIntervalMs ?? 1000`). Without it, the warm-path first interval would become 1000 ms instead of the smoothed period, because the `BehaviorSubject` replay arrives one microtask after the synchronous `..start()`.

## Settings
- Testing: yes (existing tick-service tests are re-split across the new seam and kept green; no new coverage beyond the relocated assertions)
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: New cadence contract and sources

- [x] **Task 1: Define the `ITickCadenceSource` contract**
  Files: `lib/BreathModule/TickCadence/ITickCadenceSource.dart`
  Create the new `TickCadence/` directory and declare the abstract interface. Extend the spec note's surface with a synchronous current-period accessor (see Byte-for-byte note / plan-review Issue 2):
  ```dart
  abstract interface class ITickCadenceSource {
    Stream<int> get smoothedPeriodMs;   // MA cadence curve, ms-per-beat
    int? get currentPeriodMs;           // sync snapshot of the latest period; null before any (for sync seeding)
    bool get isUsable;                  // can drive ticks right now
    Stream<bool> get usableChanges;     // transitions of isUsable (seeded BehaviorSubject)
    void dispose();
  }
  ```
  Pure Dart, no Flutter/Riverpod imports. Document that `usableChanges` is a **seeded** `BehaviorSubject` stream (replays its current value to new subscribers) — `SwitchableTickService` (`SwitchableTickService.dart:16`) relies on that seeded-replay behavior, which mirrors today's `_effectiveActive.stream`.

- [x] **Task 2: Implement `RrTickCadenceSource` — single home of RR staleness** (depends on Task 1)
  Files: `lib/BreathModule/TickCadence/RrTickCadenceSource.dart`
  Wrap an injected `SmoothedRrSource` (`lib/Biometrics/SmoothedRrSource.dart`, App-owned singleton — **do not dispose it**). Relocate the **entire** availability/grace machinery from `HeartRateTickService` **verbatim** (semantics unchanged):
  - `smoothedPeriodMs` returns `smoothedRrSource.smoothedIntervalStream` (`SmoothedRrSource.dart:51`).
  - `currentPeriodMs` returns `smoothedRrSource.smoothedIntervalMs` (`SmoothedRrSource.dart:47`) — the synchronous snapshot used by the metronome to seed at construction (preserves today's `:46` warm-path seed).
  - `isUsable` backed by `BehaviorSubject<bool>.seeded(smoothedRrSource.hasActiveSource)` (mirrors `HeartRateTickService.dart:35`); `usableChanges` is that subject's stream; the `isUsable` getter reads its value.
  - Warm/cold replay guard: `final expectReplay = smoothedRrSource.smoothedIntervalMs != null; _droppedReplay = !expectReplay;` (`HeartRateTickService.dart:39,43`) so the first stale `BehaviorSubject` replay is not counted as a genuine beat.
  - Arm the grace at construction if `smoothedRrSource.hasActiveSource` is true (`HeartRateTickService.dart:49-51`).
  - Subscribe to `smoothedIntervalStream` with an `_onSmoothed` handler copying the **activation half** of the original (`HeartRateTickService.dart:133-146`): drop the one replay, then on a genuine emission set `isUsable = true` (add `true` only if not already) and re-arm the grace.
  - Grace expiry → `isUsable = false` via `_onGraceExpired` (`HeartRateTickService.dart:155-156`).
  - **Naming:** today's symbols are the constructor param `graceWindow` and field `_graceWindow` (`HeartRateTickService.dart:31,56`) — there is no `_coastGraceWindow` symbol despite the spec note's wording. Carry the grace duration as a constructor parameter `graceWindow = const Duration(seconds: 10)` and field `_graceWindow`, and inject `Timer Function(Duration, void Function()) timerFactory = Timer.new` for testability (matches today's seams).
  - `dispose()`: cancel the smoothed subscription + grace timer + close the `isUsable` subject. Does **not** dispose `SmoothedRrSource`.

- [x] **Task 3: Implement `TickCadenceSelector` — keep all sources warm, expose first usable by priority** (depends on Task 1)
  Files: `lib/BreathModule/TickCadence/TickCadenceSelector.dart`
  Implements `ITickCadenceSource`. Constructor takes `List<ITickCadenceSource> sources`.
  - Subscribe to every source's `usableChanges` at construction (all warm in parallel).
  - Active source = lowest-index source with `isUsable == true`. Re-pipe the active source's `smoothedPeriodMs` to the selector's own `smoothedPeriodMs` output via a broadcast `StreamController<int>`; cancel/re-subscribe the inner pipe on every re-selection.
  - `currentPeriodMs` delegates to the currently-selected source's `currentPeriodMs`; when no source is usable yet, fall back to `sources.first.currentPeriodMs` (with a single pass-through source this equals `rrCadence.currentPeriodMs`, preserving the construction-time seed).
  - `isUsable` = any source usable. `usableChanges` is a **seeded** `BehaviorSubject<bool>` (seed with the initial any-usable value, add on each re-selection) — mirrors today's `_effectiveActive` so `HeartRateTickService.hasActiveSourceStream` (delegating to it) and `SwitchableTickService.dart:16` keep their seeded-replay contract.
  - Re-select on any child `usableChanges` event. With a single source this is a transparent pass-through → behavior-preserving.
  - `dispose()`: cancel all subscriptions, close own subject/controller, and dispose each child source.

### Phase 2: Gut the metronome and rewire

- [x] **Task 4: Gut `HeartRateTickService` into a dumb metronome** (depends on Task 1)
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Keep the class name and its `ITickService` implementation (`source => TickSource.heartbeat`, `nominalIntervalMs => 1000`, `sourceChanges => const Stream.empty()`, `trySwitchTo => false`).
  - Change the constructor to `HeartRateTickService({required ITickCadenceSource cadence, Timer Function(Duration, void Function()) timerFactory = Timer.new})`, replacing the `smoothedRrSource:`/`graceWindow:` params (`:28-33`).
  - **Seed synchronously at construction:** `_currentPeriodMs = cadence.currentPeriodMs ?? 1000` (preserves today's `:46` behavior byte-for-byte — see Byte-for-byte note). Then subscribe to `cadence.smoothedPeriodMs` to update `_currentPeriodMs` on each emission.
  - **Keep** the free-running self-rescheduling metronome (`_scheduleNext`/`_onMetronomeFire`, `:118-129`), the 250–3000 ms clamp (`_periodFloorMs = 250`/`_periodCeilMs = 3000`, `:115-116`), `start()` (`:96`), and the `tickStream` broadcast controller. Real beats still never emit ticks.
  - `hasActiveSource` / `hasActiveSourceStream` (`:89-90`) now **delegate** to `cadence.isUsable` / `cadence.usableChanges`.
  - **Remove** all grace/availability machinery now owned by the cadence source: `_graceWindow` (`:56`), `_effectiveActive` (`:59`), `_droppedReplay` (`:63`), `_armGrace` (`:150`), `_onGraceExpired` (`:155`), and the activation/replay-guard logic inside `_onSmoothed` (`:133-146`) — replace `_onSmoothed` with a plain period-update handler. No grace timer remains in the metronome.
  - **Disposal (resolves plan-review Issue 1 — BLOCKING):** `dispose()` **does dispose the injected `cadence`** — cancel the metronome timer + cadence subscription, close `tickStream`, then `cadence.dispose()`. This follows the spec note (`01-tick-cadence-source-contract.md:68`) and `RULES.md:9` (the class that received the dependency owns its lifecycle), and yields the concrete chain `SwitchableTickService.dispose() → _heart.dispose() → selector.dispose() → rrCadence.dispose()` (which does **not** dispose `SmoothedRrSource`). Each session builds a fresh selector + RR cadence dedicated to that session's heart, so heart-owns-cadence creates no shared-ownership hazard. **Do not** add a separate teardown hook in `buildSession`.
  - Update the class doc comment to reflect that staleness now lives in the cadence source.

- [x] **Task 5: Rewire session assembly in `BreathModule.dart`** (depends on Tasks 2, 3, 4)
  Files: `lib/BreathModule/BreathModule.dart`
  Replace the two-line wiring at `:32-34` (inside `buildSession`) with:
  ```dart
  final clock = ClockTickService()..simulateTick();
  final rrCadence = RrTickCadenceSource(App.shared.smoothedRrSource);
  final selector = TickCadenceSelector([rrCadence]);
  final heart = HeartRateTickService(cadence: selector)..start();
  final tickService = SwitchableTickService(clock: clock, heart: heart);
  ```
  Add imports for `TickCadence/RrTickCadenceSource.dart` and `TickCadence/TickCadenceSelector.dart`. No teardown changes needed: disposal flows through the existing path `BreathSessionViewModel.dispose() → tickService.dispose() → _heart.dispose() → selector.dispose() → rrCadence.dispose()` (Task 4 owns the cadence disposal). `App.dart:225-226` (`ActiveRrSource`/`SmoothedRrSource` singletons) and `SwitchableTickService` stay untouched.

- [x] **Task 6: Re-split the existing tick-service tests across the new seam** (depends on Tasks 2, 4)
  Files: `test/BreathModule/heart_rate_tick_service_test.dart`, `test/BreathModule/switchable_tick_service_test.dart`, new `test/BreathModule/rr_tick_cadence_source_test.dart`, new `test/BreathModule/Fakes/FakeSmoothedRrSource.dart` (shared helper)

  **Shared fake (resolves plan-review minor item):** the `_FakeSmoothedRrSource` is currently file-private to `heart_rate_tick_service_test.dart:16`. Extract it (and `_rr`/`SensorSource` helpers it needs) into a shared `test/BreathModule/Fakes/FakeSmoothedRrSource.dart` so both `rr_tick_cadence_source_test.dart` and (where still needed) the heart test can import it. Add a small `FakeTickCadenceSource` fake exposing `smoothedPeriodMs` / `currentPeriodMs` / `isUsable` / `usableChanges` for reconstructing the metronome SUT.

  **Disposition of each existing test (resolves plan-review Issues 2 & 3 — moved / split / rewritten / dropped):**

  | Existing test (`heart_rate_tick_service_test.dart`) | Concern | Disposition |
  |---|---|---|
  | `:123` seed hasActiveSource true (warm) | RR | **Move** → RR test, assert `isUsable == true` |
  | `:139` seed hasActiveSource false (cold) | RR | **Move** → RR test, assert `isUsable == false` |
  | `:153` arm grace at construction (warm) | RR | **Move** → RR test |
  | `:172` not arm grace at construction (cold) | RR | **Move** → RR test |
  | `:187` seed metronome period from smoothedIntervalMs (600) | metronome | **Rewrite** in heart test against `FakeTickCadenceSource(currentPeriodMs: 600)`; assert metronome scheduled at 600 ms (validates the new sync seed) |
  | `:207` default metronome period to 1000 when null | metronome | **Rewrite** in heart test against `FakeTickCadenceSource(currentPeriodMs: null)`; assert 1000 ms |
  | `:230`–`:391` metronome lifecycle group (no schedule before start, no prime tick, emit on fire, reschedule, 250 floor, 3000 ceiling, broadcast) | metronome | **Move** → heart test, drive period via `FakeTickCadenceSource` (seed/emit on `smoothedPeriodMs`) |
  | `:399` update period from genuine beat, no tick | metronome | **Rewrite** in heart test: fake cadence emits `smoothedPeriodMs = 600`; assert no tick, then metronome fires at 600 |
  | `:431` drop first replay, treat second genuine | RR (replay) | **Split**: replay-drop semantics → RR test (assert `smoothedPeriodMs`/`isUsable` reflect only the genuine emission). Metronome-applies-new-period aspect already covered by `:399` rewrite |
  | `:463` first emission genuine on cold path | RR + metronome | **Split**: `isUsable == true` on first genuine → RR test; metronome applies cadence-stream period → heart test |
  | `:495` re-arm grace on each genuine beat | RR | **Move** → RR test |
  | `:535` flip hasActiveSource false when grace fires | RR | **Move** → RR test, assert `isUsable == false` + `usableChanges` emits `false` |
  | `:558` metronome keeps running after grace expiry | metronome | **Rewrite** in heart test: metronome fires independent of `usableChanges == false` (it has no grace knowledge now) |
  | `:586` flip back true when beat returns after grace | RR | **Move** → RR test |
  | `:614`–`:651` ITickService interface group | metronome | **Move** → heart test, construct with `FakeTickCadenceSource` |
  | `:658` cancel metronome timer on dispose | metronome | **Move** → heart test |
  | `:678` cancel grace timer on dispose | RR | **Move** → RR test |
  | `:696` stop reacting after dispose | both | **Split**: RR test (RR source stops reacting); heart test (metronome stops reacting to cadence stream) |
  | `:717` close tickStream on dispose | metronome | **Move** → heart test |
  | `:736` close hasActiveSourceStream on dispose | delegation | **Rewrite** in heart test: after `dispose()` (which disposes cadence), `hasActiveSourceStream`/`usableChanges` is done |
  | `:755` not dispose underlying SmoothedRrSource | RR | **Move** → RR test |

  `switchable_tick_service_test.dart` uses an `implements HeartRateTickService` fake whose construction/`dispose()` are unaffected by the constructor change — leave it as-is. Run `/usr/local/bin/flutter analyze` and `/usr/local/bin/flutter test test/BreathModule/` to confirm green.

## Commit Plan
- **Commit 1** (after tasks 1-3): "Add ITickCadenceSource contract, RR cadence source, and selector"
- **Commit 2** (after tasks 4-6): "Reduce HeartRateTickService to a dumb metronome and rewire cadence path"
