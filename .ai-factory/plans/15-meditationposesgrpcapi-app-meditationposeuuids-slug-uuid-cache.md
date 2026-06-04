# Plan: `MeditationPosesGrpcApi` + `App.meditationPoseUuids` slug→UUID cache

## Context
Introduces a gRPC wrapper for the meditation poses catalogue and an App-level slug→UUID cache so later tasks can resolve pose slugs to server UUIDs. This milestone only creates the wrapper and the (empty) cache field — it does NOT populate the cache (that is the next milestone, "Fetch pose UUIDs when meditation list opens").

Note: `.ai-factory/RULES.md` says App.dart should be infrastructure-only, but this milestone explicitly requires both new App members because the slug→UUID cache is read cross-module via `App.shared`. Following the milestone spec here (`.ai-factory/notes/85-meditation-poses-grpc-api.md`).

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: gRPC wrapper + App wiring

- [x] **Task 1: Create `MeditationPosesGrpcApi` wrapper**
  Files: `lib/MeditationModule/MeditationPosesGrpcApi.dart`
  Create a plain class wrapping the generated `MeditationPosesServiceClient`, mirroring the existing `lib/Bci/BciDevicesGrpcApi.dart` pattern.
  - Constructor takes a `MeditationPosesServiceClient` (`final MeditationPosesServiceClient _client;`).
  - Single method `Future<List<({String id, String slug})>> listPoses()` that calls `await _client.listPoses(Empty())` and maps `resp.poses` to records: `(id: p.id, slug: p.slug)`.
  - Imports: `package:mind/Core/Grpc/generated/meditation_poses.pbgrpc.dart` (exposes `MeditationPosesServiceClient` + re-exports the `.pb.dart` messages) and `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` for `Empty` (same import `BciDevicesGrpcApi` uses).
  - No interface file is required (the spec shows a plain class). Keep it stateless — no `dispose`, no stored state beyond `_client`.

- [x] **Task 2: Add `meditationPosesApi` + `meditationPoseUuids` to `App` and wire the API** (depends on Task 1)
  Files: `lib/Core/App.dart`
  - Add import `import 'package:mind/MeditationModule/MeditationPosesGrpcApi.dart';` alongside the other module imports.
  - Declare two new members in the `App` class fields block (near the other `final` infrastructure fields):
    - `late final MeditationPosesGrpcApi meditationPosesApi;`
    - `Map<String, String> meditationPoseUuids = const {}; // slug → UUID; populated lazily when the meditation list opens, NOT in initialize()`
  - Do NOT add `meditationPosesApi` to the `App._({...})` constructor parameter list, and do NOT add `meditationPoseUuids` to it either — keep the constructor unchanged. Because `meditationPosesApi` is `late final`, assign it after the singleton is constructed.
  - In `initialize()`, after `shared = App._( ... );` is assigned, add a single-line assignment: `shared.meditationPosesApi = MeditationPosesGrpcApi(grpcClient.meditationPosesService);` (the `meditationPosesService` getter already exists on `GrpcClient`). Follow the App.dart style rule: single-line, no trailing comma.
  - Leave `meditationPoseUuids` empty (`const {}`) — populating it is a later milestone.
