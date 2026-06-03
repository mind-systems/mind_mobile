# MeditationPosesGrpcApi + App.meditationPoseUuids Cache

**Date:** 2026-06-03
**Source:** conversation context

## Key Findings

- New `lib/MeditationModule/MeditationPosesGrpcApi.dart` wraps the generated client; single method `listPoses()`.
- `App` gets two new fields: `meditationPosesApi` (initialized at startup) and `meditationPoseUuids: Map<String, String>` (slug → UUID, empty until first fetch).
- Cache is NOT populated in `App.initialize()` — populated lazily when the meditation list opens. This avoids a wasted gRPC call on every launch for users who never open meditation.

## Details

### `MeditationPosesGrpcApi` (`lib/MeditationModule/MeditationPosesGrpcApi.dart`)

```dart
class MeditationPosesGrpcApi {
  final MeditationPosesServiceClient _client;
  MeditationPosesGrpcApi(this._client);

  Future<List<({String id, String slug})>> listPoses() async {
    final resp = await _client.listPoses(Empty());
    return resp.poses.map((p) => (id: p.id, slug: p.slug)).toList();
  }
}
```

### `App.dart` changes (`lib/Core/App.dart`)

```dart
late final MeditationPosesGrpcApi meditationPosesApi;
Map<String, String> meditationPoseUuids = const {};  // slug → UUID; populated lazily
```

In `initialize()`, after `_grpcClient` is ready:
```dart
meditationPosesApi = MeditationPosesGrpcApi(_grpcClient.<meditationPosesService>);
```

The exact getter name on `GrpcClient` for `MeditationPosesServiceClient` is found in `lib/Core/Grpc/generated/` after running `gen_proto.sh`.
