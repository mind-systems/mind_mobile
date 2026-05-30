# Code Review: Sync calibration history from server when BCI screen opens

**Plan:** `91-sync-calibration-history-from-server-when-bci-screen-opens.md`
**Scope:** `lib/Bci/NfbCalibrationRepository.dart`, `lib/Bci/BciDeviceManager.dart`
**Risk:** 🟢 Low — additive, fire-and-forget, no new wiring.

## Summary

Both tasks implemented as specified:

- **Task 1** (`NfbCalibrationRepository.refreshFromServer`): calls `_api.list(serial)`, trims to `_maxEntries` (20), encodes with the same `e.toJson()` shape as `record()`, writes under the same `_keyFor(serial)` key. Wrapped in a single `try`/`catch (Object e)` that logs and swallows — never rethrows.
- **Task 2** (`BciDeviceManager.startScan`): added a synchronous `for (final serial in _repository.cachedSerials())` loop directly after the `fetchKnownSerials` fire-and-forget block, firing-and-forgetting `refreshFromServer(serial)` per entry with a defensive `.catchError` logging line.

## Verification

- `_keyFor(serial)` and JSON shape match `record()` (`NfbCalibrationRepository.dart:43-50`) — refreshed data round-trips through `history(serial)` correctly.
- `_api.list(serial)` returns `Future<List<NfbCalibrationData>>` already mapped from proto (`NfbCalibrationGrpcApi.dart:28-34`) — no extra conversion needed.
- Empty `cachedSerials()` → loop iterates zero times → no API call on fresh install. Confirmed.
- `cachedSerials()` is a synchronous in-memory read (`BciDeviceRepository.cachedSerials()`), safe to call inline in `startScan()`.
- Loop runs before `final cachedSerials = _repository.cachedSerials();` (re-read for auto-connect logic). Dart is single-threaded — the loop completes before any async event interleaves, so no concurrent-modification risk.
- No `await` in the new loop — scanning is not blocked by sync.
- Calibration auto-restore via `latestValid(serial)` in `connectDevice()` will pick up freshly synced data on subsequent connects.

## Findings

None that require changes. The following are observations carried over from the plan review and confirmed against the implementation; all are accepted trade-offs:

1. **First-scan-after-fresh-install is a no-op.** `fetchKnownSerials()` is fire-and-forget, so `cachedSerials()` returns `[]` on the very first scan after a clean install even when the server has serials. The user must open the BCI screen a second time before history syncs. Plan describes this as intended ("first BCI screen open on a fresh install → cache empty → no refresh triggered").
2. **`latestValid` ordering depends on server.** `latestValid(serial)` iterates from index 0 and returns the first valid entry, so the server must return history newest-first for the auto-restore in `connectDevice()` to pick the most recent valid calibration. Outside this milestone's scope; flagging only.
3. **Concurrent refresh vs record race.** If a `record()` runs while `refreshFromServer` is in flight, last-writer-wins on `SharedPreferences.setString`. Acceptable: in practice `startScan` → refresh fires before any calibration completes, and any lost local entry was already mirrored to the server via `record()`'s unawaited `_api.record` call.
4. **Double error swallow.** `refreshFromServer` catches internally and the outer `.catchError` at the call site duplicates that. Plan explicitly notes this redundancy as a style match with the existing `fetchKnownSerials` pattern.

## Positive

- Clean separation: repository owns sync, manager only triggers it.
- Error handling pattern matches existing `fetchKnownSerials` / `record` precedent (consistent style).
- No `dispose()`, no streams, no new state — additive only.
- No new `App.dart` wiring; dependencies already constructor-injected.
- No schema/migration impact (same SharedPreferences key, same JSON shape).
- No security regression — same auth-gated gRPC channel.

REVIEW_PASS
