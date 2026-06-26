# Code Review: Add HR-derived cadence source as automatic fallback (`60000/heartRate`)

**Scope reviewed:** `git diff HEAD` + `git status` — new file `HeartRateTickCadenceSource.dart`, plus edits to `BreathModule.dart`, `TickCadenceSelector.dart`, `App.dart`. Read each changed/new file in full along with the unchanged collaborators (`HeartRateTickService`, `SwitchableTickService`, `RrTickCadenceSource`, `ITickCadenceSource`, `NeiryBciProvider`, `CardioData`).

**Verdict:** No correctness, security, or runtime defects found. Implementation is faithful to the plan and consistent with the sibling `RrTickCadenceSource`.

---

## Correctness analysis

### `HeartRateTickCadenceSource` (new)
- **Validity gate** `!data.metricsAvailable || data.hasArtifacts || data.heartRate <= 0` correctly matches the spec's positive form `metricsAvailable && !hasArtifacts && heartRate > 0` (De Morgan). `heartRate` is `double`; `<= 0` guards both zero and the division.
- **Period math** `(60000 / data.heartRate).round()` yields `int`, matching the `Stream<int>` contract. Out-of-range BPM is additionally clamped downstream by `HeartRateTickService` (`_periodFloorMs` 250 / `_periodCeilMs` 3000), so a pathological-but-non-artifact BPM cannot busy-loop the metronome — HR rides the same protection RR has. No SMA applied, per the final decision.
- **Emit order** period is pushed to `_periodSubject` *before* `_isUsable.add(true)`. `_periodSubject` is a `BehaviorSubject<int>`, so when the selector reacts to the `usableChanges→true` transition and subscribes to `smoothedPeriodMs`, the last period is replayed immediately — the RR→HR handoff lands on the same sample that triggered the switch rather than coasting a stale RR period for one beat. This is the correct resolution of the plan-review's only substantive concern (`BehaviorSubject`, not plain broadcast).
- **Staleness** grace timer re-armed on every valid sample via injected `timerFactory`; on expiry `isUsable→false` and the period is intentionally not reset (coasts), mirroring `RrTickCadenceSource._onGraceExpired`. Window 10 s matches RR.
- **No stale-replay drop needed** — unlike `RrTickCadenceSource` (which drops the first `SmoothedRrSource` BehaviorSubject replay), `cardioStream` is a plain broadcast stream (`NeiryBciProvider.dart:62`) with no replay, so a new subscriber only sees future samples. Omitting the `_droppedReplay` dance is correct, not an oversight.
- **Disposal** cancels the cardio sub + grace timer and closes both subjects; does not dispose the injected `IHeartRateSource`. Correct ownership — `bciProvider` is the App-owned singleton, also consumed by `BciDeviceManager` and `BioStreamRouter`. Post-dispose callbacks cannot fire on a closed subject (sub cancelled, timer cancelled).

### `TickCadenceSelector.currentPeriodMs` (TODO resolved)
- New body returns the active source's snapshot when one is selected; otherwise walks sources in priority order returning the first non-null `currentPeriodMs`, falling back to `_sources.first` only if all are null. This fixes the real defect the old `(_activeSource ?? _sources.first).currentPeriodMs` would have introduced once a nullable-cold HR source joined: with RR cold (`null`) but HR warm, the seed now prefers HR's value instead of returning `null`. TODO comment removed. Behavior with a single source is unchanged.

### Wiring
- `BreathModule.buildSession()` registers `[rrCadence, hrCadence]` — RR priority-0 (preferred), HR priority-1 (fallback). Import added. `clock`/`heart`/`SwitchableTickService` lines untouched, so the documented goal holds: while HR streams the selector's aggregate `isUsable` stays `true`, and `SwitchableTickService` only flips to the clock on `hasActive==false` (`SwitchableTickService.dart:16-20`) — i.e. only when *both* RR and HR are dead. No flip to clock and no "connect a sensor" alert during RR-only staleness. RR revival reclaims priority-0 via `_reSelect`.
- `App.dart` adds `heartRateSource` (field + ctor param + `heartRateSource: bciProvider` wiring + import). `bciProvider` is `NeiryBciProvider` which `implements IHeartRateSource` (`:40`). `cardioStream` is broadcast, so this third subscriber coexists with the existing `cardioSource:`/router subscriptions without "stream already listened to". Type-correct.

## Runtime safety
- **No new streams without cleanup** — the HR source's subjects/sub/timer are all torn down via the existing dispose chain `SwitchableTickService → HeartRateTickService → selector → child sources`.
- **No migrations / codegen** touched (no Drift, no proto).
- **No race** — single-isolate event-loop ordering; selector reacts to `usableChanges` microtask after construction, with `currentPeriodMs` seed covering the pre-resolution window (returns `null` at construction since neither source has a sample yet → metronome seeds the existing `?? 1000` default, unchanged).

## Cold-start note (informational, not a defect)
Because `IHeartRateSource` exposes no synchronous "is-active" snapshot and `cardioStream` has no replay, `HeartRateTickCadenceSource` seeds `isUsable=false` and only warms up on its first valid `CardioData` (~1 beat for a live headband). This is the only behavioral asymmetry vs `RrTickCadenceSource` (which seeds from `hasActiveSource`). It is harmless: RR (priority-0) covers the warm path, and HR is a fallback that legitimately needs one live sample to prove itself. Matches the plan's stated design.

REVIEW_PASS
