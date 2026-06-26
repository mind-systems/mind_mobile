# Plan Review: Add HR-derived cadence source as automatic fallback (`60000/heartRate`)

**Plan:** `02-add-hr-derived-cadence-source-as-automatic-fallback-60000-heartrate.md`
**Risk Level:** 🟢 Low — plan is accurate, faithful to the spec note, and all file/line references check out.

## Verification summary

Every concrete claim in the plan was checked against the live codebase:

| Claim | Status |
|---|---|
| `ITickCadenceSource` contract at `lib/BreathModule/TickCadence/ITickCadenceSource.dart` | ✅ exists; `smoothedPeriodMs`/`currentPeriodMs`/`isUsable`/`usableChanges`/`dispose` as described |
| `RrTickCadenceSource` structure (graceWindow 10s, `timerFactory = Timer.new`, App-owned singleton not disposed) | ✅ matches (`RrTickCadenceSource.dart:29-52, 80-85`) |
| `IHeartRateSource` exposes `Stream<CardioData> get cardioStream` | ✅ `IHeartRateSource.dart:12` |
| `CardioData` fields `heartRate` (double), `metricsAvailable` (bool), `hasArtifacts` (bool) | ✅ `CardioData.dart:9-11` |
| `NeiryBciProvider implements ... IHeartRateSource` | ✅ `NeiryBciProvider.dart:40` |
| `bciProvider` created at `App.dart:193`, used as `cardioSource:` at `:196` | ✅ |
| App fields `smoothedRrSource` at `:104`, ctor `:137`, wiring `:258` | ✅ all line refs correct |
| `BreathModule.buildSession()` cadence wiring at `:35-36`, `heart` line at `:37` references `selector` | ✅ correct; `heart`/`clock`/`SwitchableTickService` lines remain valid |
| `TickCadenceSelector` `TODO(note-164)` at `currentPeriodMs` (`:53-61`), unconditional `_sources.first` fallback | ✅ exactly as described |
| `cardioStream` is a broadcast stream (safe for an additional subscriber) | ✅ `_cardioController = StreamController<CardioData>.broadcast()` (`NeiryBciProvider.dart:62`) |

The selector's auto-fallback mechanics also confirm the plan's core thesis: `SwitchableTickService` only flips to the clock when `_heart.hasActiveSourceStream` emits `false` (`SwitchableTickService.dart:16-20`), which is driven by the selector's aggregate `isUsable`. With HR added as priority-2, the aggregate stays `true` while HR streams, so the metronome no longer flips to the clock during RR staleness. Goal is correctly achieved.

## Context Gates

- **Roadmap (alignment): PASS.** Maps exactly to ROADMAP Phase 57, the second checkbox ("Add HR-derived cadence source as automatic fallback (`60000/heartRate`)"). Spec note `.ai-factory/notes/02-heart-rate-derived-cadence-fallback.md` is faithfully reflected — staleness window pinned to 10s, no SMA (final decision), HR as cadence source not synthetic `IRrIntervalSource`, trust SDK flags.
- **Rules (RULES.md): PASS with note.** Rule 2 forbids "module-specific state, streams, or triggers in App.dart — App.dart is infrastructure only." Task 2 adds `heartRateSource` to App.dart. This is acceptable and correctly justified: it is a domain biometric source singleton (the same `bciProvider` already wired as `cardioSource`/router source), structurally identical to the existing `activeRrSource`/`smoothedRrSource` infrastructure fields — not module-specific breath state. Rule 3 (constructor injection, no external wiring) is satisfied — the HR cadence source subscribes to its own injected `cardioStream`.
- **Architecture: PASS.** New source slots into the existing `ITickCadenceSource` + selector abstraction with no boundary violation. `ARCHITECTURE.md` has a DI-wiring section that mentions `App` initialization; since the plan sets `Docs: no`, leaving it unupdated is acceptable (WARN-level only, non-blocking).

## Findings

### Minor — prefer `BehaviorSubject<int>` over a plain broadcast `StreamController<int>` for `smoothedPeriodMs` (handoff correctness)

Task 1 offers two options: "a `BehaviorSubject<int>` (or a broadcast `StreamController<int>`)" for `smoothedPeriodMs`. These are **not** equivalent for the RR→HR failover, and `BehaviorSubject` is the correct choice — recommend pinning it rather than leaving it open.

Reason: the plan emits the period *before* flipping `isUsable` ("emit it on `smoothedPeriodMs`, set `isUsable = true`"). The selector reacts to the `usableChanges` transition by re-selecting HR and *then* subscribing to `HeartRateTickCadenceSource.smoothedPeriodMs` (`TickCadenceSelector.dart:108`). With a plain broadcast controller, the period value emitted on the *activating* sample is already gone — the selector receives nothing until the **next** valid `CardioData` (~1 beat later), so the metronome coasts at the stale RR period during the handoff. A seeded `BehaviorSubject` replays the last period to the selector's new subscription immediately, so HR cadence takes over on the same sample that triggered the switch. This also matches the RR source, whose `smoothedPeriodMs` passes through `SmoothedRrSource.smoothedIntervalStream` (a replay-style stream), keeping both sources consistent under the selector.

Recommendation: specify `BehaviorSubject<int>` for `smoothedPeriodMs` (not "or broadcast StreamController").

### Nit — naming proximity to `HeartRateTickService`

`HeartRateTickService` (`lib/BreathModule/HeartRateTickService.dart`) is the dumb metronome currently fed by **RR** (via the selector), while the new `HeartRateTickCadenceSource` is fed by actual **HR/BPM**. The two "HeartRate…" names sit side by side in the same module and mean different things. This is the name the roadmap/spec already chose, so keep it — just flagging that a one-line class-doc cross-reference (as Task 1 already requires for the "HR is a cadence source, not a synthetic RR source" note) will reduce future confusion. No change required.

## Positive Notes

- File paths, line numbers, constructor signatures, and the `metricsAvailable && !hasArtifacts && heartRate > 0` validity gate all match the actual `CardioData` shape and sibling `RrTickCadenceSource` conventions — no fantasy holes.
- Task 4 correctly identifies and resolves the pre-existing `TODO(note-164)`: with HR added, the null-snapshot fallback in `currentPeriodMs` must walk priority order rather than blindly return `_sources.first`. Good catch that the plan ties this fix to the same change set.
- Disposal ownership is correct and explicit: the chain `SwitchableTickService → HeartRateTickService → selector → HR source` disposes children, and the HR source correctly does **not** dispose the App-owned `IHeartRateSource` (mirrors `RrTickCadenceSource`).
- Cold-start behavior is sound: seeding `isUsable=false` and `currentPeriodMs=null` is appropriate since `IHeartRateSource` has no synchronous "is-active" snapshot and the broadcast `cardioStream` provides no replay — HR simply warms up on the first valid sample, and RR (priority 0) covers the warm path regardless.
- Phase ordering and dependencies (Task 3 depends on 1+2; Task 4 depends on 1) are correct.

The two findings are both non-blocking quality recommendations, not defects in the plan's correctness. The plan is implementable as written.

PLAN_REVIEW_PASS
