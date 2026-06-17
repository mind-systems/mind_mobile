# BiometricBatcher + ActiveRrSource — Test Batch

**Date:** 2026-06-17
**Source:** roadmap-decompose

## Key Findings

- Two biometrics-pipeline classes in `lib/Biometrics/`; both have injectable timing params added in the Test Infra phase (ROADMAP.md `## Test Infra`), so no further refactor is needed.
- Both use `fake_async` for timer control — include `fake_async` in test imports (`dart pub add dev:fake_async` or verify it's already in `dev_dependencies`).
- Implementation detail for each class is fully documented in the dedicated research notes; this batch note is the entry point.
- Both have zero existing test coverage.

## Details

### File 1: `test/Biometrics/biometric_batcher_test.dart`

**Source:** `lib/Biometrics/BiometricBatcher.dart`
**Research note:** `.ai-factory/notes/93-test-plan-biometric-batcher.md`

Instantiation: `BiometricBatcher(router: fakeRouter, client: fakeClient, flushInterval: Duration(milliseconds: 1), maxBatchSize: 3)` — the two injectable params make timer tests synchronous with `fake_async`.

Key test groups (summary — full spec in note 93):
1. **Size flush** — 3rd sample triggers immediate `sendBatch`; timer cancelled; buffer cleared.
2. **Timer flush** — 2 samples → no flush; advance 1 ms → `sendBatch([2 samples])`.
3. **No duplicate timer** — 2nd sample before deadline does not start a second `Timer`.
4. **Dispose** — flushes remaining buffer, then cancels subscription.
5. **Empty dispose** — no `sendBatch` call when buffer is empty on dispose.

Fakes needed:
- `_FakeBioStreamRouter`: exposes `StreamController<BioSample>` as `samples` stream.
- `_FakeBiometricStreamClient`: records `sendBatch(List<BioSample>)` calls in a list.

---

### File 2: `test/Biometrics/active_rr_source_test.dart`

**Source:** `lib/Biometrics/ActiveRrSource.dart`
**Research note:** `.ai-factory/notes/90-test-plan-active-rr-source.md`

Instantiation: `ActiveRrSource(sources, clock: fakeClock, timerFactory: fakeTimerFactory)` — the two injectable params let tests control time without `fake_async`.

Recommended timer spy pattern:
```dart
List<({Duration delay, void Function() callback})> timers = [];
Timer fakeTimerFactory(Duration d, void Function() cb) {
  timers.add((delay: d, callback: cb));
  return FakeTimer(); // minimal Timer that records cancel() calls
}
```

Key test groups (summary — full spec in note 90):
1. **Initial emission** — first interval from source[0] forwarded; `hasActiveSource → true`.
2. **Priority steal** — source[1] active; source[0] emits → active flips to source[0].
3. **Silence detection** — emit 800 ms interval; invoke captured watchdog callback; no fresh alternative → `hasActiveSource → false`.
4. **Failover** — source[0] silenced; source[1] has recent `_lastSeenAt` → active flips to source[1].
5. **Dispose** — all source subs cancelled, both controllers closed.
