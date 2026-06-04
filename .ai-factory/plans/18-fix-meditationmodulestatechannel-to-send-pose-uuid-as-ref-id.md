# Plan: Fix MeditationModuleStateChannel to send pose UUID as ref_id

## Context
`MeditationModuleStateChannel` must send the pose UUID (not the slug) as `refId`, because `module_sessions.activityRefId` is a `uuid` column — slugs like `"easy"` trigger `invalid input syntax for type uuid` on every session. The UUID lookup moves out of the channel and into `MeditationModule.buildSession()`, and the channel's constructor param is renamed `poseId → refId` to reflect that it now holds whatever string is sent on the wire.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Channel + wiring fix

- [x] **Task 1: Rename channel param to `refId` and pass it through directly**
  Files: `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`
  Rename the named constructor parameter `poseId → refId` and the backing field `_poseId → _refId`. In `_onState`, remove the internal UUID lookup (`final refId = App.shared.meditationPoseUuids[_poseId] ?? _poseId;`) and instead pass the field directly: `_channel.start(type: ActivityType.meditation, refId: _refId)`. After removing the lookup, drop the now-unused `App` import (`package:mind/Core/App.dart`) if nothing else in the file references `App`. The rest of the lifecycle logic (start/end/re-arm, `dispose`) stays unchanged.

- [x] **Task 2: Resolve UUID in `buildSession()` and pass as `refId`** (depends on Task 1)
  Files: `lib/MeditationModule/MeditationModule.dart`
  In `buildSession(context, {required String poseId})`, before constructing the channel add `final refId = App.shared.meditationPoseUuids[poseId] ?? poseId;`. Update the `MeditationModuleStateChannel(...)` call to pass `refId: refId` instead of `poseId: poseId`. Leave `MeditationSessionViewModel(poseId: poseId)` unchanged — the slug still drives image/title display. Fallback behavior is preserved: when `meditationPoseUuids` is empty, `refId` falls back to the slug (existing server-reject behavior, no new crash).
