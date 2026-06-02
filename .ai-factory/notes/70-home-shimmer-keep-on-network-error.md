# Keep HomeScreen Shimmer on Network Errors

**Date:** 2026-06-02
**Source:** conversation context

## Key Findings

- Currently `catch (e)` in `_loadSuggestions` and `_loadStats` always resets `isXxxLoading = false` — on a network/timeout error the shimmer disappears and areas collapse, breaking the "shimmer while disconnected" feature.
- Fix: distinguish network errors (`TimeoutException`, `GrpcError` unavailable/cancelled) from real errors; on network errors keep `isXxxLoading = true` so the shimmer persists until `HomeGrpcReconnected` fires and retries.
- Depends on note 69 (timeout added) — without a timeout the `TimeoutException` branch never fires for the hanging case.

## Details

### Problem

`HomeViewModel._loadSuggestions` catch:
```dart
} catch (e) {
  state = state.copyWith(isSuggestionsLoading: false, error: e.toString());
}
```
Any error — including `TimeoutException` (from note 69) or `GrpcError.unavailable` — collapses the area. The intended behavior is: shimmer stays during disconnect, content appears on reconnect (via `HomeGrpcReconnected → _loadInitialData`).

### Fix

**Add helper to `HomeViewModel`:**
```dart
bool _isNetworkError(Object e) =>
    e is TimeoutException ||
    (e is GrpcError &&
        (e.code == StatusCode.unavailable ||
         e.code == StatusCode.cancelled));
```

**Update both catch blocks:**
```dart
} catch (e) {
  if (_isNetworkError(e)) return; // keep isXxxLoading = true
  state = state.copyWith(isSuggestionsLoading: false, error: e.toString());
}
```

**New imports for `HomeViewModel.dart`:**
```dart
import 'dart:async'; // TimeoutException
import 'package:grpc/grpc.dart'; // GrpcError, StatusCode
```

### Files to change

| File | Change |
|------|--------|
| `lib/HomeModule/Presentation/HomeScreen/HomeViewModel.dart` | add `_isNetworkError` helper, update 2 catch blocks, add 2 imports |

### Reconnect path

When device connectivity is restored, `GrpcConnectionManager._connectivitySubscription` fires `connect()` → state transitions `disconnected → connecting → connected` → `HomeService.observeChanges()` pairwise detects the transition → emits `HomeGrpcReconnected` → `_loadInitialData()` retries → on success `isXxxLoading = false`, data shown.

### Guard

`StatusCode` in `package:grpc/grpc.dart` — confirm this import does not conflict with any existing grpc import in the file. If `grpc` is already imported under an alias, reuse that alias.

## Verify

1. Server unreachable → shimmer persists past 10 s (no collapse after timeout).  
2. Server comes back / device reconnects → `HomeGrpcReconnected` fires → data loads → shimmer replaced by content.  
3. Server returns a real error (e.g. `PERMISSION_DENIED`) → areas collapse normally (not treated as network error).
