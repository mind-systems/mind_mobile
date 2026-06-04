# Plan Review: Wire gRPC note sync — MeditationNotesGrpcApi + service update + buildSession

**Plan:** `24-wire-grpc-note-sync-meditationnotesgrpcapi-service-update-buildsession.md`
**Risk Level:** 🟢 Low

## Verification of Assumptions

Every codebase claim in the plan was checked against the source and holds:

| Claim | Verdict |
|-------|---------|
| `GrpcClient.meditationNotesService` is a `MeditationNotesServiceClient` | ✅ `GrpcClient.dart:42` |
| `CreateNoteRequest { sessionId, poseId, noteText }` stubs exist | ✅ `meditation_notes.pb.dart:140` (fields 191/200/209) |
| `MeditationNotesServiceClient.createNote(...)` exists | ✅ `meditation_notes.pbgrpc.dart:36`, returns `ResponseFuture<MeditationNote>` |
| `meditation_notes.pbgrpc.dart` re-exports `.pb.dart` (so `CreateNoteRequest` is visible from the pbgrpc import) | ✅ `meditation_notes.pbgrpc.dart:21` `export 'meditation_notes.pb.dart';` |
| `MeditationPosesGrpcApi.dart` style to mirror | ✅ matches Task 1 exactly |
| `App.dart` has `meditationPosesApi` field + initializer to mirror | ✅ field `App.dart:100`, init `App.dart:243`, import `App.dart:52` |
| `MeditationNoteService.saveNote` resolves UUID + saves locally | ✅ `MeditationNoteService.dart:14-17` |
| `IMeditationNoteService.saveNote(String, {String? sessionId})` signature | ✅ used unchanged by service/coordinator |
| `MeditationSessionCoordinator` declares `getSessionId` + forwards to `saveNote` | ✅ `MeditationSessionCoordinator.dart:17,27` (Task 4 verify-only correct) |
| `buildSession()` passes `getSessionId: () => stateChannel.moduleSessionId` | ✅ `MeditationModule.dart:44` (Task 4 verify-only correct) |
| `StatusCode.alreadyExists` exists in grpc package | ✅ `grpc-5.1.0/.../status.dart:59` |
| `AuthApi.dart` GrpcError pattern reference | ✅ `AuthApi.dart:22-25` matches |

No incorrect file paths, no wrong API usage, no missing intermediate steps. Task dependency ordering (1 → 2 → 3 → 4) is correct: the API class must exist before DI registration, which must exist before the service references `App.shared.meditationNotesGrpcApi`.

## Context Gates

### Architecture — WARN (informational, aligned)
`.ai-factory/ARCHITECTURE.md` models the layering as `Repository (Drift DB + gRPC API)` and lists `App.dart` as the manual-DI initialization root. Registering a stateless gRPC wrapper in `App.dart` directly mirrors the existing `meditationPosesApi` (`App.dart:243`) and `gRPC API` infrastructure entry (ARCHITECTURE `Infrastructure` table). **Aligned** — no boundary violation.

### Rules — WARN (no violation, worth a note)
`.ai-factory/RULES.md`: *"Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only (DB, HTTP, notifiers, sync)."*
A `MeditationNotesGrpcApi` is a **stateless gRPC client wrapper** (no `StreamController`/`StreamSubscription`/`dispose`), in the same category as the already-present `meditationPosesApi` and `meditationNoteRepository`. It is infrastructure, not module state/stream/trigger, so the rule is **not violated**. The implementer should keep the wrapper stateless to stay within this rule.

### Roadmap — WARN (missing explicit linkage)
This is `feat` work (server-side note sync). The plan body does **not** cite a ROADMAP milestone or a `.ai-factory/notes/NN-…` spec, unlike every completed Phase 28/29/33 task which ends with `Spec: .ai-factory/notes/NN-…`. Recommend linking this task to its milestone/note for traceability. Non-blocking.

## Observations (non-blocking)

1. **poseId UUID contract dependency.** `MeditationNoteService.saveNote` resolves `poseId = App.shared.meditationPoseUuids[_poseSlug] ?? _poseSlug`. The `meditationPoseUuids` map is populated **lazily** ("populated lazily when the meditation list opens, NOT in initialize()" — `App.dart:102`). If a meditation session reaches the note step before the list has ever populated that map, `poseId` falls back to the **raw slug**, and the new server `CreateNote` call would send a non-UUID `poseId`. Because the call is fire-and-forget with a catch-all, any server rejection (e.g. `INVALID_ARGUMENT`/`NOT_FOUND`) is silently swallowed — so it degrades gracefully, but the note silently fails to sync. ROADMAP line 19 already flags the "correct `poseId` UUID contract" as landing with the pose-catalog integration, so this is a **known, accepted** boundary. Worth a one-line log in the catch so silent server-side drops are observable (the plan already specifies "minimal log, non-fatal").

2. **`unawaited` for fire-and-forget.** Task 3 correctly adds `import 'dart:async'` for `unawaited`. Note the helper itself is `async` and the `try/catch` is *inside* it, so the `unawaited(_syncToServer(...))` at the call site can never throw synchronously — correct.

3. **`await _client.createNote(...)` discards `ResponseFuture<MeditationNote>`.** The wrapper returns `Future<void>` and awaits the unary call, discarding the `MeditationNote` body. Intentional and fine for a thin wrapper.

## Conclusion

The plan is accurate, well-scoped, correctly ordered, and every codebase assumption verified true. Tasks 1–3 are concrete edits; Task 4 is correctly verify-only (both pieces already wired). The only items are non-blocking context-gate notes (roadmap linkage, lazy-UUID degradation) that the fire-and-forget design already tolerates.

PLAN_REVIEW_PASS
