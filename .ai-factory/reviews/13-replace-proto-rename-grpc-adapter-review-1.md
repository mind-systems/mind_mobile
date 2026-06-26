# Code Review: Replace proto + rename gRPC adapter

**Scope:** `git diff HEAD` — proto swap, regenerated stubs, gRPC adapter rename, `GrpcClient` / `App` wiring, note sync path.

## What was verified

- **Proto is identical to the source of truth.** `proto/module_session_notes.proto` is a byte-for-byte match with `mind_api/proto/module_session_notes.proto` (`diff` reports no differences). The mobile repo did not edit the contract, satisfying the proto-ownership rule.
- **Field-number invariant holds.** In the regenerated descriptors (`module_session_notes.pbjson.dart`): `note_text` is field 4 in `ModuleSessionNote` and field 3 in `CreateNoteRequest`. Old `pose_id` positions are emitted as reserved ranges (`{'1': 3, '2': 4}` and `{'1': 2, '2': 3}`) plus reserved name `pose_id` (the `'10': ['pose_id']` entries are the `reserved_name` slot of `DescriptorProto`, exactly as expected). No renumbering occurred.
- **No `poseId` accessor leaks.** The generated `pb.dart` exposes no `poseId` getter/setter; the adapter and sync path compile without it.
- **Rename is complete and consistent.** `ModuleSessionNotesGrpcApi` (new file), `GrpcClient.moduleSessionNotesService` / `ModuleSessionNotesServiceClient`, and `App.moduleSessionNotesGrpcApi` (field + import + wiring on line ~272) all line up. `ModuleSessionNoteService._syncToServer` calls the renamed API with only `sessionId` + `noteText`, and the `GrpcError` / `StatusCode.alreadyExists` handling is unchanged.
- **No stale artifacts.** No `meditation_notes.*` files remain in `lib/Core/Grpc/generated/`; the old `MeditationNotesGrpcApi.dart` is deleted. No references to the old names (`meditationNotesGrpcApi`, `MeditationNotesService`, `meditationNotesService`, `MeditationNotesGrpcApi`) remain anywhere in `lib/` or in tests.
- **Compiles clean.** `flutter analyze` over the affected files (`App.dart`, `GrpcClient.dart`, `lib/MeditationModule/`, generated grpc stub) reports "No issues found!".

## Notes (non-issues)

- The remaining `meditation_notes` / `pose_id` hits in `lib/Core/Database/Database.dart` are historical migration steps (create-then-drop of the old local table from the prior milestone). Migration history must not be rewritten, so leaving the old table-name string literal there is correct.
- The remaining `poseId` references in `router.dart`, `MeditationListCoordinator`, `MeditationSessionCoordinator`, and `MeditationModule.dart` belong to meditation *pose* navigation, which is unrelated to the notes contract and correctly untouched.

No bugs, security issues, or correctness problems found.

REVIEW_PASS
