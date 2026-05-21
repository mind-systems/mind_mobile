# Neiry Kit Integration — BCI & Heart Rate Architecture

**Date:** 2026-05-21
**Source:** conversation context

## Key Findings

- The BCI section in `mind_mobile` is unimplemented — `lib/Device/` is unrelated (it handles device-ping telemetry, not BCI). Integration starts from a clean slate.
- `neiry_kit` (sibling repo at `../neiry_kit`) already exposes the needed Dart API: `DeviceLocator`, `Device` with `eegStream`, and a set of classifiers (`NfbClassifier`, `CardioClassifier`, `PhysioClassifier`, etc.). It is the concrete adapter, not the abstraction.
- `ITickService` abstraction already exists in `packages/breath_module`; only `ClockTickService` is implemented. A `CardioTickService` (heart-rate → intervalMs) is the natural integration point between BCI and breath sessions.
- BCI in `HomeScreen` is currently a pure placeholder (`onComingSoonTap`) — no domain code exists yet.
- Architecture must support multiple future BCI headbands and multiple heart-rate sources (headband, fitness band, Apple Watch / HealthKit, Google Fit). Solution: two independent provider interfaces — `IBciDeviceProvider` and `IHeartRateProvider` — with Neiry implementing both (EEG + optional PPG/HR if hardware supports).
- Data sent to backend during breathing sessions should be **aggregated only** (band powers per region at 4–10 Hz, classifier scores, phase-correlated). Raw EEG (~8 KB/s) is too heavy for routine storage; keep raw as opt-in "research mode" stored separately (e.g. S3).
- HRV is a separate domain service (`HrvAnalyzer`) that consumes `rrIntervalStream` from any `IHeartRateProvider` — independent of breathing sessions.

## Details

### neiry_kit API surface

| Class | Key streams |
|---|---|
| `DeviceLocator` | `requestDevices()` → `Stream<List<DeviceInfo>>` |
| `Device` | `eegStream`, `psdStream`, `resistanceStream`, `batteryStream`, `connectionStateStream`, `calibratedStream` |
| `CardioClassifier` | `cardioStream` → `CardioData` (heartRate BPM, kaplanIndex, stressIndex, `metricsAvailable`); also exposes raw `ppgStream` for custom HRV |
| `NfbClassifier` | `nfbStream` → `NfbUserState` (delta/theta/alpha/smr/beta, 0–1) |
| `PhysioClassifier` | `physioStream` → relaxation, stress, fatigue, concentration (0–1) + artifact flags |
| `EmotionsClassifier` | attention, relaxation, cognitiveLoad, cognitiveControl, selfControl |
| `ProductivityClassifier` | productivity score / focus events |

Important: `CardioData.heartRate` is only valid when `metricsAvailable == true`. Wait for `calibratedStream` to fire before trusting any classifier metrics.

### Proposed module layout

```
packages/bci_module/                 UI: pairing screen, main BCI screen, signal-quality indicator
  IBciDeviceProvider                 scan / connect / disconnect / qualityStream / eegBandsStream
  IBciClassifierProvider             alpha/beta/theta/... aggregated stream

lib/Heart/                           heart-rate domain
  IHeartRateProvider                 hrStream + rrIntervalStream
  HeartRateNotifier                  domain notifier; subscribes to currently active provider
  HrvAnalyzer                        consumes RR intervals → RMSSD/SDNN/pNN50/LF-HF

lib/Bci/
  BciDeviceManager                   discovery, connect, lifecycle, auto-reconnect, persisted serials
  BciNotifier                        domain state stream (device + signal quality + calibration)
  NeiryBciProvider                   adapter over neiry_kit (EEG + classifiers)
  NeiryHeartRateProvider             Neiry headband PPG/ECG → implements IHeartRateProvider
  WearableHeartRateProvider          HealthKit / Google Fit / fitness band → same interface

lib/BreathModule/
  CardioTickService                  implements ITickService via IHeartRateProvider
```

### Device connection state machine

```
disconnected → scanning → connecting → impedance → calibrating → ready
```

Transitions:
- `scanning` enters automatically when pairing screen opens.
- `connecting` triggers when user taps a discovered device OR when a previously paired device is found in range (auto-reconnect).
- `impedance` is **mandatory** on every connect — user must verify contact on every electrode pad.
- `calibrating` is also **mandatory** on every connect — user closes eyes, calibration runs to completion, sound signal plays on finish (reuse the asset from `neiry_kit` example app).
- `ready` means `calibratedStream` has fired and `metricsAvailable == true`.

### Pairing screen UX

A single screen handles discovery, connect, impedance, and calibration.

- Persist serials of **all** previously paired headbands.
- On BCI main screen open with no active device → pairing screen opens automatically.
- Pairing screen always shows the list of discovered devices (so a different device can be selected even when a known one is in range).
- If a known device is found in scan, connect to it automatically in the background; user still sees the scan list.
- Connect + start are merged into a single action — no separate "start" button as in the kit example.
- After connect: impedance indicators per channel become active. Calibration control becomes enabled. Controls below the connect area stay greyed out until connection is established.
- Calibration runs in place on the same screen with a "close your eyes" instruction. Audio cue on completion.
- Pairing screen can be dismissed at any time, returning to the BCI main screen. Dismissing during calibration cancels it.
- Disconnect button on the BCI main screen returns to pairing screen to choose another device.

### BCI main screen

Composite layout drawn from the original Neiry app screens (used as reference only, not as a design template — our version is simpler):

- **Top bar:** per-channel signal-quality bars (green/yellow/red) + battery indicator.
- **Body:** vertical coloured bars, one per available metric from active classifiers (band powers, relaxation, stress, etc.). Bars animate to current values; height/colour reflects live state.
- **States:** "collecting" (device connected but `metricsAvailable == false`, bars are flat/placeholder) → "active" (bars reflect live classifier output).
- **Controls:** disconnect button (returns to pairing screen).

### Device persistence model

- Save a list of paired device serials so any of them can be auto-connected when in range.
- This is **not** a property of the User aggregate — model it as a separate server-side resource (e.g. `BciDevice` table with `user_id` FK) that owns its own lifecycle (add / remove / last-used).
- Mobile caches the list locally for offline auto-connect; server is the source of truth for cross-device sync.
- Proto contract for the device list lives in `mind_api/proto/` (API-owned).

### Auto-connect flow

1. App start → load paired-serials list from local cache.
2. BCI main screen open → if no device active, push pairing screen.
3. Pairing screen → `requestDevices()` immediately, render results live.
4. If a result matches a saved serial → start `connect()` in background.
5. After connect → user goes through impedance + calibration (mandatory).
6. `calibratedStream` fires → state machine reaches `ready`, BCI main screen unlocks.

### Heart-rate provider selection

- Heart module never references Neiry directly — only `IHeartRateProvider`.
- `App.shared` selects the active provider based on what is connected and user preference. Adding a new wearable = new adapter, no consumer changes.

### CardioTickService

```dart
class CardioTickService implements ITickService {
  // BPM → intervalMs: 60000 / heartRate (hysteresis to prevent jitter)
  // fallback: if metricsAvailable == false → emit fixed 1000ms (timer fallback)
  @override TickSource get source => TickSource.heartbeat;
}
```

Injection in `BreathModule.dart`: use `CardioTickService` when an `IHeartRateProvider` is ready, else fall back to `ClockTickService`.

### Breathing-session data contract

**Do not send raw EEG** (~250 Hz × N channels is too heavy for routine storage).

**Send per breath phase** (inhale / hold / exhale / rest):

| Source | Fields | Purpose |
|---|---|---|
| `NfbClassifier` | alpha, theta, beta (0–1) | Relaxation + cognitive load |
| `PhysioClassifier` | relaxation, stress (0–1) + artifact flags | Direct correlation with breathing |
| `CardioClassifier` | heartRate, kaplanIndex, stressIndex | HRV, stress level |
| Meta | phase, phase_duration_ms, artifact_count | Context for interpretation |

Artifact flags are mandatory — data without quality indicators is uninterpretable.

**Opt-in "research mode":** raw EEG stream uploaded to object storage (not main DB), behind explicit user consent.

Likely new proto entity, e.g. `BciSessionSample { ts, phase, channel, band, power }` — to be defined in `mind_api/proto/`.

### Classifiers to run during a session

Running all six classifiers has measurable CPU/battery cost. Minimal set:

- `CardioClassifier` — HR tick source + stress index
- `NfbClassifier` — band powers
- `PhysioClassifier` — relaxation/stress + artifact flags

Defer `EmotionsClassifier` and `ProductivityClassifier` until there is a concrete UI consumer.

### HRV strategy

- Short-term: use `kaplanIndex` + `stressIndex` from `CardioClassifier` (available out of the box from the SDK).
- Full HRV (RMSSD, SDNN, pNN50): compute from raw `ppgStream` RR intervals — more work but more precise and SDK-independent.
- `HRVCapabilities.full` on `NeiryHeartRateProvider` signals raw-RR capability.
- Fitness bracelet adapters typically report `HRVCapabilities.basic` (HR only, SDNN approximation).

### Relevant existing files

| File | Role |
|---|---|
| `packages/breath_module/lib/src/ITickService.dart` | Tick source abstraction — extend with `CardioTickService` |
| `packages/breath_module/lib/src/CommonModels/TickSource.dart` | `enum TickSource { heartbeat, timer }` |
| `lib/BreathModule/ClockTickService.dart` | Only existing `ITickService` impl |
| `packages/breath_module/lib/src/BreathSession/BreathSessionViewModel.dart` | Consumes `ITickService` — injection point |
| `lib/BreathModule/BreathModule.dart` | Assembly point — wire `CardioTickService` here |
| `lib/Core/App.dart` | App singleton — register `BciDeviceManager` and active providers |
| `lib/HomeModule/Presentation/HomeScreen/HomeScreen.dart` | BCI placeholder tile — replace `onComingSoonTap` with navigation to BCI main screen |

### Future-headband principle

Each new BCI device = new adapter implementing `IBciDeviceProvider`. The domain, UI package, and breathing-session pipeline must depend only on the interface and never on `neiry_kit` directly.

## Open Questions

1. **HRV from raw PPG or Neiry's built-in metrics?** Built-in (`kaplanIndex`, `stressIndex`) is simpler but SDK-bound; raw gives RMSSD/SDNN precision but needs client-side DSP. Could ship built-in first, upgrade to raw later.
2. **`CardioTickService` fallback behavior:** auto-fallback to fixed 1000 ms timer when `metricsAvailable == false`, or pause the breath session until calibration completes? UX trade-off.
3. **Final shape of the `BciSessionSample` proto** — needs to be authored in `mind_api/proto/` before mobile work begins.
4. **Current state of heart-rate integration** — does any HealthKit / Google Fit code already exist, or is heart truly greenfield too?
5. **Does the Neiry headband expose RR intervals / PPG via `neiry_kit`?** Determines whether `NeiryHeartRateProvider` is the first HR adapter or whether we start with HealthKit.
6. **Impedance UI fidelity** — per-channel colour indicators (green/yellow/red) or a simplified "adjusting…" state? Pairing screen needs a clear design call.
