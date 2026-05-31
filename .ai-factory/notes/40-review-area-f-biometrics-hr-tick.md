# Code Review — Area F: Biometric Stream Pipeline + Heart-Rate Tick (Phases 21, 22)

**Date:** 2026-05-31
**Source:** conversation context (roadmap review, branch `bci-integration`)
**Scope:** `lib/Biometrics/{BioSample,BioStreamRouter,BiometricBatcher,BiometricStreamClient,ActiveRrSource}.dart` + capability mixins; `lib/BreathModule/{SwitchableTickService,HeartRateTickService,ClockTickService}.dart`

## Verdict

Well-built, layered pipeline — the producer→router→batcher→client chain and the two-policy RR split (server-merge via `BioStreamRouter` vs client-active via `ActiveRrSource`) are clean and match the architecture notes. Timestamp discipline (SDK clocks, never `DateTime.now()`) is honored everywhere. One real robustness gap in the stream client's reconnect; the rest are low/info.

## Key Findings

- **[Medium-low] `BiometricStreamClient` reconnect has no backoff and is uncoordinated with `GrpcConnectionManager`.** `sendBatch` runs every ≤250 ms during a session and calls `_ensureSinkOpen()` at the top; after a stream `onError`/`onDone` tears the sink down (`_sink = null`), the very next batch reopens immediately. During a real server/transport outage this re-opens `streamData` every 250 ms with no cooldown — network/battery thrash. The other streams (`ModuleStateChannel`, `ModuleInstructionStream`) route reconnects through `confirmConnected`/`scheduleReconnect` exponential backoff; this client opens its own bidi stream directly and ignores that machinery. Consider gating reopen on `GrpcConnectionManager.connectionState == connected`, or a minimum reopen interval.

## Details

### Lower-severity / info
- **[Low / info] Sink persists across module sessions.** `ModuleSessionEnded`/`Abandoned` clears `_currentSessionId` and the replay ring but does **not** close `_sink`/the bidi stream. The next session reuses the same open stream; correctness is fine because each wire `BioSample` carries its own `session_id`, so the server routes per-sample. Intentional reuse, but the bidi stream is effectively app-lifetime (only `dispose()` closes it). Flag only if the server expects one stream per session.
- **[Low] Idle batching churn.** Sources (nfb/emotions/cardio/rr/motion) emit continuously whenever the BCI is connected, regardless of an active module session. With no session, `BiometricBatcher` still buffers + arms 250 ms timers + calls `sendBatch`, which returns early before encoding (silent drop). Cheap (no proto encode), bounded, but MEMS motion (batched, higher rate) fills the 25-sample buffer quickly → frequent no-op flushes. Negligible; could short-circuit the batcher when no session is active if it ever matters.
- **[Low / doc] "Clock ticks always → zero first-tick lag on switchback" is slightly inaccurate.** In `SwitchableTickService`, the clock subscription is cancelled while heartbeat is active, so switching back waits for the clock's next periodic tick (up to ~1 interval). The clock keeps ticking internally, but ticks aren't delivered while unsubscribed. Not a defect — just an over-stated comment/spec.

### Verified correct
- `BioSample` factories: every `timestampMs` derives from the domain model's SDK timestamp (`*.timestamp.millisecondsSinceEpoch`) — no `DateTime.now()`. `source` tag on cardio/rr/motion from `*.source.name`; nfb/emotions hard-code `'neiry'` with a documented "add source field later" note. `hrv` sub-map included only when non-null. No `sessionId` (injected at wire time).
- `ActiveRrSource`: preferred-with-fallback — `_onInterval` forwards only the active index, steals back to a higher-priority source on revival (`index < _activeIndex`); watchdog window = `max(2s, lastIntervalMs × 2)`; `_onSilence` walks the list for a source seen within the 2s floor, else flips `hasActiveSource → false`. Single-source path (the real Neiry-only case) correctly goes inactive on silence. Artifacts forwarded + logged (MVP, filter slot documented). `dispose()` does not dispose the App-owned sources.
- `SwitchableTickService`: `trySwitchTo(heartbeat)` returns `false` when `!_heart.hasActiveSource` (caller shows the alert); auto-fallback via `hasActiveSourceStream` (no spurious switch on the seeded `false`); `sourceChanges` is the single source of truth for `state.tickSource` (manual toggle + auto-fallback share one path); `dispose()` propagates to clock + heart.
- `HeartRateTickService`: maps `RrInterval → TickData(intervalMs)`; `dispose()` cancels its own sub but **not** the shared `ActiveRrSource`.
- `BioStreamRouter`: lazy cached `Rx.merge(...).asBroadcastStream()`; register-before-subscribe invariant documented and honored by `App.initialize()`; no dedup by design (server aggregates by `source` tag). All five capabilities registered to the one `NeiryBciProvider` instance.
- `BiometricBatcher`: flush on size (25) or 250 ms deadline; `List.unmodifiable` snapshot before clear; final best-effort `_flushNow()` on dispose.
- `BiometricStreamClient` replay ring: bounded drop-oldest (75); on reopen, the ring drains via `_encodeAndAdd(replay)` **before** the current `sendBatch` encodes its new samples — ordering (old-then-new) preserved.

## Open Questions

- Should biometric stream reconnect ride on `GrpcConnectionManager`'s backoff/connection state instead of reopening per-batch? Cheapest fix: a `_lastReopenAttempt` timestamp gate (note: `DateTime.now()` is fine here — this is wall-clock retry control, not a physiological sample timestamp).
- Does the server tolerate one app-lifetime bidi stream carrying multiple sessions' samples (per-sample `session_id`), or does it expect a fresh stream per session?
