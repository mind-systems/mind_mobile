## Code Review Summary

**Files Reviewed:** plan `22-…-red-scenarios-no-production-code.md` (revised) + targeted codebase (`lib/Core/Grpc/ModuleStateChannel.dart`, `lib/BreathModule/Core/BreathModuleStateChannel.dart`, `lib/MeditationModule/Core/MeditationModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`, `test/BreathModule/breath_module_state_channel_test.dart`) + prior plan-review-1
**Risk Level:** 🟢 Low

### Context Gates
- **Roadmap linkage — OK.** Plan title matches `ROADMAP.md:78`; governing spec note 24 encoded as INV-1…12 / SC-1…7; impl split (note 20 = eviction/reconnect, note 19 = start-race) matches roadmap lines 79–80. (Re-confirmed by plan-review-1; unchanged this round.)
- **ARCHITECTURE.md — OK.** Test-only milestone; touches nothing under `lib/`.
- **RULES.md — OK.** All three rules concern production code; no conflict with a `test/`-only deliverable.
- **skill-context — absent.** No `.ai-factory/skill-context/aif-review/SKILL.md`; general rules only.

### Plan-review-1 issues — all resolved
- **CI-1 (RED scenarios that were GREEN today) — FIXED.**
  - INV-7 now explicitly labelled **GREEN-now guard** (`plan:75`), with the correct code anchors (`ModuleStateChannel.dart:152-159` / `_upsertRegistryEntry:205-214`) and existing-coverage reference.
  - INV-10 / SC-7 now split (`plan:86-88`): same-type adopt = GREEN-now guard (early-return at `:237`), cross-type suppression = the RED case. Verified: with a live meditation child, `currentState.status == active`, so a breath `start()` returns early at `:237` and no `activityStart` reaches the wire → genuinely RED and wire-observable. Correct.
  - INV-4 now reframed to the stale-root-on-reconnect angle (`plan:72`): registry is not cleared on `_closeSessionStream` (`:136-141`), so the pre-reconnect `rootId` (`_registry.rootId`, `:35`) persists across reopen. Child RESUMED frames upsert children only and never set `rootId`, so the assertion "`rootId` does not still resolve to the pre-reconnect root" fails today → RED. Then a ROOT re-open frame restores it. Correct.
- **CI-2 (SC-1 asserted on forbidden per-type pending field) — FIXED.** Task 5 (`plan:92-93`) now states "Assert purely on the wire — never on per-type pending fields (guard)" and re-expresses SC-1 as "both breath's and meditation's `activityStart` reach the wire" — today the second is dropped at `:237` because the shared `_isPendingStart` is already set → RED, wire-observable. Correct.
- **Minor: harness inputs — FIXED** (`plan:57`). `authStream` (→ `StreamController<AuthState>`) and `instructionStream` (→ fake `BreathModuleInstructionStream`) now called out. Verified against real constructors: `ModuleStateChannel(... authStream)` (`:70`), `BreathModuleStateChannel(channel, stateStream, instructionStream, sessionId)` (`:34-38`), `MeditationModuleStateChannel(channel, stateStream, refId)` (`:22-25`). All accurate.
- **Minor: null-sink ordering pin — FIXED** (`plan:58`). Push `connected` + flush before any adapter emits active, else `channel.start` is dropped by `_sendSessionRequest:292-298`. Correct.
- **Minor: fakeAsync vs microtask-pump mixing — FIXED** (`plan:21`). Mandates `async.flushMicrotasks()` after each emission inside the `fakeAsync` zone, no `Future.delayed`, mirroring the bio precedent.
- **Minor: SUPERSEDED-close vs resume counter bookkeeping — FIXED** (`plan:64`). Separate `test()`s / baseline-delta assertions now required so a reader can tell which half regressed.

### Verified against current code (this round)
- `_FakeModuleStateServiceClient.calls` with per-call `options` / `sentRequests` / `responseCtrl`, and `_FakeConnectionManager` counters (`confirmConnectedCount` / `disconnectCount` / `scheduleReconnectCount`) exist exactly as the harness plan describes (`module_state_channel_test.dart:36-91`).
- `onDone`/`onError` both `disconnect()` + `scheduleReconnect()` (`:120-131`); reopen-on-`connected` is unconditional (`:75-76`); single `start()` guard is `currentState.status == active || _isPendingStart` (`:237`); shared `_isPendingStart` (`:42`). All plan anchors accurate.
- Adapter constructors type on the **real** `ModuleStateChannel`, so `wireConcurrent(...)` binding the real channel (not `_FakeChannel`) type-checks.

### Minor Issues / Suggestions (non-blocking)
- **INV-6 — clarify the frame that drives the "{abandoned} reset" (`plan:74`).** There is no global-reset / `AllSessionsReset` seam today, and the plan (correctly) forbids asserting on that not-yet-existing symbol. The RED framing still works through the current surface: a **root-typed ABANDONED frame** does `removeTerminal(rootId)` only (`_handleRootFrame:227-231`) and does **not** cascade to children, so after a fresh ROOT frame the registry ends with new-root **plus** the stale child → the "no stale children" assertion fails today → RED. But the plan wording ("an `{abandoned}` reset is applied") leaves the injecting frame implicit; note that a `session_error{no_active_session}` frame instead calls `_registry.clear()` (`:112-114`) and would make the scenario GREEN. Recommend the plan pin "root-typed ABANDONED frame" explicitly so the implementer doesn't accidentally pick the clearing path.
- **INV-11 defer (`plan:94`) — RED-ness is state-precondition-dependent.** "Tap start within the settling window → assert no `activityStart` (deferred)" is only RED if the local single-state is **idle** at that moment (today an idle start fires immediately → RED, should defer). If the pre-reconnect single-state is still `active` across the reopen (it is not reset by `_closeSessionStream`), `start()` early-returns at `:237` and the "no `activityStart`" assertion passes → **GREEN**, masking the missing defer. Recommend the plan nail the idle single-state precondition for the deferring adapter (e.g. drive the defer on a type whose local single-state is idle while the *other* type's child is the one resuming). The plan's empirical-RED hard guard (`plan:13`) is the safety net here, but pinning the precondition avoids a chase.

### Positive Notes
- Every blocking and minor point from plan-review-1 was addressed precisely and with correct code anchors — the revision is disciplined, not cosmetic.
- The empirical-RED hard guard (`plan:13`) plus the explicit GREEN-now-guard category gives the implementer a principled fallback for any scenario that turns out green, which de-risks the two residual state-dependent framings above.
- Real-channel/real-adapter stateful doubles (m36), copy-not-import fakes, the single `skip:`-annotated seam for `takeOverHere()` (INV-3), and the "do not assert on `_yielded`/`AllSessionsReset`/per-type pending" list remain exactly the right constraints.

Overall: the revised plan is solid and well-grounded. The two remaining items are precondition-clarity suggestions the empirical-RED guard already backstops — neither blocks implementation.

PLAN_REVIEW_PASS
