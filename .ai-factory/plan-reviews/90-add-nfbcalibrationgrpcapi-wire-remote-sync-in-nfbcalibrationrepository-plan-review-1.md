# Plan Review: Add `NfbCalibrationGrpcApi` + wire remote sync in `NfbCalibrationRepository`

## Code Review Summary

**Files Reviewed:** 1 plan file + cross-reference of 5 affected source files
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** (`/Users/max/projects/mind/mind_mobile/.ai-factory/ARCHITECTURE.md`): OK. The plan creates a thin gRPC API wrapper at the Repository ↔ network boundary, exactly where the architecture spec places it (Repository = "Drift DB + gRPC API"). No domain leakage, no Flutter imports.
- **RULES.md** (`/Users/max/projects/mind/mind_mobile/.ai-factory/RULES.md`): OK. Constructor-injection rule respected (`NfbCalibrationGrpcApi(this._client)`, repository injected via `App.dart`). App.dart only wires infrastructure — no module concerns added. Rule about stateless module Services is not relevant (this is a repository-layer dependency, not a module Service).
- **ROADMAP.md** (`/Users/max/projects/mind/mind_mobile/.ai-factory/ROADMAP.md`): OK. Plan corresponds 1:1 to the `[ ]` item at line 203 in Phase 24 — "Add `NfbCalibrationGrpcApi` + wire remote sync in `NfbCalibrationRepository`". The deferred `refreshFromServer` work is correctly left to the next ROADMAP task (line 205).
- **skill-context/aif-review/SKILL.md**: WARN — file not present. No project-specific review rules to apply.

### Critical Issues

None.

### Cross-checks against the codebase

All technical claims in the plan match what is on disk:

- `RecordNfbCalibrationRequest` field names and types — verified against `lib/Core/Grpc/generated/nfb_calibration.pb.dart` (lines 235–424). All eleven fields (`deviceSerial`, `calibratedAt` as `String`, `isValid` as `bool`, `failReason` as `String`, plus the seven `double` fields) exist with the exact names listed in the plan.
- `ListNfbCalibrationsRequest(deviceSerial, limit)` — verified (lines 427–493).
- `ListNfbCalibrationsResponse.records` — verified, `PbList<NfbCalibrationRecord>` (line 544).
- `NfbCalibrationServiceClient.record(req)` returns `ResponseFuture<NfbCalibrationRecord>` — discarding the return value is sound for fire-and-forget.
- `NfbCalibrationServiceClient.list(req)` returns `ResponseFuture<ListNfbCalibrationsResponse>` — `response.records` exists, plan's mapping is correct.
- `App.dart:163` already constructs `NfbCalibrationGrpcApi(grpcClient.nfbCalibrationService)` (visible in working-tree diff), and `GrpcClient.dart:40` already exposes `nfbCalibrationService` — so Task 2's claim "no wiring change needed" holds.
- `NfbCalibrationRepository` already takes `required NfbCalibrationGrpcApi api` and already wraps `_api.record(...)` in `unawaited(... .catchError(...))` — Task 2 is genuinely a no-op verification, as the plan asserts.
- The doc comment in `nfb_calibration.pb.dart:21` confirms the `calibratedAt` ISO-8601 convention used in the plan.
- `NfbCalibrationData` field set matches the proto field set 1:1 (the proto's extra `id` and `createdAt` are correctly dropped in the proto→domain mapping; they are not part of the local cache model).

### Observations (non-blocking)

1. **No interface (`INfbCalibrationGrpcApi`) — divergent from `BciDevicesGrpcApi`.** The sibling file `lib/Bci/BciDevicesGrpcApi.dart` implements `IBciDevicesGrpcApi`, but the plan deliberately omits an interface here. The justification ("consumed only by `NfbCalibrationRepository`") is reasonable, but the inconsistency will matter as soon as the repository needs unit tests with a fake — adding the interface later is trivial, so this is fine for now. Worth a one-line mention in the file (or a follow-up task) so the asymmetry isn't taken as a pattern to copy.

2. **`DateTime.parse(r.calibratedAt)` is unguarded.** If the server returns an empty string (proto3 default) or a malformed value, the future returned by `list()` rejects. The plan correctly notes the `list` call is unused in this task — the future `refreshFromServer` task already plans to wrap it in `catchError`. Just flagging so the next plan doesn't drop the guard. No change needed here.

3. **`failReason` enum-name is sent verbatim.** The local domain stores `failReason` as a free-form `String` whose allowed values are documented in `NfbCalibrationData.dart:15-19` (`"none"` / `"tooManyArtifacts"` / `"peakFrequencyAtBorder"`). The plan passes it straight to the proto string field. This is correct **provided** the server contract uses the same lowerCamelCase names — confirm against `mind_api/proto/nfb_calibration.proto` (this is an integration concern, not a plan defect).

4. **Silent UNAUTHENTICATED swallowing.** `unawaited(_api.record(serial, data).catchError(...))` will silently drop a `gRPC code 16` if a calibration completes during the brief window where the token is unauthenticated. The `GrpcAuthInterceptor` publishes to `LogoutNotifier` only on the awaited path; here we're awaiting in a detached future whose error is caught and logged. This matches the project's existing fire-and-forget pattern (e.g. `SyncEngine`-side telemetry), so it's consistent — just worth noting that "lost calibration" is the failure mode the user will not see. Out of scope for this plan.

5. **Plan settings `Logging: minimal`.** The single `logPrint` already lives in the repository (pre-existing). The new API file correctly adds none. Consistent.

### Positive Notes

- Plan is tightly scoped (one new file, two verifications, an analyzer pass) and matches an explicit ROADMAP entry.
- Proto-field mapping is enumerated explicitly rather than left as "map the fields", which catches naming drift early.
- Plan flags the "build currently broken" condition (because `NfbCalibrationRepository` and `App.dart` already import the missing file) — clarifies urgency and dependency order.
- Plan correctly defers the `refreshFromServer` caller and the `list` consumer to the next ROADMAP task, keeping each task atomic.
- Plan respects the no-interface decision but justifies it instead of silently dropping the convention.
- The `// Return value (NfbCalibrationRecord) is intentionally discarded` comment in the working-tree file (not the plan, but a result of following it) is the kind of intent-preserving comment future readers benefit from.

PLAN_REVIEW_PASS
