# Biometric Stream Architecture — Technical Brief

**Date:** 2026-05-23
**Status:** decisions locked, plan to be written next
**Scope:** mobile-side foundation for streaming biometric data to the API during active module sessions. Pairs with `mind_api` Phase 17 (`ModuleBiometricStreamService` + `bio_session_samples` table).

This note is the design contract — not an implementation plan. The plan agent will turn it into milestones. The point of writing it now is to **fix the architecture before any code is added**, so that we never need to retro-fit non-Neiry hardware (Garmin, Polar, Apple Watch, dedicated chest-strap HR monitors, future EEG devices, etc.) into Neiry-shaped abstractions.

---

## What we are building

A pipeline that takes biometric samples produced by **any** connected device, batches them on the phone, and uploads them through a new gRPC bidi stream to the API, where they will be time-joined with the existing instruction stream (`breath_phase`, `session_event`) by `(moduleSessionId, timestamp)`.

The API side (parallel work in `mind_api`):

- Service: `ModuleBiometricStreamService` — a peer of `ModuleInstructionStreamService`. Same bidi pattern, same `StreamEngine`-style buffering, same `session_id` validation through `ActivityEngine.getActiveSession(userId)`. Different table (`bio_session_samples`).
- Envelope: generic — `{ session_id, timestamp, sample_type, data: google.protobuf.Struct }`. No typing in proto for sample contents. `sample_type` is a free string (`cardio`, `emotions`, `nfb`, ...); the `data` Struct shape is owned by the producer (the mobile side and, transitively, the source device).
- Batching: client sends `repeated BioSample samples = 1` per request — sends a small batch every few hundred ms instead of one sample per RPC frame.
- Auth: same JWT interceptor chain as the existing streams.

The mobile side has to:

1. Produce a unified `BioSample` event from heterogeneous sources.
2. Decouple **source of data** (Neiry headband, Garmin watch, Polar strap, ...) from **kind of data** (cardio, emotions, nfb, ...).
3. Stream samples only while a module session is active and unpaused.
4. Batch and back-pressure correctly.

---

## Locked decisions

### 1. Stream lifecycle is tied to the session, not the device

Biometric samples without an `activity:start` anchor are noise — there is no instruction context to join them to. So:

- **Start** streaming when the user begins a module session (`activity:start` accepted by the server). Not when the BCI device connects.
- **Stop** streaming when the session ends (`activity:end`, `activity:stop`, abandon, server kick).
- **Pause** the upload pipeline when the user pauses the session, **resume** on unpause. Samples produced during the pause window are dropped on the floor, not buffered. Reason: during pause the user is doing something undefined; data is unanalysable, sessions with paused windows already carry lower analytic weight, so we don't even ship the bytes.
- A device may be connected with no active session — samples are still produced for live UI (`BciDataScreen` keeps working), but the upload pipeline does not consume them.

### 2. Split by device class AND by capability — two independent axes

This is the central design decision. The temptation is to either (a) put everything behind one BCI-shaped interface (today's state — works for Neiry only) or (b) name every interface after the vendor that happens to exist today (Neiry-only). Both are wrong. The right split is two orthogonal axes:

**Axis 1 — device class** (what kind of hardware this is):
- `IBciDeviceProvider` — anything in the EEG-headband class. Owns the concerns that make a device "a BCI": scan, connect/disconnect, calibration, impedance/signal-quality, battery. Generic by design, ready for a second BCI vendor (Muse, OpenBCI, ...) the day one shows up. **Not renamed, not made Neiry-specific.**
- A future class for wrist-worn / chest-strap devices does not need to be invented now. Watches don't have calibration or impedance — they wouldn't borrow anything useful from `IBciDeviceProvider`. When the day comes, give them their own class interface (or none — they may be small enough to live as bare capability sources).

**Axis 2 — capability mixins** (what the device can emit). One interface per kind of stream, hardware-agnostic:
- `IHeartRateSource` → `Stream<CardioData>`
- `IEegBandsSource` → `Stream<BciNfbData>` (NFB classifier band powers)
- `IEmotionsSource` → `Stream<BciEmotionsData>`
- (later) `IBreathRateSource`, `IGsrSource`, `ISpO2Source`, ...

Each capability is a focused mixin/interface, not a giant grab-bag. A device implements whichever capabilities it actually supports.

Concrete compositions:
- `NeiryBciProvider implements IBciDeviceProvider, IHeartRateSource, IEegBandsSource, IEmotionsSource` — does everything today.
- A future EEG-only headband: `implements IBciDeviceProvider, IEegBandsSource`. No cardio.
- A future Garmin watch: `implements IHeartRateSource` only. Doesn't pretend to be a BCI.

**The router and uploader subscribe to capability interfaces, not to specific providers.** Logic becomes "give me every registered `IHeartRateSource`," never "give me the BCI and the watch." Adding a second BCI: implement `IBciDeviceProvider` + relevant capabilities, register it, done — router code untouched. Adding a watch: implement `IHeartRateSource`, register it, done.

**Layer C — multiplexer** (`BioStreamRouter` — name TBD):
- Holds a registry of active capability sources.
- Merges streams of the same capability across sources, with an explicit dedup policy (e.g. if both Neiry and a watch supply HR, prefer the watch — dedicated sensors are more accurate. Policy must live in code, not be implicit.)
- Exposes one combined `Stream<BioSample>` to the uploader.

**Layer D — uploader** (`BiometricStreamClient`):
- Subscribes to the router's combined stream.
- Batches in a sliding window (target: 200–500 ms flush, max batch size ~50 — see `neiry_kit/.ai-factory/notes/22-classifier-callback-rates-and-data-ranges.md`).
- Holds one bidi gRPC stream to `ModuleBiometricStreamService`.
- Only runs while there is an active, non-paused module session.

**On naming the data models.** `BciCardioData` is misnamed — cardio is not EEG-derived, it just happens to come from a BCI today. Rename to `CardioData`, move out of `lib/Bci/Models/` into `lib/Biometrics/Models/`. `BciNfbData` and `BciEmotionsData` keep the `Bci` prefix — they are EEG-classifier outputs by definition; a non-BCI device cannot produce them.

### 3. Sample envelope on the wire

Each `BioSample` shipped to the API carries:

| Field | Source | Notes |
|---|---|---|
| `session_id` | injected by uploader from current `ModuleSession.id` | required |
| `timestamp` | client unix-ms at sample production time | required, **must** be the production timestamp from the device callback, not the batch-send time |
| `sample_type` | tag set by the producer adapter | free string. Current values: `cardio`, `emotions`, `nfb`. New values are added by writing the adapter; no proto change. |
| `data` | `google.protobuf.Struct` | producer-defined shape; see schema notes below |

No `module_id` field — `moduleSessionId` already implies `activityType` via `module_sessions.activityType`, and biometric samples are not module-specific anyway.

### 4. Per-type `data` schemas — owned by the mobile side

The API stores `data` as opaque jsonb. The mobile side is the source of truth for the shape. Versioning is informal for now (add a `v` field if a breaking shape change is ever needed — until then assume v1). Initial shapes:

**`sample_type: "cardio"`**

```
{
  "heartRate": double,           // bpm
  "metricsAvailable": bool,
  "hasArtifacts": bool,
  "hrv": {                       // optional — present when source can compute HRV
    "rmssd": double | null,
    "sdnn":  double | null,
    "pnn50": double | null,
    "lf":    double | null,
    "hf":    double | null,
    "lfhf":  double | null
  },
  "source": "neiry" | "garmin" | "polar" | "apple_health" | ...   // device family
}
```

The `source` field is **mandatory** — without it the analytics layer cannot tell whether two cardio samples in the same session came from the same sensor. It is the only place the source hardware is identified per-sample.

HRV must be added to `BciCardioData` / `CardioData` **now**, even if Neiry doesn't ship all six indices yet — the field is optional, the API doesn't care if half are null. The point is not to retro-fit the model when Garmin/Polar arrives.

**`sample_type: "emotions"`**

```
{
  "attention":        double | null,    // 0..1
  "relaxation":       double | null,
  "cognitiveLoad":    double | null,
  "cognitiveControl": double | null,
  "selfControl":      double | null,
  "source": "neiry"
}
```

**`sample_type: "nfb"`**

```
{
  "delta": double | null,    // 0..1, raw classifier output
  "theta": double | null,
  "alpha": double | null,
  "smr":   double | null,
  "beta":  double | null,
  "source": "neiry"
}
```

NFB output is **classifier-aggregated at ~5 Hz**, not raw EEG (250 Hz). It is compact and worth keeping. Raw EEG samples are explicitly out of scope — we are not building a research-grade EEG ingestion pipeline.

### 5. What we explicitly do NOT send

- Raw EEG (~250 Hz)
- Raw PPG (~3.3 Hz)
- Signal quality / impedance (`signalQualityStream`) — live UI only
- Battery (`batteryStream`) — live UI only
- Calibration data (`IndividualNfbData`) — local-only persistence, see `lib/Bci/` calibrator TODO
- `PhysiologicalStates` (once per 2 minutes; not useful yet)
- Productivity scores (unbounded floats, no agreed schema yet)

These can be added later by writing a new producer adapter and assigning a new `sample_type`. No protocol change needed.

### 6. Rate and batching budget

From `neiry_kit/.ai-factory/notes/22-classifier-callback-rates-and-data-ranges.md`:

| Source | Rate |
|---|---|
| NFB | 5 Hz |
| Emotions | 5 Hz |
| Cardio (Neiry) | 3.3 Hz |

Combined: ~13 samples/sec while a Neiry headband is the only source. Well below the 50 samples/sec backpressure hint from the API.

Batcher policy:
- Flush every 250 ms **or** when batch size reaches 25, whichever comes first.
- Drop on overflow only if the bidi stream is wedged; surface a structured warning, do not crash.
- On stream error / disconnect, hold samples in a bounded in-memory ring (~5 seconds worth, ~75 samples) and replay on reconnect — same lifetime tactic the instruction stream uses.

### 7. Pause semantics

When the session is paused:
- The uploader **stops** consuming from the router.
- In-flight batch is flushed.
- Samples produced during the pause are **dropped on the floor**, not buffered.
- On resume, the uploader resubscribes fresh; the first batch reflects post-resume samples only.

This is symmetric with the instruction stream blocking `breath_phase` while paused. Server-side validation may or may not enforce this — that is the API's call, not ours. The mobile side simply does not produce.

### 8. Single uploader per app instance

The bidi gRPC stream is a singleton inside the app's gRPC channel, like `ModuleInstructionStream`. Reconnect / auth refresh / network swap are handled by the existing `GrpcConnectionManager`. Do not stand up a per-session stream.

---

## Refactors and module boundaries to act on

Doing these splits now is cheap; doing them after a second device lands is expensive. None of these are renames-for-renaming's-sake — each one removes a coupling that would otherwise force ugly choices later.

1. **Extract three capability mixins from `IBciDeviceProvider`.** Pull the `cardioStream`, `nfbStream`, `emotionsStream` getters out of `IBciDeviceProvider` and put each into its own interface: `IHeartRateSource`, `IEegBandsSource`, `IEmotionsSource`. `IBciDeviceProvider` keeps only the device-class concerns (scan / connect / disconnect / calibration / impedance / battery / connectionState). `NeiryBciProvider` declares all four interfaces in its `implements` clause — the body of the class barely changes. This is the load-bearing refactor; everything else hangs off it.

2. **Move cardio data out of `lib/Bci/`.** New home: `lib/Biometrics/Models/CardioData.dart`. Delete `BciCardioData` (no alias — internal, one repo, do it cleanly). `IHeartRateSource` lives next to its data model under `lib/Biometrics/`, not under `lib/Bci/`. `BciNfbData` and `BciEmotionsData` stay under `lib/Bci/Models/` — they are EEG-specific by definition.

3. **Keep `IBciDeviceProvider` generic.** Do not rename it to `INeiryDeviceProvider`. The interface shape is already vendor-neutral; only its over-broad responsibility (forcing cardio + NFB + emotions on every implementor) was wrong, and step 1 fixes that. A second BCI vendor (Muse, OpenBCI) plugs into the same interface.

4. **Introduce `lib/Biometrics/`** as the home for hardware-agnostic concerns: capability interfaces (`IHeartRateSource`, ...), data models that aren't EEG-specific (`CardioData`), the router, the uploader, the gRPC client wrapper. `lib/Bci/` keeps Neiry/BCI-specific things only: `IBciDeviceProvider`, `NeiryBciProvider`, EEG-derived data models (`BciNfbData`, `BciEmotionsData`), calibration types.

5. **`BciNotifier` event names** that carry cardio (`BciCardioUpdated`) stay on the notifier for live `BciDataScreen` UI, but the **uploader** must not read from there — it subscribes to capability sources via the router. Don't make the upload path depend on a UI-facing notifier; the two pipelines (live UI, server upload) have different consumers and lifetimes.

---

## Non-goals for this milestone

- Shipping a second BCI provider or any watch/HRM provider. The goal is **architectural readiness**: the day either lands, integration must be "implement the relevant capability interface(s) and register" — no router/uploader changes, no schema changes.
- Server-side calibration sync.
- Multi-device merging logic beyond the simplest priority rule for HR dedup (and even that policy can be a hard-coded constant until a second cardio source actually exists).
- A retry/redelivery guarantee for samples lost in the bidi stream. Best-effort, like the instruction stream. Bio samples are sampled densely; losing a handful does not break analysis.
- Backwards compatibility for the refactors — internal, one repo, do it cleanly.

---

## Open questions for the mobile agent to bring back

1. Does `CardioClassifier` from `neiry_kit` actually expose HRV indices (RMSSD/SDNN/LF/HF), or only `heartRate`? If only HR, decide whether we compute RR-interval HRV on the phone or wait for the kit to ship it. (HRV may well arrive via a Garmin/Polar before Neiry — the schema accommodates either path.)
2. Where does the uploader's session-lifecycle subscription hook in — directly to `ModuleStateChannel` events, or via a new domain-level "current session" observable? (The latter is cleaner; the former is one less abstraction.)
3. Naming: capability interfaces (`IHeartRateSource` vs `ICardioSource`; `IEegBandsSource` vs `INfbSource`), the router (`BioStreamRouter` vs `BiometricSourceRegistry`), the uploader (`BiometricStreamClient` vs `BioStreamClient`). Pick once, stick with it.
4. Registry shape for capability sources — DI-managed list, an explicit registrar service, or hard-wired in `App.dart` while there is only one provider? Pick the simplest thing that won't need to be torn out when a second source lands.

---

## Cross-reference

- Server side: `mind_api/.ai-factory/ROADMAP.md` Phase 17 (to be written) — `ModuleBiometricStreamService` + `bio_session_samples`.
- Existing instruction stream as architectural mirror: `mind_api/src/realtime/module-instruction-stream.grpc.controller.ts`, `mind_api/src/realtime/services/stream-engine.service.ts`, `mind_api/docs/realtime/instruction-model.md`.
- Rate measurements: `neiry_kit/.ai-factory/notes/22-classifier-callback-rates-and-data-ranges.md`.
- Current Neiry adapter: `lib/Bci/NeiryBciProvider.dart`.
- Current data models being renamed: `lib/Bci/Models/BciCardioData.dart`, `lib/Bci/IBciDeviceProvider.dart`.
