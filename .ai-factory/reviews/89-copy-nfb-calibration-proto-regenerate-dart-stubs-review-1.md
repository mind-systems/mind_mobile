# Review: Copy `nfb_calibration.proto` + regenerate Dart stubs (Milestone 89)

## Scope of review

Staged changes in `mind_mobile`:

- `proto/nfb_calibration.proto` (new)
- `lib/Core/Grpc/generated/nfb_calibration.pb.dart` (new)
- `lib/Core/Grpc/generated/nfb_calibration.pbenum.dart` (new)
- `lib/Core/Grpc/generated/nfb_calibration.pbgrpc.dart` (new)
- `lib/Core/Grpc/generated/nfb_calibration.pbjson.dart` (new)
- `.ai-factory/plans/89-...md` and `.ai-factory/plan-reviews/89-...md` (docs only — out of scope for code review)

## Verifications performed

1. **Proto byte-for-byte identical to source of truth.** `diff mind_api/proto/nfb_calibration.proto mind_mobile/proto/nfb_calibration.proto` reports no differences — the file was copied verbatim, satisfying the "no edits, no symlinks" rule from root `CLAUDE.md` ("Proto contract ownership").

2. **All four generated artifacts present.** `lib/Core/Grpc/generated/` now contains `nfb_calibration.pb.dart`, `nfb_calibration.pbenum.dart`, `nfb_calibration.pbgrpc.dart`, `nfb_calibration.pbjson.dart` alongside the pre-existing stubs.

3. **`NfbCalibrationServiceClient` is generated as expected.** `nfb_calibration.pbgrpc.dart:24` declares `class NfbCalibrationServiceClient extends $grpc.Client` with two unary RPCs (`record`, `list`) whose path strings (`/mind.NfbCalibrationService/Record`, `/mind.NfbCalibrationService/List`) match the proto `service NfbCalibrationService` block.

4. **Message classes match the proto.** `nfb_calibration.pb.dart` defines `NfbCalibrationRecord`, `RecordNfbCalibrationRequest`, `ListNfbCalibrationsRequest`, `ListNfbCalibrationsResponse`. Field tag numbers and types (`string`, `bool`, `float` → `aOS`/`aOB`/`aD` with `PbFieldType.OF`) align with the proto declarations.

5. **No collateral changes.** `git diff HEAD --name-only -- lib/Core/Grpc/generated/` shows ONLY the four new `nfb_calibration.*` files. The codegen script wipes and regenerates the whole `generated/` directory, but since the other `.proto` files are unchanged the regenerated content is byte-identical to the committed copies — no stale/regenerated diffs leaked in.

6. **Static analysis clean on the new files.** `flutter analyze` on the four new files reports "No issues found!" — the stubs compile.

7. **Required dependencies present.** `pubspec.yaml` declares `grpc: ^5.1.0` and `protobuf: ^6.0.0`, matching the `import 'package:grpc/service_api.dart'` and `import 'package:protobuf/protobuf.dart'` directives in the generated code.

## Findings

None.

The milestone is correctly scoped: only proto + generated stubs are added. No application code is wired up, which is the expected end-state per the milestone description and the plan's Notes ("No edits to any file outside `proto/nfb_calibration.proto` and the regenerated `lib/Core/Grpc/generated/` tree"). The follow-up BCI calibration milestones will consume `NfbCalibrationServiceClient`.

REVIEW_PASS
