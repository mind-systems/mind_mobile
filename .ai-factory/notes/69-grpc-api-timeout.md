# Add Timeout to gRPC Unary Calls in UserApi and StatsApi

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- `GrpcConnectionManager.connect()` emits `connected` immediately without waiting for actual TCP/TLS handshake — gRPC calls fired right after can hang indefinitely (no default timeout in the Dart gRPC package).
- Confirmed by logs: `[_loadSuggestions] start` and `[_loadStats] start` appear with no subsequent `done` or `error` line, and `isXxxLoading` stays `true` forever.
- Fix: add `.timeout(const Duration(seconds: 10))` to both unary calls. `TimeoutException` is caught by the existing `catch (e)` in `HomeViewModel`.

## Details

### Problem

`GrpcClientChannel` in Dart connects lazily on the first RPC call. `GrpcConnectionManager.connect()` sets state to `connected` synchronously before any TCP connection exists. `_loadInitialData()` fires via `Future.microtask` immediately after `build()`, so the gRPC calls start before the channel is ready. Without a timeout they hang until the OS TCP timeout (~75 s on mobile).

### Fix

**`lib/User/UserApi.dart` — `fetchSuggestions`:**
```dart
final response = await _breathSessionService
    .getSuggestions(bsProto.GetSuggestionsRequest(timeOfDay: _mapTimeOfDay(timeOfDay)))
    .timeout(const Duration(seconds: 10));
```

**`lib/User/StatsApi.dart` — `fetchStats`:**
```dart
final response = await _statsService
    .getStats(statsProto.GetStatsRequest())
    .timeout(const Duration(seconds: 10));
```

No import changes needed — `timeout()` is a `Future` extension from `dart:async`, already available.

### Files to change

| File | Method |
|------|--------|
| `lib/User/UserApi.dart` | `fetchSuggestions` |
| `lib/User/StatsApi.dart` | `fetchStats` |

### Standalone behavior

With this task alone (no catch-block changes): after 10 s the `TimeoutException` propagates to `HomeViewModel._loadSuggestions` / `_loadStats`, the existing `catch (e)` resets `isXxxLoading = false`, and the areas collapse. Not ideal UX (shimmer disappears instead of persisting), but prevents the infinite-hang. The follow-up task (note 70) improves the catch behavior.

## Verify

With server unreachable: shimmer appears, then after ~10 s areas collapse. Console shows `[_loadSuggestions] error — TimeoutException`. No hang beyond 10 s.
