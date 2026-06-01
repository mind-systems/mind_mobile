# Plan: Rate-limit `BiometricStreamClient` stream reopen

## Context
Add a 2-second reopen cooldown to `_ensureSinkOpen()` in `BiometricStreamClient` so that during a server/transport outage it stops thrashing `streamData` reconnects every ~250 ms; blocked samples fall through to the existing bounded replay ring.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Reopen cooldown

- [x] **Task 1: Add reopen-attempt timestamp field**
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  Add a private field `DateTime? _lastOpenAttempt;` alongside the existing sink/ring state fields (near `_sink` / `_responseSub`, around lines 31-38). This tracks the wall-clock time of the last stream-open attempt for cooldown gating. `DateTime.now()` is intentional here — it is retry/backoff control, not a sample timestamp.

- [x] **Task 2: Apply 2s cooldown guard in `_ensureSinkOpen`** (depends on Task 1)
  Files: `lib/Biometrics/BiometricStreamClient.dart`
  In `_ensureSinkOpen()` (currently lines 85-134), after the existing `if (_sink != null) return;` early return and **before** creating the new `StreamController`, add a cooldown guard:
  ```dart
  if (_lastOpenAttempt != null &&
      DateTime.now().difference(_lastOpenAttempt!) < const Duration(seconds: 2)) {
    return;
  }
  ```
  When the guard returns early, `_sink` stays `null`, so `_encodeAndAdd` takes its existing `_sink == null` branch and enqueues samples into the replay ring — no extra handling needed.
  Immediately after passing the guard (i.e. when an open is actually being attempted), set `_lastOpenAttempt = DateTime.now();`. Place this assignment before `_sink = StreamController(...)` so a failed open (the existing `catch` → `_teardownSink()` path) still records the attempt and is rate-limited.
  Leave the existing replay-ring drain block (the `_currentSessionId != null` → `_encodeAndAdd(replay)` at the end of the method) unchanged so a successful open still flushes buffered samples.

## Notes
- **Single file, single concern** — one commit at the end. No commit checkpoints needed.
- **Tradeoff (documented in spec note 48):** the cooldown does not add sample loss. During an outage the stream cannot send regardless; samples overflow the bounded replay ring (`_replayRingMax = 75`) the same way with or without the cooldown. Resizing the ring for worst-case outages is a separate task, out of scope here.
- The larger "ride on `GrpcConnectionManager` backoff" alternative stays deferred in note 43 (Q4); this milestone is the conservative interim only.
