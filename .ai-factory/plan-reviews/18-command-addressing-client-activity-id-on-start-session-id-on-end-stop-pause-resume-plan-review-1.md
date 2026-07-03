## Code Review Summary

**Plan reviewed:** `18-command-addressing-client-activity-id-on-start-session-id-on-end-stop-pause-resume.md`
**Files targeted:** 4 (`ModuleStateChannel.dart`, `BreathModuleStateChannel.dart`, `MeditationModuleStateChannel.dart`, `RootStateChannel.dart`)
**Risk Level:** 🟢 Low

### Context Gates
- **Roadmap (ROADMAP.md:60):** ✅ Aligned. The plan implements exactly the milestone contract — thread `client_activity_id` on start + `session_id` on end/stop/pause/resume through both adapters, never target the root id.
- **Governing spec (notes/16-rootchild-command-addressing.md):** ✅ Aligned. The change/guards match the note. The one guard the plan does **not** implement — "adopt an already-live child of the same type instead of starting a new one" (note 16 §Guards bullet 2) — is explicitly deferred by that same bullet ("Full rule + settling-window race in note 19"), which is roadmap line 80. Correct scoping; not a gap for this milestone. (WARN-level informational only.)
- **ARCHITECTURE.md / RULES.md:** ✅ No violations. The plan touches state-channel adapters, not module Services, so the stateless-Service and App.dart-purity rules do not apply.

### Verification performed
- **Proto fields exist as claimed** (`module_state.pb.dart`): `ActivityStartCmd(clientActivityId:)`, `ActivityEndCmd(sessionId:)`, `ActivityStopCmd(sessionId:)`, `ActivityPauseCmd(sessionId:)`, `ActivityResumeCmd(sessionId:)` — all constructors accept nullable params and set the field only when non-null, matching the existing `refId:` pattern the plan relies on. ✅
- **Line references accurate.** Every cited line in all four files matches the current source (`start :236`, `startRoot :253`, `pause :259`, `unpause :265`, `end :271`, `stop :280`; Breath first-start `:85-93`, resume `:95-96`, pause `:104`, end `:110`, dispose stop `:160`, reset `:144-155`; Meditation start `:48-50`, end `:52`, dispose stop `:62`, abandoned handler `:33-38`; Root startRoot `:21`). ✅
- **`uuid` dependency present** (`pubspec.yaml:66`, `uuid: ^4.5.3`) and `const Uuid().v4()` is the established idiom in this repo (5 existing call sites). ✅
- **`childOfType` semantics confirmed** (`SessionRegistry.dart:62-68`): never returns the root, returns `null` when no live child of that type exists — satisfies "omit → sole-child" and "never target root". Terminal entries are removed via `removeTerminal`, so it only ever yields live children. ✅
- **All command call sites covered.** Grep confirms the only callers of `start/startRoot/pause/unpause/end/stop` are the three adapters named in the plan. All new params are optional/nullable, so the signature changes are backward-compatible — no unlisted call site breaks. ✅
- **`ActivityType` import already present** in the Meditation adapter (line 3), as the plan states. ✅

### Critical Issues
None.

### Observations (non-blocking)
- **By-type addressing assumes ≤1 live child per activity type.** `_childSessionId` resolves via `childOfType(ActivityType.breath|meditation)`, which returns the *first* entry of that type. This is correct for the intended concurrency model (breath + meditation concurrently — one of each type) and matches the existing `SessionRegistry` API from the prior milestone. If the app ever runs two concurrent sessions of the *same* type, this addressing becomes ambiguous — but that is an inherited design property of `childOfType`, not something this plan introduces, and note 16's verify case ("breath + meditation") confirms the intended scope. No action needed.
- **Registry-population race on very-early pause/end.** Between `_channel.start(...)` and the server's ACTIVE frame, the registry has no child entry, so `_childSessionId` is `null` and the field is omitted → server falls back to sole-child. Under single-child flow this is harmless; under true concurrency an early command could theoretically hit `AMBIGUOUS_SESSION`. This settling-window race is explicitly the domain of note 19 (start-race hardening), so leaving it uncovered here is correct.
- **Root token reused across users is safe.** `RootStateChannel._clientActivityId` is minted once at construction and persists across logout/login. Because the server dedups on `${userId}:${clientActivityId}`, a new user yields a different key regardless — reuse cannot collide. The plan's "stable across reconnects" intent holds.
- **Minor wording:** Task 2 describes the first-start branch as `wasInactive && isRunning && !_started`, but the source nests these (`if (wasInactive && isRunning) { if (!_started) {...} }`). The token must be minted inside the `!_started` block (before the `_channel.start` at line 90). The intent is unambiguous; noting only so the implementer places the mint inside the inner block, not the outer condition.

### Positive Notes
- Correctly identifies that the channel does **not** resolve the child id itself — callers pass it — keeping `ModuleStateChannel` a pure transport and the addressing policy in the adapters.
- Token lifecycle is handled thoroughly: minted once per logical start, reused on the resume/`unpause` path (never regenerated → no duplicate child), and cleared on every reset path (`reset()` for breath; idle re-arm + `ModuleSessionAbandoned` for meditation).
- Distinguishes the root's stable-per-construction token (idempotent across reconnects) from the per-start child tokens correctly.
- Backward-compatible signature evolution (all-optional params) means no collateral edits and no risk to untouched call sites.

PLAN_REVIEW_PASS
