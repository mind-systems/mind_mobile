# Plan Review: `MeditationPosesGrpcApi` + `App.meditationPoseUuids` slug→UUID cache

**Plan:** `15-meditationposesgrpcapi-app-meditationposeuuids-slug-uuid-cache.md`
**Risk Level:** 🟢 Low

## Verification Against Codebase

Every concrete API reference in the plan was checked against the actual source. All correct:

- **Generated stubs exist** — `lib/Core/Grpc/generated/meditation_poses.pbgrpc.dart` is present and exposes `MeditationPosesServiceClient` with `listPoses(Empty())` returning `ResponseFuture<ListMeditationPosesResponse>`. The `.pbgrpc.dart` file `export`s `meditation_poses.pb.dart`, so the single import the plan specifies is sufficient for both the client and the messages. ✔
- **Message shape matches** — `ListMeditationPosesResponse.poses` is a `PbList<MeditationPose>`, and `MeditationPose` exposes `.id` and `.slug` string getters. The mapping `(id: p.id, slug: p.slug)` is valid. ✔ (Note: `MeditationPose` also has a `displayOrder` field the wrapper intentionally drops — fine for this milestone.)
- **`GrpcClient.meditationPosesService` getter exists** — `GrpcClient.dart:43`. The `initialize()` wiring `MeditationPosesGrpcApi(grpcClient.meditationPosesService)` is valid; `grpcClient` is a local variable in scope at that point. ✔
- **`Empty` import path is correct** — `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` matches exactly what `BciDevicesGrpcApi.dart:3` uses. ✔
- **Pattern reference is faithful** — `BciDevicesGrpcApi` is a plain client-wrapper class returning record-typed results, which is the shape the plan mirrors. ✔
- **`lib/MeditationModule/` already exists** as a domain directory, so placing the new file there is consistent. ✔
- **App.dart `late final` approach is sound** — keeping `meditationPosesApi` out of the `App._({...})` constructor and assigning `shared.meditationPosesApi = ...` after construction is a valid one-time `late final` initialization. ✔

## Context Gates

- **RULES.md — WARN (acknowledged & justified):** Rule states *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only."* Both new members (`meditationPosesApi`, `meditationPoseUuids`) are module-specific additions to App.dart. The plan explicitly calls this out (Context section) and justifies it by the milestone spec (note 85) requiring cross-module access via `App.shared`. This is a deliberate, documented deviation, not an oversight. Acceptable for this milestone; no blocking action required.
- **ARCHITECTURE.md:** No boundary violation introduced beyond the RULES.md note above. The wrapper lives in the domain layer (`lib/`), consistent with `BciDevicesGrpcApi`.
- **ROADMAP.md:** This is scoped as one milestone in a multi-step sequence (cache populated in the *next* milestone). The plan correctly limits scope and states the follow-up explicitly.

## Minor Observations (non-blocking)

1. **No interface, unlike `BciDevicesGrpcApi`** — the BCI wrapper implements `IBciDevicesGrpcApi`, whereas this wrapper is a bare class. The plan justifies this (spec shows a plain class, thin/stateless wrapper). Consistent enough; flag only because a future test seam might want one. No change needed now.
2. **`meditationPoseUuids` is a public mutable field on a singleton** — a mild design smell (shared mutable global), but it is exactly what the milestone requires and is documented as populated lazily. Acceptable given the spec.
3. **Field placement comment** — Task 2 places a non-`final` field among the `final` infrastructure fields. Harmless in Dart; the inline `// slug → UUID` comment keeps intent clear.

## Conclusion

The plan is technically accurate: every generated symbol, getter, import path, and pattern it relies on was confirmed to exist in the current codebase. Scope is tight and correctly bounded. The only rule tension (App.dart infrastructure-only) is explicitly acknowledged and justified by the milestone spec, not a mistake. No missing steps, no wrong API usage, no incorrect file paths.

PLAN_REVIEW_PASS
