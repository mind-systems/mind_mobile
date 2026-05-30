# Code Review: 90 — Add `NfbCalibrationGrpcApi` + wire remote sync in `NfbCalibrationRepository`

## Scope of review

Reviewed every code change against `HEAD`:

- `lib/Bci/NfbCalibrationGrpcApi.dart` (new file, 50 lines)
- `lib/Bci/NfbCalibrationRepository.dart` (added `_api` dep, fire-and-forget sync in `record()`)
- `lib/Core/App.dart` (constructs `NfbCalibrationGrpcApi(grpcClient.nfbCalibrationService)` and wires it into the repository)
- `lib/Core/Grpc/GrpcClient.dart` (added `late final nfbCalibrationService`)

Cross-checked against generated proto symbols in `lib/Core/Grpc/generated/nfb_calibration.pb.dart`, the domain model `lib/Bci/Models/NfbCalibrationData.dart`, and the existing analogue `lib/Bci/BciDevicesGrpcApi.dart`.

## Correctness

- **Field mapping `domain → RecordNfbCalibrationRequest`** is exhaustive and ordered: all 11 request fields are populated, `calibratedAt` is serialized via `toIso8601String()` matching the proto's ISO-8601 contract documented in `nfb_calibration.pb.dart:19-20`. No fields silently default to proto3 zero values.
- **Field mapping `NfbCalibrationRecord → domain`** in `_recordToDomain` covers every field the domain model carries; the proto-only `id` and `createdAt` fields are correctly dropped (the domain has no slot for them and the local cache does not need server identity).
- **Return value of `record()`** is intentionally discarded — the comment makes this explicit. Fire-and-forget contract is preserved end to end (`NfbCalibrationGrpcApi.record` returns `Future<void>`; repository wraps with `unawaited(... .catchError(...))`).
- **`list()` is unused this milestone** — exposed per task spec for the next phase's `refreshFromServer`. No dead-code regression.

## Runtime / failure modes

- **Logout-on-`UNAUTHENTICATED` still fires.** The new `record()` call goes through the standard interceptor chain on `_channel`. The `.catchError` at the repository swallows the error *after* `GrpcAuthInterceptor` has already published to `LogoutNotifier`, so the global logout flow is unaffected.
- **`DateTime.parse(r.calibratedAt)` would throw `FormatException` if the server ever returns an empty string** (proto3 default). This is informational only — `list()` has no callers in this milestone, and the Phase 24 follow-up task wraps `refreshFromServer` in `.catchError`, so a bad batch would log-and-skip rather than corrupt the local cache. No change needed now; flagged only so the next-task reviewer keeps it in mind.
- **`failReason` round-trip is unvalidated.** `NfbCalibrationData` documents `"none" | "tooManyArtifacts" | "peakFrequencyAtBorder"` but neither the domain model nor `_recordToDomain` rejects other strings. This is consistent with the existing model (the milestone that created `NfbCalibrationData` did not add runtime validation either), so no regression.
- **Fire-and-forget ordering.** Multiple back-to-back `record()` calls could complete out of order on the wire. Acceptable: server-side history is append-only and is keyed by `calibratedAt`, so reordering does not corrupt state.

## Wiring

- **`GrpcClient`** — `nfbCalibrationService` inserted in the existing alphabetical-by-name block. `late final` pattern + interceptor list usage matches the surrounding 10 service clients exactly.
- **`App.initialize()` ordering** — `nfbCalibrationApi` is constructed after `grpcClient` already exists and after the cold-start sync barrier, before the repository that consumes it. No null-init hazard, no ordering regression.
- **Style** — both new initializers in `App.dart` are single-line with no trailing commas, matching the project convention captured in user memory (`feedback_app_dart_style.md`).
- **Imports** — `dart:async` (for `unawaited`) and `package:mind/Logger.dart` (for `logPrint`) added to `NfbCalibrationRepository.dart`. No unused imports.

## Architecture compliance

- `NfbCalibrationGrpcApi` is pure Dart (no Flutter or Riverpod imports) and owns no state beyond the injected client — matches the `BciDevicesGrpcApi` pattern.
- Domain model `NfbCalibrationData` is the boundary type both into and out of the API class; the proto types never leak past `lib/Bci/NfbCalibrationGrpcApi.dart`.
- Repository keeps SharedPreferences as the read source of truth; remote sync is write-only this milestone, matching the plan's explicit deferral of `refreshFromServer` to the next task.

## No findings.

REVIEW_PASS
