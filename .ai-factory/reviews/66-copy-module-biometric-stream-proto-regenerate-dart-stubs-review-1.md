# Review: Copy `module_biometric_stream.proto` + regenerate Dart stubs

## Scope verified
- `proto/module_biometric_stream.proto` is a byte-identical copy of `mind_api/proto/module_biometric_stream.proto` (`diff -q` reports no differences).
- The four generated Dart files (`module_biometric_stream.pb.dart`, `pbenum.dart`, `pbgrpc.dart`, `pbjson.dart`) are present under `lib/Core/Grpc/generated/` as required.
- `ModuleBiometricStreamServiceClient` is exported from `module_biometric_stream.pbgrpc.dart` (the proto declares `service ModuleBiometricStreamService` in `package mind;`, matching the generated class name).
- Generated stubs correctly import `module_state.pb.dart` (for `StateErrorEvent`) and the well-known `google/protobuf/struct.proto` (for `BioSample.data`).
- `flutter analyze` reports no issues on the four new generated files.
- No application code was touched — task description explicitly forbids it, and `git status` confirms only the proto + four generated files + plan/plan-review docs are added.

## Findings

None.

REVIEW_PASS
