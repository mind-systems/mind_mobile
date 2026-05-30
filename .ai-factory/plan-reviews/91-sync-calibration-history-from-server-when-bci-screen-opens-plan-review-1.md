# Plan Review: Sync calibration history from server when BCI screen opens

**Plan:** `91-sync-calibration-history-from-server-when-bci-screen-opens.md`
**Risk Level:** 🟢 Low

## Context Gates

- **Architecture:** PASS. `NfbCalibrationRepository` lives in the pure-Dart domain layer (`lib/Bci/`), and the trigger sits in `BciDeviceManager` (domain) — no Flutter / Riverpod imports introduced. Boundary discipline is preserved.
- **Rules:** PASS. No Module Service touched (no statefulness regressions). Dependencies (`_nfbCalibrationRepository`, `_repository`) are already constructor-injected; no new wiring from the outside. No changes to `App.dart`.
- **Roadmap:** Not verified against `ROADMAP.md` linkage — milestone 91 is the implied source. No action needed for this scope.

## Critical Issues

None. Plan compiles cleanly against the current code:

- `NfbCalibrationGrpcApi.list(serial)` at `lib/Bci/NfbCalibrationGrpcApi.dart:28` exists and returns `Future<List<NfbCalibrationData>>` mapped from proto records — matches Task 1's assumption.
- `_maxEntries = 20`, `_keyFor(serial)`, and the JSON encoding shape (`e.toJson()` list) all match `record()` at `NfbCalibrationRepository.dart:43-50`, so `history(serial)` will round-trip the refreshed data correctly.
- `BciDeviceManager.startScan()` lines cited in the plan (143–146, 148, 199) align with the current file. Inserting the loop between the `fetchKnownSerials` block and the `cachedSerials()` read is structurally sound.
- `cachedSerials()` is a synchronous in-memory read of SharedPreferences (`BciDeviceRepository.dart:16`) — calling it inside `startScan()` is cheap and safe.
- Empty cache → loop iterates zero times → no spurious API call on fresh install. Confirmed.
- The fire-and-forget `catchError` redundancy is acknowledged in the plan and matches the existing `fetchKnownSerials` style.

## Observations / Minor Notes

These are non-blocking but worth recording.

1. **Fresh-install + remote serials race.** On a fresh install where the server already has registered devices, `startScan()` issues `unawaited(_repository.fetchKnownSerials())` and then immediately reads `cachedSerials()` — which returns `[]` until that future completes. As a result, the calibration refresh is *also* a no-op on this first scan; the user must open the BCI screen a second time (after the serial cache has been hydrated) before history syncs. The plan describes this as "next time the BCI screen opens" which is technically accurate, but the first-time-after-fresh-install delay is worth being explicit about. Alternative (not required): await `fetchKnownSerials()` once before reading `cachedSerials()`, or refresh once `fetchKnownSerials` resolves. The plan's choice to mirror auto-connect (which has the same property) is defensible — flagging only so this isn't a surprise during implementation.

2. **Server ordering assumption.** Task 1 says "preserve server-returned order". `latestValid(serial)` (line 36) iterates from the start of the list and returns the first valid entry, so this is correct **only if the server returns history in descending chronological order** (most recent first). The proto API (`ListNfbCalibrationsRequest` with `limit: 50`) is not inspected here, but `record()`'s local pattern (`[data, ...existing]`) also assumes newest-first. Implementation should verify the server endpoint matches that ordering; if it returns ascending, `latestValid` will pick the wrong entry. Worth a quick sanity check during implementation, not a plan blocker.

3. **Unconditional replace loses unsynced local entries.** Plan explicitly states this is intentional ("server is authoritative"). Note: a calibration recorded while offline goes through `record()` which writes locally *and* fires `_api.record` unawaited; if that API call silently fails, the next `refreshFromServer` will overwrite the unsynced local entry. Accepted trade-off per the plan, but the implementer should be aware that `record()`'s fire-and-forget remote write is the only thing keeping local-only entries from being lost on the next sync.

4. **No concurrency guard on overlapping refreshes.** If the user opens / closes / re-opens the BCI screen quickly, two `refreshFromServer` calls for the same serial may interleave. Last writer wins on `SharedPreferences.setString`, both write near-identical data — acceptable, but worth noting. No fix required.

5. **Logging volume.** Settings say "minimal" logging. The plan adds two error-only `logPrint` lines (repository internal catch + `catchError` at the call site) — both quiet on the happy path. Aligned with settings.

## Positive Notes

- Clean separation: repository owns the sync mechanics; manager only triggers it. No coupling regression.
- File paths and line numbers all verified against current source.
- API surface (`_api.list`, `latestValid`, `cachedSerials`) used correctly, no invented methods.
- Error handling pattern matches the existing `fetchKnownSerials` / `record()` precedent — consistent with the established style in this file.
- No migrations required (SharedPreferences key is unchanged, JSON shape is unchanged).
- No security concerns — same auth-gated gRPC channel used everywhere else.

PLAN_REVIEW_PASS
