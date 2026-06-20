# Plan: Smoothed-RR metronome for breath ticks (heart gap tolerance)

## Context
Decouple breath ticks from individual heartbeats: drive the heart tick source as a free-running metronome whose period is a moving average of RR intervals, so a device RR gap no longer stalls the dot or double-counts a late beat, and the feature only drops to the clock after a 10 s grace window with no real beat.

## Settings
- Testing: no (one no-op override added to keep the existing test compiling — see Task 4)
- Logging: minimal
- Docs: yes — written in **Russian** (existing tick-source/RR docs are Russian; match them — see Task 5)

## Review Resolutions

### plan-review-1
- **Critical #1 — `start()` vs. "test untouched" contradiction (resolved, option a):** `test/BreathModule/switchable_tick_service_test.dart` declares `_FakeHeartRateTickService implements HeartRateTickService` (concrete class, line 50), so adding a public `start()` to `HeartRateTickService` forces the fake to implement it or the test fails to compile. The same precedent already exists for `ClockTickService.simulateTick()` (the fake has `@override void simulateTick() {}` at line 41). Resolution: keep the public `start()` (preserves the spec's settled `..start()` symmetry with `ClockTickService`) **and** add a one-line `@override void start() {}` no-op to `_FakeHeartRateTickService`. The constraint is reworded from "green untouched" to "stays green with one no-op override added, mirroring `simulateTick`." See Task 4.
- **Issue #2 — `BehaviorSubject` replay can falsely activate heart (designed in, refined by review-2 Issue A):** `smoothedIntervalStream` is a `BehaviorSubject` and `SmoothedRrSource` is an always-on singleton, so a new subscriber may synchronously receive a stale buffered SMA from a now-disconnected sensor. `HeartRateTickService` must **conditionally** ignore that replay and rely on the constructor seed (`smoothedRrSource.hasActiveSource`) for initial activation. See Task 3.
- **Issue #3 — metronome timer type (clarified):** the metronome is a **one-shot timer that reschedules itself** at the current `_currentPeriodMs` after each fire — NOT `Timer.periodic` (which cannot change interval and would freeze the cadence at the first period). The grace timer is also one-shot. See Task 3.
- **Issue #4 — redundant artifact logging (resolved):** `ActiveRrSource._onInterval` already `logPrint`s every artifact (line 74). `SmoothedRrSource` is a silent filter — it does **not** log skipped artifacts. See Task 1.
- **RULES.md framing:** `SmoothedRrSource` is registered in `App` as **general biometric infrastructure** (mirrors `ActiveRrSource`, lines 98/214/243), not breath-module state — compliant with "App.dart is infrastructure only".

### plan-review-2
- **Issue A — `.skip(1)` drops the first real beat on a cold start (fixed):** a `BehaviorSubject` replays synchronously **only when it `hasValue`**. On the **warm** path (`smoothedIntervalMs != null`) the first delivered event is the replay, so skipping it is correct. On the **cold** path (`smoothedIntervalMs == null`, no RR since launch) there is **no** replay, so an unconditional `.skip(1)` would wrongly drop the first genuine beat — delaying activation to the second beat and contradicting "first real beat activates — matches today's behavior." Fix: make the skip **conditional** on whether a replay is pending at construction. See Task 3.
- **Issue B — grace-arm vs. cold path (folded into Task 3 wording):** with the conditional skip, "every subsequent emission resets the grace timer" must mean "every **non-replay** emission" — so on the cold path the first real beat both sets `_effectiveActive` true and arms/resets grace. See Task 3.
- **Task 6 — roadmap entry already exists:** ROADMAP Phase 45 ("Heart tick source: smoothed-cadence metronome (gap tolerance)") already exists and already references `notes/130-heart-tick-source-gap-tolerance.md`. Task 6 is reframed from "add an entry" to "verify Phase 45 is present/linked and mark it `[x]` on completion" — no duplicate phase. See Task 6.
- **Docs language (Task 5):** the existing tick-source/RR docs are in **Russian**; these updates must be written in Russian (global rule: match the language of neighboring docs, overriding the English-files project rule here).

## Implementation Notes (from spec `.ai-factory/notes/130-heart-tick-source-gap-tolerance.md`)

Hard constraints — treat every one as mandatory:
- **Do NOT touch** `SwitchableTickService`, `ClockTickService`, `ActiveRrSource`, `ITickService`, or `BreathViewModel`. The metronome/grace logic must live above `hasActiveSourceStream` so the existing single `sourceChanges` channel keeps `tickSource` correct.
- `test/BreathModule/switchable_tick_service_test.dart` stays green with **one no-op override added** (`@override void start() {}` on `_FakeHeartRateTickService`), mirroring the existing `simulateTick` no-op. No test logic changes.
- **Real beats must never emit ticks** — they only update the metronome period and reset the grace timer. This is the entire double-count fix; do not "also emit on beat".
- **Mirror `ClockTickService` exactly** (the binding rule): metronome started at construction via `..start()`, no prime/immediate tick, no pause/lifecycle logic, never stopped on grace. Pause is already gated by `BreathSessionStateMachine._onTick`.
- `ActiveRrSource` stays **raw** — never synthesize anything back into its stream, never change its silence window.
- `SmoothedRrSource` is a pure metric — no `ITickService`, no breath imports, no grace logic.
- Neither new component disposes `ActiveRrSource` (owned by `App`, never disposed — App is a process-lifetime singleton).

## Tasks

### Phase 1: Reusable smoothed-RR metric layer

- [x] **Task 1: Create `SmoothedRrSource` App-singleton smoothing layer**
  Files: `lib/Biometrics/SmoothedRrSource.dart`
  New always-on derived-metric layer over `ActiveRrSource`. Pure Dart, RxDart `BehaviorSubject` (mirror the style of `ActiveRrSource`), no breath/tick knowledge.
  - Constructor `SmoothedRrSource(ActiveRrSource source, {int window = _defaultWindow})`; subscribes to `source.stream` in the constructor.
  - `static const int _defaultWindow = 7;` (document in a comment that 9 = smoother but laggier, a one-line change).
  - Maintain a ring/list of the last `window` **non-artifact** intervals: on each `RrInterval`, if `rr.isArtifact` **skip it silently** (this is the artifact-filter slot flagged in `ActiveRrSource` docs; do **not** log it — `ActiveRrSource` already logs every artifact, and the minimal-logging setting forbids double-logging the same event); otherwise push `rr.intervalMs`, trim to `window`, recompute the simple moving average (integer rounded) and publish it.
  - Expose: `int? get smoothedIntervalMs` (current SMA, `null` before the first accepted beat — the `BehaviorSubject` is created **unseeded**, so it `hasValue` only after the first non-artifact interval), `Stream<int> get smoothedIntervalStream` (`BehaviorSubject<int>` — emits once per accepted real beat; replays its last value to new subscribers **only when it `hasValue`**, which Task 3's conditional guard depends on), and pass-throughs `bool get hasActiveSource => source.hasActiveSource` and `Stream<bool> get hasActiveSourceStream => source.hasActiveSourceStream`.
  - `dispose()` cancels the subscription and closes the subject. Does **NOT** dispose `source`.
  - Use the `logPrint` facade (`package:mind/Logger.dart`) for any logging, never `print`/`debugPrint`.

### Phase 2: Wire the singleton into App

- [x] **Task 2: Register `smoothedRrSource` singleton in `App`** (depends on Task 1)
  Files: `lib/Core/App.dart`
  Mirror the existing `activeRrSource` wiring exactly — frame it as general **biometric infrastructure** (like `activeRrSource`), not breath-module state, to stay compliant with the "App.dart is infrastructure only" rule:
  - Add `import 'package:mind/Biometrics/SmoothedRrSource.dart';`.
  - Add `final SmoothedRrSource smoothedRrSource;` field (next to `final ActiveRrSource activeRrSource;`, line 98).
  - Add `required this.smoothedRrSource,` to the `App._` constructor.
  - In `initialize()`, after `final activeRrSource = ActiveRrSource([bciProvider]);` (line 214), add `final smoothedRrSource = SmoothedRrSource(activeRrSource);` so its moving average accumulates continuously from app start (warm by the time any session opens).
  - Pass `smoothedRrSource: smoothedRrSource,` into the `App._(...)` call (next to `activeRrSource:`, line 243).
  - No App-level dispose exists (singleton lives for the process), so no teardown wiring is required — matches `activeRrSource`.

### Phase 3: Rewrite the heart tick service as a metronome

- [x] **Task 3: Rewrite `HeartRateTickService` as a free-running smoothed-cadence metronome** (depends on Task 1)
  Files: `lib/BreathModule/HeartRateTickService.dart`
  Replace the 1:1 beat→tick implementation. Keep the `ITickService` contract identical (`tickStream`, `source => TickSource.heartbeat`, `nominalIntervalMs`, `sourceChanges => const Stream.empty()`, `trySwitchTo => false`). Constructed per-session over the already-warm `SmoothedRrSource`.
  - Constructor `HeartRateTickService({required SmoothedRrSource smoothedRrSource, <timer factories>})` replacing the `ActiveRrSource` injection.
  - Add a public `void start()` method (mirrors `ClockTickService.simulateTick()`) that launches the metronome. Keeping it public preserves the spec's settled `..start()` symmetry; the test fake gets a matching no-op (Task 4).
  - Own `_effectiveActive` as a `BehaviorSubject<bool>` **seeded from `smoothedRrSource.hasActiveSource`** (not hard false). Re-point `bool get hasActiveSource` and `Stream<bool> get hasActiveSourceStream` at `_effectiveActive` — these are exactly what `SwitchableTickService` reads.
  - **Metronome timer:** a **one-shot timer that reschedules itself** after each fire (NOT `Timer.periodic` — a fixed periodic timer cannot change its interval and would freeze the cadence at the first period, ignoring later smoothed updates). Started by `start()`. On fire → `_tickController.add(TickData(_currentPeriodMs))` then schedule the next one-shot at the current `_currentPeriodMs`. Free-runs for the whole session; **no prime/immediate tick**; **no pause/lifecycle subscription**; **never stopped on grace** — only `dispose()` cancels it.
  - `_currentPeriodMs` = `smoothedRrSource.smoothedIntervalMs ?? 1000` (1000 ms placeholder only before any beat ever arrives). Keep `nominalIntervalMs => 1000`.
  - **Subscribe to `smoothedRrSource.smoothedIntervalStream`, conditionally ignoring the replay.** A `BehaviorSubject` replays its last value synchronously to a new subscriber **only when it `hasValue`** — so a replay is pending only on the **warm** path. Capture at construction `final bool _expectReplay = smoothedRrSource.smoothedIntervalMs != null;` and:
    - **Warm path** (`_expectReplay == true`): the first delivered emission is the stale replay → **drop it** (it may come from a now-disconnected sensor; treating it as a beat would falsely set `_effectiveActive` true and arm grace against a phantom source, letting `trySwitchTo(heartbeat)` succeed with no live sensor). Every emission **after** the replay is a genuine beat.
    - **Cold path** (`_expectReplay == false`): there is **no** replay → the **first** delivered emission is already a genuine beat; do **not** skip it (an unconditional `.skip(1)` here would drop the first real beat and delay activation to the second, contradicting "first real beat activates — matches today's behavior").
    - On every **genuine (non-replay) beat**: update `_currentPeriodMs`, set `_effectiveActive` true, and **reset (arm) the grace timer**. Beats never emit ticks. Implement the guard so "subsequent emission" precisely means "non-replay emission" in both paths (e.g. a `bool _droppedReplay = !_expectReplay;` that is flipped true after dropping the one replay).
    - Initial activation in **both** paths is governed solely by the constructor seed (`smoothedRrSource.hasActiveSource`), never by the replayed value.
  - **Grace timer** `static const Duration _coastGraceWindow = Duration(seconds: 10);`: a one-shot timer, armed at construction if seeded active; reset on every genuine beat; on fire → `_effectiveActive.add(false)` only (do NOT stop the metronome). `SwitchableTickService` reacts to the false and auto-falls-back to the clock. Coast (0–10 s) falls out for free because `_effectiveActive` stays true and the metronome keeps forwarding at the last smoothed period.
  - Before the first beat ever (`smoothedIntervalMs == null`, cold path): metronome runs at 1000 ms placeholder but `_effectiveActive` stays false (seeded cold) until the first real beat, so `trySwitchTo(heartbeat)` is rejected — matches today's behavior.
  - **Testability (folded in, same file):** inject timer factories the way `ActiveRrSource` does (note 90) — a one-shot reschedulable factory for the metronome and a one-shot `Timer Function(Duration, void Function()) = Timer.new` for the grace timer, defaulting to production behavior.
  - `dispose()` cancels the metronome timer, the grace timer, the smoothed-stream subscription, closes `_tickController` and `_effectiveActive`. Does **NOT** dispose `smoothedRrSource` (owned by App).
  - Use `logPrint` for any logging.

- [x] **Task 4: Inject and start the metronome in `BreathModule.buildSession`; keep the existing test compiling** (depends on Task 2, Task 3)
  Files: `lib/BreathModule/BreathModule.dart`, `test/BreathModule/switchable_tick_service_test.dart`
  - In `BreathModule.buildSession`: replace `final heart = HeartRateTickService(activeRrSource: App.shared.activeRrSource);` (line 33) with construction over `App.shared.smoothedRrSource` and start the metronome at construction alongside the clock, mirroring `ClockTickService()..simulateTick()` — `final heart = HeartRateTickService(smoothedRrSource: App.shared.smoothedRrSource)..start();`. Everything else in `buildSession` (the `SwitchableTickService`, ViewModel, module channel wiring) stays unchanged. (Construction order is already correct: `heart` is built before `SwitchableTickService(clock, heart)`, which subscribes to the seeded `_effectiveActive` on construction.)
  - In `switchable_tick_service_test.dart`: add a single `@override void start() {}` no-op to `_FakeHeartRateTickService` (it `implements HeartRateTickService`, so the new public `start()` must be satisfied). This mirrors the existing `@override void simulateTick() {}` no-op in `_FakeClockTickService` (line 41). **No other test changes** — test logic and assertions stay identical and green.

### Phase 4: Documentation & roadmap

- [x] **Task 5: Update tick-source and RR docs (in Russian)** (depends on Task 3)
  Files: `docs/breath/session/tick-sources.md`, `docs/biometrics/active-rr-source.md`
  Both files are written in **Russian** — write these updates in Russian to match (per the global "match the language of neighboring docs" rule, which overrides the English-files project rule here). Describe behavior, not code — no method/field lists, no file trees.
  - `tick-sources.md`: describe `HeartRateTickService` as a smoothed-cadence metronome (period = moving average of RR via `SmoothedRrSource`), no longer 1:1 beat→tick; real beats only adjust the period; auto-fallback to the clock fires only after `_coastGraceWindow` (10 s) of no real beat, and is one-way (user re-enables manually).
  - `active-rr-source.md`: note that a new `SmoothedRrSource` derived layer now sits above `ActiveRrSource`; `ActiveRrSource` stays raw with its silence window unchanged.

- [x] **Task 6: Mark ROADMAP Phase 45 complete** (depends on Task 5)
  Files: `.ai-factory/ROADMAP.md`
  ROADMAP **Phase 45 — "Heart tick source: smoothed-cadence metronome (gap tolerance)"** already exists and already references `notes/130-heart-tick-source-gap-tolerance.md`. Do **not** add a new entry (would duplicate). Verify the linkage is correct and mark the Phase 45 task `[x]` on completion.

## Commit Plan
- **Commit 1** (after tasks 1-2): "Add SmoothedRrSource smoothing layer and wire App singleton"
- **Commit 2** (after tasks 3-4): "Rewrite heart tick source as smoothed-cadence metronome"
- **Commit 3** (after tasks 5-6): "Document smoothed-RR metronome tick source"
