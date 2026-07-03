# Plan Review 2 — Start-race hardening (variant B): pending-start + timeout + retry keyed on `client_activity_id`

**Plan:** `26-start-race-hardening-variant-b-...md`
**Files Reviewed:** 8 production + 2 test / test-support files, plus the contract spec, roadmap and note context
**Risk Level:** 🟢 Low

## Verdict

This is the revised plan after plan-review-1. **All five issues from review 1 are resolved in the plan text**, and I re-verified every anchor and the contract-test trace against the current tree — the design greens all RED scenarios in `start_race_contract_test.dart` and preserves the GREEN-now guards without regression. The plan is ready to implement.

### Resolution of review-1 issues

1. **Commit-1 compile ordering (was Critical).** Fixed. Task 2 now explicitly folds the `SessionStartFailed` class definition **and** both exhaustive-switch cases (`BiometricStreamClient._onLifecycleEvent`, `KeepAliveCoordinator._onEvent`) into the same task/commit as the emit site ("the fix for review issue 1"). Commit 1 compiles standalone. ✅
2. **Type-scoped adapter reset.** Fixed. Task 3 now gates each adapter's reset on its own `event.type` (`SessionStartFailed && event.type == ActivityType.breath` / `.meditation`), and explicitly preserves the unfiltered whole-tree resets for `ModuleSessionAbandoned`/`SessionTerminated`. ✅
3. **`_beginStart` defined; released deferred start becomes pending.** Fixed. The new "Design: the two send helpers" section defines `_beginStart` (registers pending + owns confirm-timeout/retry lifecycle) vs `_sendStart` (send + arm timer, no registration). Task 4 releases a deferred start via `_beginStart`, so it gets its own 5s timeout + bounded retry — closing the INV-8 gap. ✅
4. **Offline-timer vs settling-window double-fire.** Fixed. Task 4 adds an explicit double-fire guard: while `_settlingActive`, the window owns carried-pending resolution exclusively and cancels each carried pending's own confirm timer on window-arm. ✅
5. **Adopt precedes settling defer.** Fixed. Task 1 pins adopt as step 1; Task 4 inserts the settling check after adopt so an already-live same-type child is adopted immediately even during settling. ✅

### Context Gates

- **Roadmap (PASS):** Heading matches the Phase-65 contract line; `Spec: .ai-factory/notes/19-...`. Governing contract note 24 → impl note 19. Aligned. ✅
- **Rules (PASS):** All pending/timeout/retry state stays command-level in `ModuleStateChannel` (note 25 §Guards — pending-start kept out of the FSM); the FSM is only read (`isReconnectOpen`). Adapters remain token minters, no token-reuse change. App.dart wire mirrors the existing `sessionAbandonedStream` shape. ✅
- **Architecture (PASS):** Domain/module boundary respected; no domain leak into packages. ✅

## Anchor verification (all accurate)

`ModuleStateChannel.dart`: `_isPendingStart` `:44`, start guard `:333`, `start()` `:332-343`, RESUMED clear `:232-233`, ACTIVE clear `:242-243`, `_resetWholeTree` `:426-431`, reconcile window `:145-157`, `_arrivedChildIds` `:56`, `_lifecycle` `:68`, `_transition` `:73`, connected handler `:108-122`, `takeOverHere` `:324-328`, `childOfType` `:38`, `dispose` `:441-450` — all exact.
Adapters: `BreathModuleStateChannel` events listener `:52-54`, mint `:94-100`, `_clientActivityId` `:24`; `MeditationModuleStateChannel` events listener `:34-42`, mint `:54-60`, `_clientActivityId` `:17` — all exact.
`ModuleStateEvent.dart` sealed hierarchy present; `BiometricStreamClient._onLifecycleEvent` exhaustive switch `:96-116` (the `SessionTerminated` case is at `:111`); `KeepAliveCoordinator._onEvent` exhaustive switch `:46-63`; `GlobalListeners` `sessionAbandonedStream` `:24`/`:51-53`; `App.dart` GlobalListeners construction `:319-322`. l10n keys `sessionAbandoned`/`sessionMovedToAnotherDevice` exist in `app_en.arb`. Test anchors `module_state_channel_test.dart` `:292` pending-guard test (`:302` comment), `:184` RESUMED group, `:667` ACTIVE group — all present.

**No missed exhaustive switch.** I swept every `ModuleStateEvent` consumer: only `KeepAliveCoordinator` and `BiometricStreamClient` switch exhaustively over the sealed type; the adapters use `if (event is …)`, and `App.dart`/`GlobalListeners`/`HomeService` use `.where((e) => e is …)` — none break on a new subtype. The plan's two-switch list is complete.

### Contract-test trace (spot-checked, greens without regression)

- INV-8/INV-9/SC-2: first send (attempts→1) → 5s timeout, `isConnected` true → same-token resend (attempts→2). 2 wire starts, second reuses `firstId`. ✅
- INV-12 ceiling: sends at attempts 1/2/3, give-up at `attempts >= 3` with no 4th send → exactly 3. ✅
- INV-8 post-confirm: ACTIVE clears `_pendingStarts[type]` + timer → 10s elapse sends nothing. ✅
- INV-10/SC-7 adopt: RESUMED populates registry → `start()` step-1 adopt returns, no send. ✅
- INV-10 cross-type & SC-1 concurrent: per-type pending map + dropped `status==active` clause let the un-started type reach the wire. ✅
- INV-11/SC-3 defer→adopt and defer→release: `_settlingActive` on reconnect open defers; reconcile adopts if `childOfType != null` else releases via `_beginStart`. ✅

## Minor observations (non-blocking — clarify during implementation)

### A. Pin the settling-defer position relative to the per-type pending guard
Task 1's `start()` order is adopt → pending-guard → `_beginStart`; Task 4 inserts the settling defer "after the adopt-existing step and before the send." That phrasing leaves the defer's position relative to the **pending guard** unpinned. The safe order is adopt → **pending guard** → settling defer → `_beginStart`: if a same-type pending is already carried into the settling window, the pending guard should short-circuit so the window's carried-pending resolution (not a second deferred entry) owns it. The contract tests don't exercise both a carried pending and a deferred start for the same type at once, so either ordering passes today — but pinning it avoids a latent double-tracking bug. Recommend stating it explicitly in Task 4.

### B. Give-up + adapter re-arm can silently re-loop while the module session is still running
On `SessionStartFailed`, Task 3 resets the owning adapter (`_started = false`, `_previousLifecycle`/`_previousStatus = null`). But the underlying `BreathSessionState`/`MeditationSessionState` is still in its running/active lifecycle and emits frequently; the next emission re-satisfies `wasInactive && isRunning` (resp. `active && !_started`) and fires a **fresh** `start()` with a new `client_activity_id` and a fresh 3-attempt budget. So "give up after retries" is not terminal from the adapter's side — it silently restarts the whole retry cycle after showing the snackbar. This may be intended (auto-retry on the next tick) or unwanted (repeated snackbars / unbounded re-loop). It's outside the contract tests' scope and doesn't block the plan, but confirm the intended semantics against note 19 and, if terminal-until-user-re-tap is desired, add a per-type "gave up" latch that a genuine fresh user tap clears. Symmetric for both adapters.

## Positive Notes

- The revision addresses every review-1 issue **in the plan text itself**, each cross-referenced to its issue number — no silent hand-waving.
- The `_beginStart`/`_sendStart` split is the right factoring: it makes "register-then-send with confirm-timeout ownership" the single shape used by the initial send, the retry, and the deferred-release, which is exactly what closes the INV-8 gap on the reconnect path.
- Attempt-counting model (increment on send, give up at `attempts >= 3`) yields exactly 3 wire sends across three 5s windows — matches INV-12's `lessThanOrEqualTo(3)` precisely.
- First-connect vs reconnect discrimination via `isReconnectOpen = _lifecycle != disconnected` at `_openSessionStream` top correctly leaves first-connect timing untouched (INV-8/SC-2).
- Test-migration discipline (one-pass audit of the full blast radius, no weakening of the contract assertions) is carried forward and the migration anchors are accurate.

## Recommendation

The plan is solid, well-grounded, and fully addresses the prior review. Observations A and B are clarifications to fold in during implementation, not blockers.

PLAN_REVIEW_PASS
