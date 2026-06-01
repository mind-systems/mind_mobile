# Plan: Cap the gRPC reconnect backoff exponent

## Context
Clamp the reconnect backoff exponent in `GrpcConnectionManager._nextDelay` so `math.pow(2, attempt)` cannot overflow the `Duration` microsecond int64 after a long outage (many failed attempts).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Clamp the exponent

- [x] **Task 1: Cap the backoff exponent at the source**
  Files: `lib/Core/Grpc/GrpcConnectionManager.dart`
  In `_nextDelay()` (around line 116-127), replace the unbounded exponent computation. Currently:
  ```dart
  final base = _initialDelay * math.pow(2, _reconnectAttempt);
  ```
  Change to clamp the exponent before the power, so the multiplier never overflows:
  ```dart
  final exp = math.min(_reconnectAttempt, 6);
  final base = _initialDelay * math.pow(2, exp);
  ```
  Leave the rest of the method unchanged: the `< _maxDelay` clamp, the jitter calculation, the `_reconnectAttempt++` increment (still used by the log line at line 134), and the final `Duration` return. `2^6 = 64s` already exceeds the 30s `_maxDelay`, so normal-range behavior is unchanged — this only prevents overflow at high attempt counts.

## Notes
- Single-file, single-commit change. No commit plan needed.
- Confirm `math` is imported (`import 'dart:math' as math;`) — it already is, since `math.pow` and `math.Random` are used in the same method.
