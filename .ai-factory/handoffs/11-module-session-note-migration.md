# Handoff — module-session-note-migration

## 1. Frame
The backend is migrating `MeditationNotesService` to a generic `ModuleSessionNotesService` so any activity (breath, meditation) can have a post-session note — the chat is compacted but the knowledge is durable in files; rehydrate from them, don't trust memory.

## 2. Read-first map

### Must-read now (minimal rehydration set)
- `mind_api/proto/module_session_notes.proto` — the new proto contract; replaces `meditation_notes.proto` ← start here
- `mind_api/.ai-factory/notes/67-module-session-note-mobile-consumer.md` — full step-by-step for the mobile side of this migration

### Read on demand
- `mind_api/.ai-factory/ROADMAP.md` — Phase 53, one remaining task: "Rename proto + API backend" (must land first before mobile can start)
- `mind_api/proto/meditation_notes.proto` — old contract for comparison (will be deleted from mind_api after Phase 53 ships)

## 3. Current state

**Done:**
- Architecture decision: notes are generic at the protocol level — `session_id` in the note maps to `module_sessions.id`, which already carries `activityType` and `activityRefId` (pose UUID for meditation, breath session ID for breath)
- Confirmed in DB: `module_sessions.activityRefId` stores the pose UUID for meditation sessions — `pose_id` in the note is a duplicate
- ROADMAP Phase 53 created in mind_api with one remaining backend task
- Spec notes written: `mind_api/.ai-factory/notes/65`, `67`

**In-flight:**
- Phase 53 task 1 (backend): rename proto + entity + migration + service + controller + mapper in mind_api — **not yet implemented**; mobile work is blocked until this ships

**Uncommitted working-tree state:**
- `mind_api/.ai-factory/ROADMAP.md` — Phase 53 added
- `mind_api/.ai-factory/notes/65-module-session-note-proto-and-api.md` — new
- `mind_api/.ai-factory/notes/67-module-session-note-mobile-consumer.md` — new

## 4. Next step
Wait for mind_api Phase 53 task 1 to ship, then: copy `mind_api/proto/module_session_notes.proto` → `mind_mobile/proto/module_session_notes.proto`, regenerate Dart stubs, delete old `meditation_notes` proto + stub, update all Dart call sites (remove `pose_id` from `CreateNoteRequest`, rename client class to `ModuleSessionNotesServiceClient`), and wire up note creation after breath sessions.

## 5. Working discipline
Confirm proto field numbers before regenerating — `note_text` stays at field 4 (not renumbered after `pose_id` field 3 is dropped) to avoid breaking serialized data.

## 8. Domain model spine
- `module_sessions.activityRefId` = pose UUID for MEDITATION, breath session UUID for BREATH — don't re-litigate; confirmed from live DB data.
- `ModuleSessionNote.session_id` links to `module_sessions.id` (not to breath_sessions or any activity-specific table) — this is what makes the note generic.

## 9. Hard rules
- Proto field numbers are immutable once shipped — dropping `pose_id` (field 3) leaves a gap; `note_text` stays at field 4. Never renumber existing fields.
- Proto source of truth is `mind_api/proto/` — copy only, never modify in mind_mobile.

## 10. Cross-cutting contracts / invariants checklist
- Old service name `MeditationNotesService` → new `ModuleSessionNotesService` — update `@GrpcMethod` decorator strings on backend AND client stub usage on mobile
- Old message `MeditationNote` → `ModuleSessionNote`
- `CreateNoteRequest`: drop `pose_id` (field 3); `note_text` stays at field 4
- `session_id` in `CreateNoteRequest` = `module_sessions.id` (UUID of the realtime session, not a breath session UUID)
