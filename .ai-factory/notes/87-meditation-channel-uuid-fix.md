# Fix: MeditationModuleStateChannel Sends Pose UUID as ref_id

**Date:** 2026-06-03
**Source:** bug investigation — invalid input syntax for type uuid: "easy"

## Key Findings

- Root cause: `MeditationModuleStateChannel` forwards the pose slug (`'easy'`, `'lotus'`…) directly as `refId` to `channel.start()`. The `module_sessions.activityRefId` column is `uuid` type — PostgreSQL rejects slugs.
- Fix is in `MeditationModule.buildSession()`: look up `App.shared.meditationPoseUuids[poseId]` before constructing the channel and pass the UUID as `refId`.
- Rename channel constructor param `poseId → refId` to reflect its actual semantics — it holds whatever string will be sent as `ref_id` on the wire.

## Details

### Files changed

**`lib/MeditationModule/Core/MeditationModuleStateChannel.dart`** — one-line rename:
```dart
// Before:
MeditationModuleStateChannel(ModuleStateChannel channel, Stream<MeditationSessionState> stateStream, String poseId)

// After:
MeditationModuleStateChannel(ModuleStateChannel channel, Stream<MeditationSessionState> stateStream, String refId)
```
The body is unchanged — it passes `refId` to `channel.start(refId: refId)`.

**`lib/MeditationModule/MeditationModule.dart`** — in `buildSession(context, {required String poseId})`:
```dart
final refId = App.shared.meditationPoseUuids[poseId] ?? poseId;
// then construct the channel:
MeditationModuleStateChannel(
  App.shared.moduleStateChannel,
  vm.stream,
  refId,   // was: poseId
)
```

### Fallback behavior
When `meditationPoseUuids` is empty (offline / fetch failed), `refId = poseId` = slug. The server rejects the session — existing behavior, no new crash mode.

### What stays unchanged
- Route `extra` continues to carry the slug (`poseId`) — session screen uses it for image/title display.
- Navigation, coordinators, and all package code are untouched.
