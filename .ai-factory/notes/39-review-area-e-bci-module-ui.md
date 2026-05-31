# Code Review — Area E: BCI Module UI (Phases 17, 19, 23)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `lib/BciModule/{BciPairingService,BciDataService,BciModule,BciDataCoordinator}.dart`, `packages/bci_module/lib/src/BciPairing/*`, `packages/bci_module/lib/src/BciData/*`

## Verdict

Clean area, no correctness bugs. The reducer/DTO boundary is well-built: both `BciPairingState` and `BciDataState` use the `_undefined`-sentinel `copyWith` correctly, so the disconnect-clears actually clear (the classic "passing null is a no-op" trap is avoided), and the Phase 17 post-review re-subscription fix is present. Findings are duplication + one cross-file inconsistency, all low severity.

## Key Findings

- **[Low / inconsistency] Battery is cleared on disconnect in one service but not the other.** `BciDataService._reduce` clears `batteryPercent: null` on `disconnected`/`bluetoothPermissionDenied`. `BciPairingService._reduceStateChanged` does **not** pass `batteryPercent` in its `disconnected` branch, so a stale battery percentage survives a disconnect in the pairing state (the header may show e.g. "47%" with no device). Add `batteryPercent: null` to the pairing disconnect branch for parity.
- **[Low / duplication] `_mapLevel` + channel→DTO mapping duplicated verbatim.** `BciSignalLevel → BciSignalQuality` and the `BciChannelQuality → BciChannelQualityDTO` list map appear identically in both `BciPairingService` and `BciDataService`. Candidate for a shared mapper (e.g. a `BciChannelQualityDTO.fromDomain` factory or a small extension).
- **[Low / inconsistency] Two ViewModels, two subscription lifecycles.** `BciDataViewModel` subscribes to `service.events` inside `build()` (automatic). `BciPairingViewModel` subscribes inside a separate `initState()` that the screen must call explicitly (it does, via a post-frame callback). The split is easy to trip over if a new entry point to the pairing screen is added and forgets the call. Worth aligning on one pattern.
- **[Low / by-design] Running-max normalization never decays.** `BciDataViewModel` ratchets a per-metric max upward and never resets within the VM lifetime (Phase 23 decision). A single outlier sample (e.g. an EEG band spiking to 50.0) permanently compresses every subsequent bar for that metric to ≤2% for the rest of the screen session. Accepted trade-off, but a decaying/percentile ceiling would be more robust if bars are seen to "die" after a glitch.

## Details

### Verified correct
- `_undefined`-sentinel `copyWith` in both states distinguishes "not provided" from "set null"; `channels` (a non-null `List`) is cleared with an explicit `const []` since `?? this.channels` can't clear it — comments call this out and the reducers honor it.
- `BciPairingViewModel`: `ref.onDispose` cancels **and nulls** `_eventsSubscription`, and `initState()` guards on `_eventsSubscription != null` — the Phase 17 post-review fix that allows re-subscription after a notifier rebuild.
- `BciModule.buildPairing` creates only `BciPairingService` (no coordinator) — consistent with the Phase 23 removal of `BciPairingCoordinator`. `buildDataScreen` wires `BciDataService` + `BciDataCoordinator(context)` and overrides the provider.
- `BciDataService._reduce`: heart rate shown only when `metricsAvailable && !hasArtifacts` (artifact gating); `isConnected` true for impedance/calibrating/ready, false for scanning/connecting/disconnected — correct.
- `BciDataViewModel._normalizeNfb/_normalizeEmotions`: per-metric, null-safe, init 1.0 (no-op when SDK contract holds). The `BciMetricBar` `clamp(0..1)` remains as the fp/negative safety net.

### Known limitation (documented in code)
Both services build state via `bciNotifier.stream.scan(..., initial())`. Because `BciNotifier` is a `BehaviorSubject` caching only the latest event, a fresh subscriber's `scan` rebuilds from `initial()` seeded by a single replayed event — pre-screen accumulation (battery, channels emitted before the screen opened) is not reconstructed until re-emitted. Mitigated by `startScan()` re-triggering the flow on mount. Comments in both services document this.

## Open Questions

- Align the two VMs on a single subscription lifecycle (both in `build()`)? `BciPairingViewModel.initState()` also fires `startScan()`, which is the real reason it's deferred — but the subscription itself could move into `build()`.
