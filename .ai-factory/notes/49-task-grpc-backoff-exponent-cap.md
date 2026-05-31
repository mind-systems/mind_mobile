# Task Spec — Cap the gRPC reconnect backoff exponent

**Date:** 2026-05-31
**Roadmap:** ROADMAP.md Phase 26
**Provenance:** note 42 Task 4 (note 37 Area C)

## Current state
`lib/Core/Grpc/GrpcConnectionManager._nextDelay()` computes `base = _initialDelay * math.pow(2, _reconnectAttempt)` and clamps only the result. `_reconnectAttempt` is unbounded (resets only on `confirmConnected()`), so after ~50+ failed attempts `pow(2, attempt)` overflows the `Duration` microsecond int64 before the clamp.

## Target
Clamp the exponent at the source:
```
final exp = math.min(_reconnectAttempt, 6);
final base = _initialDelay * math.pow(2, exp);
```
`2^6 = 64 s` already exceeds the 30 s `_maxDelay`, so normal-range behavior is unchanged.

## Guards
- Leave the `_reconnectAttempt++` increment as-is (still used for the log line).

## Files
- `lib/Core/Grpc/GrpcConnectionManager.dart` (one file).
