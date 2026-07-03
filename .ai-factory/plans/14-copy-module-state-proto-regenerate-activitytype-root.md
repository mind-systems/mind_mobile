# Plan: Copy `module_state.proto` + regenerate + `ActivityType.root`

## Context
Replace the stale `module_state` wire contract with the LIVE one from `mind_api/proto/` (adds `ROOT`, `client_activity_id`, `session_id`, `StateEvent.activity_type`) and teach the app-level `ActivityType` enum about `root` in both mapping directions. Foundation task — nothing else in Phase 61 compiles without the new wire types.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Wire contract

- [x] **Task 1: Copy the live proto and regenerate stubs**
  Files: `proto/module_state.proto`, `lib/Core/Grpc/generated/module_state.pb.dart`, `lib/Core/Grpc/generated/module_state.pbenum.dart`, `lib/Core/Grpc/generated/module_state.pbgrpc.dart`, `lib/Core/Grpc/generated/module_state.pbjson.dart`
  Copy `mind_api/proto/module_state.proto` verbatim over `mind_mobile/proto/module_state.proto` (the API repo is the single source of truth — do not hand-edit). Then run `./scripts/gen_proto.sh` from the repo root to regenerate the Dart stubs — NOT `flutter pub run build_runner build` (that is Drift codegen only). Do not hand-edit any generated `*.pb*.dart` file. After regen the new wire surface must be present: `ActivityType.ROOT = 3`, `ActivityStartCmd.clientActivityId` (field 5), `ActivityEndCmd/StopCmd/PauseCmd/ResumeCmd.sessionId`, and `StateEvent.activityType` (field 4).
  `scripts/gen_proto.sh` does `rm -rf` on the output dir and regenerates ALL `proto/*.proto` in one pass, so confirm no unrelated stub files change beyond `module_state.*`. Caveat: this check only holds if the local toolchain matches the versions that produced the committed stubs — `protoc` (libprotoc 34.0) and `protoc-gen-dart` (protoc_plugin 25.0.0). If unrelated stubs show up as changed, first verify the toolchain versions (a version drift reformats every stub) before treating it as a contract problem; revert any spurious reformat-only churn in unrelated stubs.

### Phase 2: App-level enum mapping

- [x] **Task 2: Add `root` to the app-level `ActivityType` enum** (depends on Task 1)
  Files: `lib/Core/Grpc/ActivityType.dart`
  Extend `enum ActivityType { breath, meditation }` to `enum ActivityType { breath, meditation, root }`.

- [x] **Task 3: Extend the forward mapper and add a reverse proto→app mapper** (depends on Task 2)
  Files: `lib/Core/Grpc/ModuleStateChannel.dart`
  In the existing `_mapActivityType` app→proto switch (the method spans `:213-220`; arms at `:214-219`, no default), add `case ActivityType.root: return proto.ActivityType.ROOT;`. Then add a NEW reverse mapper (does not exist today) `proto.ActivityType → ActivityType?`: map `BREATH → breath`, `MEDITATION → meditation`, `ROOT → root`; for `ACTIVITY_TYPE_UNSPECIFIED` and any unknown value, log a drop via `logPrint` and return `null` (do NOT silently coerce to a real type). Follow the existing `logPrint` call style in this file for the drop message.
  This reverse mapper is the seam the session registry (note 14) will use to tag each frame's `StateEvent.activityType` — so within THIS milestone it has no caller and is intentionally dead. Prefix the declaration with `// ignore: unused_element` to keep `flutter analyze` clean; note 14 removes the ignore when it wires the first caller. (Without the ignore, the default-enabled `unused_element` warning fails Task 4.)

### Phase 3: Verify

- [x] **Task 4: Confirm the project still analyzes clean** (depends on Task 3)
  Files: (no edits — verification only)
  Run `/usr/local/bin/flutter analyze` and confirm it is clean. Existing `ModuleStateChannel` must still compile; the new proto fields and the new reverse mapper being unused so far is expected and fine (the reverse mapper carries `// ignore: unused_element` from Task 3, so no `unused_element` warning should surface). Spot-check the generated enum contains `ROOT`, `StateEvent` exposes `activityType`, and the command messages expose `sessionId` / `clientActivityId`.
