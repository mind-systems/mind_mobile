# Code Review: Cap the gRPC reconnect backoff exponent

**Branch:** bci-integration
**Files changed:** `lib/Core/Grpc/GrpcConnectionManager.dart` (+1 line net), plus plan/plan-review/json artifacts.

## Scope of code change

```dart
Duration _nextDelay() {
-    final base = _initialDelay * math.pow(2, _reconnectAttempt);
+    final exp = math.min(_reconnectAttempt, 6);
+    final base = _initialDelay * math.pow(2, exp);
     final clamped =
         base.inMilliseconds < _maxDelay.inMilliseconds ? base : _maxDelay;
     ...
```

## Correctness analysis

- **Overflow eliminated.** With `exp` capped at 6, `math.pow(2, exp)` ≤ 64, so `base = _initialDelay (1s) * 64 = 64s`. `64s` in microseconds (64,000,000) is far below the int64 ceiling, so the `Duration` multiply can no longer throw on a sustained outage. The targeted bug is fixed. ✅
- **Behavior preserved in the normal range.** `_maxDelay` is 30s. At `_reconnectAttempt = 5`, `2^5 = 32s` already exceeds the cap, so the post-clamp output is identical whether the exponent is unbounded or capped at 6 for every attempt ≥ 5. The cap only ever alters the *pre-clamp* `base`, never the returned delay. ✅
- **Types.** `_reconnectAttempt` is `int` and `6` is `int`, so `math.min` returns `int`; `math.pow(2, int)` returns `num`, and `Duration operator *(num)` accepts it. No type regression. ✅
- **Untouched logic confirmed.** Jitter calc, `_reconnectAttempt++` (line 124), the final `.clamp(0, _maxDelay)` and the `(attempt $_reconnectAttempt)` log line (line 135) are all unchanged, matching the plan's guards. ✅
- **Import.** `import 'dart:math' as math;` is present (line 3); `math.min` needs no new import. ✅

## Runtime / edge cases

- No race conditions introduced — the method is synchronous and the change is purely arithmetic.
- `clamp(0, _maxDelay.inMilliseconds)` still bounds the negative-jitter case, so the returned `Duration` stays non-negative. ✅
- No migration, serialization, or contract surface touched.

## Notes (non-blocking)

- The cap `6` is a bare literal. A named constant (`static const int _maxBackoffExponent = 6;`) would document why 6 was chosen (it's the smallest exponent whose `2^n` already passes `_maxDelay`). Cosmetic only; the plan scoped this out.

No correctness, security, or runtime defects found.

REVIEW_PASS
