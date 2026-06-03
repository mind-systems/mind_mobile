# Meditation Poses — Copy Proto + Regenerate Dart Stubs

**Date:** 2026-06-03
**Source:** conversation context

## Key Findings

- `meditation_poses.proto` does not exist in `mind_mobile/proto/`; no `MeditationPosesServiceClient` is generated.
- Copy from `mind_api/proto/` and regenerate stubs; note the exact getter name added to `GrpcClient` — needed in the next task.

## Details

### What to copy
- Source: `mind_api/proto/meditation_poses.proto`
- Destination: `mind_mobile/proto/meditation_poses.proto`
- Run: `./scripts/gen_proto.sh` to regenerate all Dart stubs

### Proto contract

```proto
service MeditationPosesService {
  rpc ListPoses(google.protobuf.Empty) returns (ListMeditationPosesResponse);
}

message MeditationPose {
  string id            = 1;   // UUID from meditation_poses.id
  string slug          = 2;   // 'easy', 'lotus', etc.
  int32  display_order = 3;
}

message ListMeditationPosesResponse {
  repeated MeditationPose poses = 1;
}
```

### Verify
Check that `MeditationPosesServiceClient` (or the exact generated name) appears in `lib/Core/Grpc/generated/`. No application code changes — task ends when the project compiles with the new stubs.
