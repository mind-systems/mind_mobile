# Code Review — Rate-limit `BiometricStreamClient` stream reopen (review 1)

**Scope:** `lib/Biometrics/BiometricStreamClient.dart` (only code change in the diff; the other staged files are plan/plan-review docs).

## Summary

The change implements the spec faithfully: a `DateTime? _lastOpenAttempt` field plus a 2-second cooldown guard at the top of `_ensureSinkOpen()`, placed after the `_sink != null` early return and before the `StreamController` is created. The timestamp is stamped before the `try`, so a failed open (the `catch`→`_teardownSink` path) is also rate-limited — matching the plan's intent.

Verified correct:
- **Null-safety / compile:** `_lastOpenAttempt!` is dereferenced only inside the `_lastOpenAttempt != null` guard. Types (`DateTime?`, `.difference()`, `const Duration(seconds: 2)`) are sound.
- **First open is not delayed:** `_lastOpenAttempt == null` on the first call skips the guard, so session start opens the stream immediately.
- **Outage throttle works:** after `_teardownSink()` nulls `_sink`, batches within the cooldown window return early; `_encodeAndAdd` then takes its existing `_sink == null` branch and buffers to the replay ring. The documented ring-loss tradeoff applies as specified.
- **Healthy-then-drop reconnect:** when a stream that ran longer than 2s drops, `now - _lastOpenAttempt > 2s`, so the first reconnect is immediate (no spurious delay).
- **No race:** `_ensureSinkOpen` is fully synchronous; there is no `await` between the cooldown check and the timestamp assignment.

## Findings

### Low — cooldown timestamp persists across session boundaries

`_lastOpenAttempt` is never cleared. It is not reset on `ModuleSessionEnded` / `ModuleSessionAbandoned` (`_onLifecycleEvent`, lines 61-64) nor on a new `ModuleSessionStarted`, and `_teardownSink()` intentionally preserves it (correct for the outage case).

Consequence: if a stream-open attempt happens late in session A (e.g. an outage tears the sink down at time T), and a **new** session B starts and emits its first batch within 2s of T, that first `_ensureSinkOpen()` for session B is throttled. The stream does not open until the window elapses, and session B's leading samples buffer in the replay ring (and can overflow it — same ~75-sample bound) for up to 2s, despite there being no actual outage at that moment.

This is a minor, low-likelihood edge (it requires two sessions to begin within ~2s of a prior open attempt) and degrades gracefully (buffering + bounded ring loss, not a crash). It is arguably outside the spec's intent, since the cooldown is meant to throttle outage reconnects, not gate a fresh session's first connection.

Suggested fix (optional, if desired): reset `_lastOpenAttempt = null;` in the `ModuleSessionEnded() || ModuleSessionAbandoned()` case (and/or on `ModuleSessionStarted`) so each session starts with a clean cooldown. If the maintainers consider this acceptable for the "conservative interim" milestone, it can be deferred — but it should be a conscious choice rather than an accident.

## Verdict

No blocking bugs. The implementation is correct for its primary purpose and matches the plan. The single finding above is a low-severity behavioral edge worth a deliberate decision (reset the timestamp on session lifecycle transitions, or explicitly accept the cross-session carryover).
