## Plan Review: Rewrite `docs/core/sync-engine.md`

**Plan file:** `.ai-factory/plans/63-rewrite-docs-core-sync-engine-md.md`
**Files verified:** `SyncGrpcListener.dart`, `SyncEngine.dart`, `SyncApi.dart`, `ISyncApi.dart`, `ChangeEvent.dart`, `ISyncStateDao.dart`, `App.dart` (lines 100–180), `sync.pb.dart`, existing `docs/core/sync-engine.md`, neighboring docs (`notifier-pattern.md`, `module-system.md`, `global-listeners.md`)
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md** — WARN: no issues. Plan is docs-only; no boundary/dependency concerns.
- **RULES.md** — WARN: no issues. Rules target code patterns (stateless services, constructor DI). Docs rewrite has no code changes.
- **ROADMAP.md** — ✅ Plan maps directly to Roadmap item **11.1 "Rewrite sync-engine.md"**.
- **SKILL.md** — WARN: `.ai-factory/skill-context/aif-review/SKILL.md` does not exist. No project-specific review overrides applied.

### Verification Results

Every factual claim in the plan was checked against source code:

| Claim | Source | Status |
|-------|--------|--------|
| `SyncEngine.sync()` calls `syncApi.fetchChanges(lastEventId)` | `SyncEngine.dart:44-45` | ✅ |
| `fullResync` flag: skip if `lastEventId == 0`, else clear + reset | `SyncEngine.dart:46-54, 123-127` | ✅ |
| `processEvents()` waits for `_activeSyncOp` | `SyncEngine.dart:63-68` | ✅ |
| Pipeline: group → split → batch 50 → Drift → cursor → invalidate | `SyncEngine.dart:72-121` | ✅ |
| `SyncApi.fetchSessionsBatch()` wraps `BreathSessionService/BatchGetSessions` | `SyncApi.dart:36-38` | ✅ |
| `SyncEngine` subscribes to `authStream.skip(1)` for login re-sync | `SyncEngine.dart:20` | ✅ |
| `waitForColdStart(bool)` with 5s timeout | `SyncEngine.dart:27-29` | ✅ |
| `SyncGrpcListener` constructor: `SyncServiceClient`, `SyncEngine`, `ISyncStateDao`, `Stream<AuthState>` | `SyncGrpcListener.dart:22-27` | ✅ |
| Double `_isAuthenticated` check around async DAO read | `SyncGrpcListener.dart:41,43` | ✅ |
| 3-second fixed reconnect timer | `SyncGrpcListener.dart:73` | ✅ |
| Proto `ChangeEvent` envelope wraps `repeated SyncEventDto` | `sync.pb.dart:424-426` | ✅ |
| `SyncEventDto.createdAt` discarded during mapping | `SyncGrpcListener.dart:78-84`, `SyncApi.dart:41-47` | ✅ |
| Domain `ChangeEvent`: `id`, `entity`, `refId`, `action` | `ChangeEvent.dart:1-13` | ✅ |
| `ISyncStateDao`: `getLastEventId()`, `setLastEventId()`, `reset()` | `ISyncStateDao.dart:1-5` | ✅ |
| Wiring order in `App.dart`: `SyncApi` → `SyncEngine` → `waitForColdStart` → `SyncGrpcListener` | `App.dart:126,137-138,162` | ✅ |
| `SyncGrpcListener` created after cold-start completes | `App.dart:138 (await)` vs `162` | ✅ |
| Old Socket.IO classes deleted (roadmap Phase 3.6) | `ROADMAP.md` Phase 3.6 ✅ | ✅ |
| Neighboring docs in Russian | `notifier-pattern.md`, `module-system.md`, `global-listeners.md` | ✅ |

### File paths referenced in the plan

All paths exist and are correct:
- `lib/Core/Sync/SyncGrpcListener.dart` ✅
- `lib/Core/Sync/SyncEngine.dart` ✅
- `lib/Core/Sync/SyncApi.dart` ✅
- `lib/Core/Api/Models/ChangeEvent.dart` ✅
- `lib/Core/App.dart` (lines ~126–162) ✅
- `lib/Core/Grpc/generated/sync.pb.dart` ✅

### Language decision

The plan instructs writing in Russian to match neighboring docs. This correctly follows the user's private instruction ("Match the language of existing docs — even if project instructions say otherwise"), which takes precedence over the project-level "All files must be written in English" rule.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- Every behavioral claim is backed by exact source code — no guesswork or stale assumptions.
- The section-by-section guide gives the implementer a clear, ordered writing plan without being overly prescriptive about prose.
- Correctly identifies all Socket.IO/REST artifacts to remove from the existing doc.
- The "Remove before writing" checklist prevents partial updates where old terminology leaks through.
- Wiring section accurately reflects the real initialization order in `App.dart`, including the critical detail that `SyncGrpcListener` is created *after* cold-start completes.

PLAN_REVIEW_PASS
