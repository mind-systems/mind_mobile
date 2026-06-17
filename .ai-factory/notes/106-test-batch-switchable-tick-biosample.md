# SwitchableTickService + BioSample Factories — Test Batch

**Date:** 2026-06-17
**Source:** roadmap-decompose

## Key Findings

- Two independent test files, no shared fakes; neither requires infra refactor — both classes are testable as-is.
- Implementation detail for each class is fully documented in the dedicated research notes; this batch note is the entry point for the implementing agent.
- Both have zero existing test coverage.

## Details

### File 1: `test/BreathModule/switchable_tick_service_test.dart`

**Source:** `lib/BreathModule/SwitchableTickService.dart`
**Research note:** `.ai-factory/notes/91-test-plan-switchable-tick-service.md`

Key test groups (summary — full spec in note 91):
1. **Initial source** — `source == timer` on construction; clock ticks forwarded, heart ticks ignored.
2. **trySwitchTo** — returns `true` and switches when `heart.hasActiveSource == true`; returns `false` otherwise; no-op if already on target.
3. **Auto-fallback** — when `hasActiveSourceStream` emits `false` while active is heartbeat, reverts to clock and emits `TickSource.timer` on `sourceChanges`.
4. **Dispose** — cancels subscriptions, closes controllers, propagates dispose to delegates.

Fakes needed:
- `_FakeClockTickService`: implements `ITickService`, injectable `StreamController<TickData>`.
- `_FakeHeartRateTickService`: same, plus injectable `bool hasActiveSource` and `StreamController<bool>` for `hasActiveSourceStream`.

---

### File 2: `test/Biometrics/bio_sample_factories_test.dart`

**Source:** `lib/Biometrics/BioSample.dart`
**Research note:** `.ai-factory/notes/94-test-plan-biosample-factories.md`

Key test groups (summary — full spec in note 94):
1. **fromCardio** — `timestampMs = cardio.timestamp.millisecondsSinceEpoch`, `sampleType == 'cardio'`, HRV sub-map absent when `cardio.hrv == null`, present when non-null.
2. **fromRr** — correct SDK timestamp, `data['intervalMs']` and `data['isArtifact']` present, artifact forwarded as-is.
3. **fromNfb** — correct timestamp, `sampleType == 'nfb'`, all band fields present.
4. **fromEmotions** — timestamp, all emotion fields.
5. **fromMotion** — per-sample SDK timestamp (not wall-clock), all six axes, `sampleType == 'motion'`.

No fakes needed — all five factory methods are pure functions; construct domain models directly.
