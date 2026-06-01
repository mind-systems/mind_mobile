# Code Review — Rate-limit `BiometricStreamClient` stream reopen (review 2)

**Scope:** `lib/Biometrics/BiometricStreamClient.dart` (only code change in the diff; the other staged files are plan/plan-review/review docs).

## Summary

The implementation correctly adds a 2-second reopen cooldown to `_ensureSinkOpen()`, and — relative to review 1 — now also resets the cooldown timestamp on session lifecycle transitions. The diff:

- Adds field `DateTime? _lastOpenAttempt;`.
- In `_ensureSinkOpen()`, after the `_sink != null` early return and before creating the `StreamController`, a guard returns early if `now - _lastOpenAttempt < 2s`; otherwise stamps `_lastOpenAttempt = DateTime.now()` before the open attempt.
- Resets `_lastOpenAttempt = null` in `_onLifecycleEvent` on both `ModuleSessionStarted` and `ModuleSessionEnded`/`ModuleSessionAbandoned`.

## Verification

- **Cooldown gating:** during an outage, `_teardownSink()` nulls `_sink`; subsequent batches within 2s hit the guard and return, so samples fall through to `_encodeAndAdd`'s `_sink == null` branch and buffer in the bounded replay ring. Documented ring-loss tradeoff applies as specified. ✓
- **No startup delay:** first open of any session has `_lastOpenAttempt == null` (reset on `ModuleSessionStarted`), so the guard is skipped and the stream opens immediately. ✓
- **Failed-open throttling:** `_lastOpenAttempt` is stamped before the `try`, so the `catch`→`_teardownSink` path is also rate-limited (matches intent). ✓
- **Cross-session carryover (review-1 finding) resolved:** resetting `_lastOpenAttempt = null` on session start and end means a fresh session never inherits a prior session's cooldown window. A new session's first stream open is never spuriously throttled. ✓
- **Sink reuse across end→start:** session end does not tear down the sink; if it is still open when the next session starts, `_ensureSinkOpen` returns early on `_sink != null`, so the timestamp reset is harmless. ✓
- **Null-safety / compile:** `_lastOpenAttempt!` is dereferenced only inside the `!= null` guard; types (`DateTime?`, `.difference()`, `const Duration(seconds: 2)`) are sound. ✓
- **No race:** `_ensureSinkOpen` is fully synchronous — no `await` between the cooldown check and the timestamp assignment. ✓

## Findings

None. The previous review's low-severity finding (cooldown timestamp leaking across session boundaries) has been addressed by resetting `_lastOpenAttempt` on session start and end. The change is correct, minimal, and matches the plan and spec.

REVIEW_PASS
