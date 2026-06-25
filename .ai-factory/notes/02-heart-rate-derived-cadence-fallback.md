# HR-derived cadence source as automatic fallback (`60000 / heartRate`)

**Date:** 2026-06-23
**Source:** conversation context

## Key Findings

- In `neiry_kit` the **RR intervals are computed by us on raw PPG**, while the **heart rate (BPM) is computed by the SDK** with a different algorithm. The two tracts fail independently — observed in logs: RR went 45 s of solid `isArtifact=true` (and a brief mislabeled `430 ms` spike → "2× too fast") while HR kept streaming valid values. Therefore HR is a **valid second cadence source**, not a redundant view of RR.
- A device can be treated as **two cadence sources at once**. The same code must serve a future HR-only sensor (a strap that emits only BPM) — so the HR cadence source is generic over `IHeartRateSource`, not Neiry-specific.
- Switching must be **automatic, no user action**. All cadence sources stay warm in parallel; the `TickCadenceSelector` (note 163) picks the highest-priority **usable** one. Priority: `[RR, HR]` — RR preferred (closest to raw beats), HR is the fallback.
- **We consume the SDK's flags, we do not clean RR.** No plausibility filter is added to RR (explicitly rejected). The mislabeled-spike micro-wobble is accepted as the SDK's responsibility; the sustained failure is what the HR fallback fixes.

## Details

Depends on note 163 (the `ITickCadenceSource` contract + selector + dumb metronome must exist first).

### `HeartRateTickCadenceSource(IHeartRateSource)` — `lib/BreathModule/TickCadence/`

Implements `ITickCadenceSource` over `IHeartRateSource.cardioStream` (`IHeartRateSource.dart:12`). Field types are fixed by `CardioData` (`lib/Biometrics/Models/CardioData.dart:9-11`): `heartRate` is `double`, `metricsAvailable` is `bool`, `hasArtifacts` is `bool` (plus `timestamp`, `source`).

- On each `CardioData`:
  - **valid** when `metricsAvailable && !hasArtifacts && heartRate > 0` → `smoothedPeriodMs.add((60000 / heartRate).round())` (`int`, matches the `Stream<int>` contract), set `isUsable = true`, re-arm the staleness timer;
  - otherwise treat as a gap (do not emit, do not refresh staleness).
- **Staleness** is this source's own concern (mirrors the RR source's grace). **Window = 10 s**, pinned to match the RR grace `_coastGraceWindow = Duration(seconds: 10)` (`HeartRateTickService.dart:54`) for one consistent gap-tolerance across both sources. No valid cardio within 10 s → `isUsable = false`. (Tunable later, but ship at 10 s — not an implementation-time guess.)
- **No extra moving average initially.** BPM is already an SDK-side average of intervals; stacking another SMA on top would lag the live heart. Emit `60000/HR` directly. Whether a light smoothing helps is a **measurement to do later** — keep smoothing an internal, swappable detail of this class so it can be added without touching the contract.
- HR is a **cadence source**, NOT an `IRrIntervalSource` injected into `ActiveRrSource`/the RR pipeline. We do not fabricate synthetic RR intervals into the raw RR merge — the HR derivation lives entirely inside this cadence source.
- `dispose()` cancels the cardio sub + staleness timer + closes subjects; does not dispose the underlying `IHeartRateSource` (App-owned).

### Wiring — register as priority-2 in the selector

**`App.shared` does not currently expose any `IHeartRateSource`** — it exposes only `activeRrSource` (`App.dart:103`) and `smoothedRrSource` (`:104`); `bciProvider` is a local in `initialize()` (`:193`, `NeiryBciProvider` which implements `IHeartRateSource`, passed as `cardioSource:` at `:196`). So a new App surface must be **added** (not reused):

1. Add field `final IHeartRateSource heartRateSource;` next to `smoothedRrSource` (`App.dart:104`) + constructor param next to `:137` + `required this.heartRateSource` next to `:137`.
2. Pass `heartRateSource: bciProvider` in the `shared = App._(...)` block, alongside `smoothedRrSource: smoothedRrSource` (`App.dart:258`).
3. Add import `package:mind/Biometrics/IHeartRateSource.dart` to `App.dart`.

Then wire in `BreathModule.buildSession()` (replacing the `:33` line from note 163):

```dart
final rrCadence = RrTickCadenceSource(App.shared.smoothedRrSource);
final hrCadence = HeartRateTickCadenceSource(App.shared.heartRateSource);
final selector  = TickCadenceSelector([rrCadence, hrCadence]); // index 0 = RR preferred, index 1 = HR fallback
final heart     = HeartRateTickService(cadence: selector)..start();
```

### Resulting behavior

- RR usable → RR drives the cadence (unchanged from note 163).
- RR goes stale (silence or sustained artifacts) → selector switches to HR automatically; the metronome keeps ticking at `60000/HR` with no flip to the clock, because the selector's aggregate `isUsable` never drops while HR is alive.
- RR becomes usable again → selector reclaims RR (lower index).
- Future HR-only device: wrap its `IHeartRateSource` in `HeartRateTickCadenceSource`, add to the list — same code path, no other changes.

## How to verify

- With a live headband, force RR to drop (sustained artifacts) while HR keeps streaming → heart tick stays active at the HR-derived cadence (~real BPM), no fallback-to-clock, no "connect a heart sensor" alert.
- Restore RR → cadence reclaims the RR source.
- Unit: a fake `IHeartRateSource` emitting `metricsAvailable=true` BPM yields `isUsable=true` and `smoothedPeriodMs == round(60000/bpm)`; a gap past the staleness window flips `isUsable=false`; selector failover RR→HR→RR ordering holds.

## Decisions

- **HR staleness window = 10 s** (pinned to `HeartRateTickService.dart:54`), no extra SMA — ship as-is.
- **App surface = new `heartRateSource` field** holding `bciProvider` (no existing exposure to reuse, verified against `App.dart:103-104,193,258`).

## Open Questions

- Whether a light HR smoothing or a shorter window helps (lag vs jitter) — a **post-ship measurement**, not a blocker. Smoothing is an internal swappable detail of `HeartRateTickCadenceSource`, so it can change without touching the contract or wiring.
