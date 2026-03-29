# Plan: Update type references

## Context

The proto contract `module_state.proto` still uses the old type names (`SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent`). These were planned for rename in mind_api Phase 10, but that work was never executed. This plan covers the full chain: rename in `mind_api/proto/` (source of truth), regenerate stubs on both sides, and update all hand-written code that references the old names.

**Cross-project plan:** Phases 1-2 operate in `mind_api/`, Phases 3-4 operate in `mind_mobile/`. Each repo is committed independently.

## Settings
- Testing: no
- Logging: minimal
- Docs: no

## Tasks

### Phase 1: Rename proto types in mind_api _(operates in `mind_api/`)_

- [x] **Task 1: Rename message and enum types in `module_state.proto`**
  Files: `mind_api/proto/module_state.proto`
  Apply these renames to the type definitions, all field-type references, the `rpc TrackActivity` signature, and surrounding comments:
  - `SessionRequest` -> `StateRequest` (message, L80)
  - `SessionResponse` -> `StateResponse` (message, L92; rpc signature L108)
  - `SessionStatus` -> `ActivityStatus` (enum, L21; field type in `SessionStateEvent` L60)
  - `SessionStateEvent` -> `StateEvent` (message, L58; oneof field type in `SessionResponse` L94)
  - `SessionErrorEvent` -> `StateErrorEvent` (message, L68; oneof field type in `SessionResponse` L95)
  - Rename the sentinel `SESSION_STATUS_UNSPECIFIED` -> `ACTIVITY_STATUS_UNSPECIFIED` (L22)
  - Update all comments that reference old names (e.g. "SessionRequest is the client-to-server..." -> "StateRequest...")

  **Do not rename:** `ActivityStartCmd`, `ActivityEndCmd`, `ActivityStopCmd`, `ActivityPauseCmd`, `ActivityResumeCmd`, `ActivityType`, `ModuleStateService`, `TrackActivity` — these are already correct.
  **Do not rename proto field names** (e.g. `session_state`, `session_error`, `module_session_id`) — only message/enum type names change.

- [x] **Task 2: Update `SessionErrorEvent` reference in `module_instruction_stream.proto`** (depends on Task 1)
  Files: `mind_api/proto/module_instruction_stream.proto`
  - L14 comment: `SessionErrorEvent.timestamp` -> `StateErrorEvent.timestamp`
  - L52 comment: `SessionErrorEvent` -> `StateErrorEvent`
  - L56 field type: `SessionErrorEvent error = 2;` -> `StateErrorEvent error = 2;`
  - L65 comment: `SessionErrorEvent` -> `StateErrorEvent`

### Phase 2: Regenerate stubs and update mind_api code _(operates in `mind_api/`)_

- [x] **Task 3: Regenerate NestJS TypeScript stubs** (depends on Task 2)
  Files: `mind_api/proto/generated/module_state.ts`, `mind_api/proto/generated/module_instruction_stream.ts`
  Run `npm run proto:gen` from the `mind_api/` root. Verify:
  - `proto/generated/module_state.ts` exports `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent` (old names gone)
  - `proto/generated/module_instruction_stream.ts` references `StateErrorEvent` (not `SessionErrorEvent`)

- [x] **Task 4: Update `module-state.grpc.controller.ts` imports and usages** (depends on Task 3)
  Files: `mind_api/src/realtime/module-state.grpc.controller.ts`
  Update the import block (L7-15) to use new names from regenerated stubs:
  - `SessionRequest` -> `StateRequest`
  - `SessionResponse` -> `StateResponse`
  - `SessionStatus` -> `ActivityStatus`

  Then replace all usages throughout the file:
  - L64: `Observable<SessionRequest>` -> `Observable<StateRequest>`, `Observable<SessionResponse>` -> `Observable<StateResponse>`
  - L65: `new Observable<SessionResponse>` -> `new Observable<StateResponse>`
  - L91, 222, 249, 264, 279, 292, 313: `SessionStatus.RESUMED`, `.ACTIVE`, `.COMPLETED`, `.INTERRUPTED` -> `ActivityStatus.*`
  - L101: `msg: SessionRequest` -> `msg: StateRequest`
  - L162: `msg: SessionRequest, subscriber: Subscriber<SessionResponse>` -> `msg: StateRequest, subscriber: Subscriber<StateResponse>`
  - L179: comment `'Empty SessionRequest'` -> `'Empty StateRequest'`
  - L196-199, 255-258, 270-273, 285, 307: `Subscriber<SessionResponse>` -> `Subscriber<StateResponse>`

  **Note:** `module-instruction-stream.grpc.controller.ts` does NOT import `SessionErrorEvent` by name — it constructs error objects as inline literals. No changes needed there; verify the import block still compiles after stub regeneration.

### Phase 3: Propagate to mind_mobile _(operates in `mind_mobile/`)_

- [x] **Task 5: Copy updated proto files and regenerate Dart stubs** (depends on Task 4)
  Files: `mind_mobile/proto/module_state.proto`, `mind_mobile/proto/module_instruction_stream.proto`, `mind_mobile/lib/Core/Grpc/generated/`
  - Copy `mind_api/proto/module_state.proto` to `mind_mobile/proto/module_state.proto` (overwrite)
  - Copy `mind_api/proto/module_instruction_stream.proto` to `mind_mobile/proto/module_instruction_stream.proto` (overwrite)
  - Run `bash scripts/gen_proto.sh` from the `mind_mobile/` root
  - Verify `lib/Core/Grpc/generated/module_state.pb.dart` defines `StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent` (old names gone)
  - Verify `lib/Core/Grpc/generated/module_instruction_stream.pb.dart` references `StateErrorEvent`

### Phase 4: Update mind_mobile Dart code _(operates in `mind_mobile/`)_

- [x] **Task 6: Replace old proto type names in `ModuleStateChannel.dart`** (depends on Task 5)
  Files: `mind_mobile/lib/Core/Grpc/ModuleStateChannel.dart`
  This is the only hand-written file that uses `module_state.proto` types (all via the `proto.` import prefix). Apply these replacements:

  **Type names** (use `replace_all`):
  - `proto.SessionResponse` -> `proto.StateResponse` (L34, 73)
  - `proto.SessionRequest` -> `proto.StateRequest` (L35, 70, 149, 160, 166, 171, 176, 181)
  - `proto.SessionStateEvent` -> `proto.StateEvent` (L113)
  - `proto.SessionStatus` -> `proto.ActivityStatus` (L77, 115, 130, 133, 136)

  **Oneof discriminator enum** (the enum value names derive from proto field names which are unchanged, so these stay the same):
  - `proto.SessionResponse_Event.sessionState` -> `proto.StateResponse_Event.sessionState` (L75)
  - `proto.SessionResponse_Event.sessionError` -> `proto.StateResponse_Event.sessionError` (L79)
  - `proto.SessionResponse_Event.notSet` -> `proto.StateResponse_Event.notSet` (L84)

  **Enum constants** (use `replace_all`):
  - `proto.SessionStatus.ACTIVE` -> `proto.ActivityStatus.ACTIVE`
  - `proto.SessionStatus.RESUMED` -> `proto.ActivityStatus.RESUMED`
  - `proto.SessionStatus.DISCONNECTED` -> `proto.ActivityStatus.DISCONNECTED`
  - `proto.SessionStatus.COMPLETED` -> `proto.ActivityStatus.COMPLETED`
  - `proto.SessionStatus.INTERRUPTED` -> `proto.ActivityStatus.INTERRUPTED`
  - `proto.SessionStatus.ABANDONED` -> `proto.ActivityStatus.ABANDONED`
  - `proto.SessionStatus.SESSION_STATUS_UNSPECIFIED` -> `proto.ActivityStatus.ACTIVITY_STATUS_UNSPECIFIED`

- [x] **Task 7: Verify no other non-generated files reference old type names** (depends on Task 6)
  Files: all files under `mind_mobile/lib/`
  Grep for `SessionRequest`, `SessionResponse`, `SessionStatus`, `SessionStateEvent`, `SessionErrorEvent` across all non-generated Dart files (`lib/` excluding `lib/Core/Grpc/generated/`). Confirm zero matches for these as proto type references. Note: `BreathModuleStateChannel.dart` does NOT use proto types directly (it works through the `ModuleState` domain abstraction). Files like `BreathSessionApi.dart` contain "Session" in unrelated contexts (breath session CRUD) — those are not affected.

- [x] **Task 8: Fix roadmap milestone 9.1**
  Files: `mind_mobile/.ai-factory/ROADMAP.md`
  Milestone 9.1 is marked `[x]` complete, but only the presence removal part was done — the type rename verification was not (it was premature, since the proto source of truth hadn't been renamed). Split 9.1 into two items:
  - `[x]` — Copy proto and verify `PresenceCmd`/`PresenceState` are removed
  - `[x]` — Verify `module_state.pb.dart` uses new type names (`StateRequest`, `StateResponse`, `ActivityStatus`, `StateEvent`, `StateErrorEvent`)
  Mark both checked since by this point both are done.

## Commit Plan
- **Commit 1** (after tasks 1-4, in `mind_api/`): "Rename proto message types: Session* to State*/Activity*"
- **Commit 2** (after tasks 5-8, in `mind_mobile/`): "Update proto stubs and Dart code for renamed message types"
