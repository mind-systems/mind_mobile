# Plan Review: Replace proto + rename gRPC adapter

**Plan:** `.ai-factory/plans/13-replace-proto-rename-grpc-adapter.md`
**Risk Level:** 🟢 Low

## Scope Verification

The plan migrates the meditation-notes proto contract to the renamed `module_session_notes`
contract, regenerates Dart stubs, and propagates the rename + `poseId` removal through the
adapter, `GrpcClient`, `App` DI, and the note sync path. Verified against the actual codebase.

### Reference accuracy — all confirmed
- `proto/meditation_notes.proto` exists; `mind_api/proto/module_session_notes.proto` exists and is the source of truth. ✅
- `mind_api/proto/module_session_notes.proto` matches the plan's description exactly: `MeditationNote` → `ModuleSessionNote`, `MeditationNotesService` → `ModuleSessionNotesService`, `reserved 3` / `reserved "pose_id"` in `ModuleSessionNote` (note_text stays field 4), `reserved 2` / `reserved "pose_id"` in `CreateNoteRequest` (note_text stays field 3). ✅
- `scripts/gen_proto.sh` does `rm -rf "$OUT_DIR"` then globs `proto/*.proto` — stale `meditation_notes.pb*.dart` are removed automatically and `module_session_notes.*` are produced. Task 2's claim is correct; no manual deletion needed. ✅
- `lib/MeditationModule/MeditationNotesGrpcApi.dart` — class/field/import/`createNote(poseId)` all match Task 3. ✅
- `GrpcClient.dart` line 10 import and line 53 `late final meditationNotesService = MeditationNotesServiceClient(...)` — match Task 4 exactly. ✅
- `App.dart` line 59 import, line 114 field `late final MeditationNotesGrpcApi meditationNotesGrpcApi`, line 272 wiring `shared.meditationNotesGrpcApi = MeditationNotesGrpcApi(grpcClient.meditationNotesService)` — all match Task 5 exactly. ✅
- `ModuleSessionNoteService._syncToServer` calls `App.shared.meditationNotesGrpcApi.createNote(sessionId, poseId: '', noteText)` with the `GrpcError`/`StatusCode.alreadyExists` guard — matches Task 6. ✅

### Completeness — no missing references
A full grep across `lib/`, `proto/`, `scripts/`, and `test/` for `MeditationNotesGrpcApi`,
`meditationNotesGrpcApi`, `meditationNotesService`, `MeditationNotesServiceClient`, and
`meditation_notes` surfaces exactly the call sites the six tasks cover. No test files reference
the adapter or service (grep over `test/` returned nothing), so no test updates are needed.

### Context Gates
- **Architecture (`ARCHITECTURE.md`):** No boundary issues. The rename keeps the existing
  domain→adapter→gRPC layering intact. `WARN`-free.
- **Rules (`RULES.md`):** The rule "Never add module-specific state to App.dart" is not violated —
  `meditationNotesGrpcApi` already exists in `App.dart` (alongside `meditationPosesApi`); the plan
  only renames pre-existing infrastructure wiring, it does not introduce new module state. No conflict.
- **Roadmap (`ROADMAP.md`):** Directly fulfills Phase 60's second task (line 43,
  "Replace proto + rename gRPC adapter"). Milestone linkage is explicit and correct. The preceding
  local-data-layer task (line 42) is already `[x]`, so the `poseId: ''` bridge this plan removes is
  the exact bridge that earlier task introduced — the sequencing is coherent.

### Observations (non-blocking)
- The local Drift table is still named `meditation_notes` in `Database.dart` (lines 46/54) inside a
  migration step. This is intentional historical migration SQL (`DROP TABLE IF EXISTS meditation_notes`)
  from the already-completed local-layer rename task and is correctly **out of scope** here — the proto
  rename must not touch it. No action required.
- Single-commit strategy is justified: the rename does not compile until all references update, so
  there is no safe intermediate checkpoint. Correct.

### Positive Notes
- Line numbers in the plan match the live files precisely (App.dart 59/114/272, GrpcClient 10/53).
- The proto field-number invariant (note_text at field 4 / field 3, never renumber the reserved gap)
  is called out explicitly and matches the source-of-truth proto — the most error-prone part of a
  proto rename is handled correctly.
- Dependency ordering between tasks is accurate (codegen before adapter, adapter before client/DI,
  DI before sync path).

PLAN_REVIEW_PASS
