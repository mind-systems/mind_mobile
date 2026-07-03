# Code Review 2 — Start-race hardening (variant B): pending-start + timeout + retry keyed on `client_activity_id`

**Scope:** full `git diff HEAD` — `lib/Core/Grpc/ModuleStateChannel.dart` (bulk), `ModuleStateEvent.dart`, both adapters, `GlobalListeners.dart`, `App.dart`, `BiometricStreamClient.dart`, `KeepAliveCoordinator.dart`, l10n, and the test migration. Read each changed file in full against its surroundings.
**Verification:** `flutter test test/Core/Grpc/` → **132 passed** (incl. `start_race_contract_test.dart` and `reconnect_eviction_contract_test.dart`); prior full run of `test/Core/Grpc/ test/BreathModule/ test/MeditationModule/` → 464 passed. `flutter analyze` on the 7 changed production files → clean.
**Note:** the working tree has advanced since review-1 — `_resolveSettling` now carries the `isConnected` guard that review-1 flagged (`ModuleStateChannel.dart:544-546,552`). That finding is resolved. This pass is independent and surfaces one new correctness issue plus one lower-severity observation.

## Findings

### [Medium] Settling-window carried-pending re-send bypasses the 3-attempt budget → INV-12 violation and duplicate-child hazard past the dedup window

`_resolveSettling()` re-sends every surviving carried pending via `_sendStart` (`ModuleStateChannel.dart:550-554`) **without** the `p.attempts >= 3` budget check that lives only in `_onConfirmTimeout` (`:505-509`). `_sendStart` (`:483-495`) unconditionally increments `attempts`, sends the same-token command, and arms a fresh 5s timer. So a start whose budget was already spent can be re-sent again — once per reconnect — and only ever gives up when a *confirm-timeout* fires while connected, which the reconnect path keeps pre-empting.

**Concrete failure (single reconnect, budget already spent):**
- t0 connect → breath start attempt 1 (timer→t5)
- t5/t10 confirm-timeouts (connected, unconfirmed) → attempts 2, 3 (timer→t15)
- t12 transport drops → `_closeSessionStream` + `reconnecting`; the t15 timer is still armed
- t15 fires while `!isConnected` → transport-down branch re-arms without consuming a retry (`:512-517`); attempts stays 3
- t17 reconnect → `_openSessionStream` cancels the carried timer (`:203-206`), arms the 3s settling window
- t20 window closes → `_resolveSettling` → carried loop → `isConnected` true → `_sendStart` → **attempts = 4, a 4th command on the wire**, then t25 give-up.

That is a 4th wire attempt — INV-12 ("total start attempts never exceed 3") is violated. INV-12's contract test only elapses three 5s windows on a *single* connection (`start_race_contract_test.dart:93-114`), so it never exercises the reconnect-carried path and stays green.

**Why it matters (not just a counter):** on a **flapping** connection (backoff reopens every few seconds — subway/elevator), each completed 3s settling window re-sends the same carried pending, so a single unconfirmed start is re-emitted many times with the **same `client_activity_id` minted at t0**. Past the server's ~10 s idempotency window (`idempotencyWindowMs` default 10 000 — note 16 / mind_api), those re-sends are no longer deduped. Variant B's safety rests on "retry only while unconfirmed → no session to duplicate," but *client-unconfirmed* ≠ *server-absent*: if the server created the child and its ACTIVE/RESUMED frames were the ones lost across the flaps, a re-send after the dedup window creates a **duplicate child** — exactly the hazard note 19 §Key Findings calls out ("after the window there is no 'already exists' guard → duplicate child"). The 3-attempt budget is what bounds that exposure; the settling path removes the bound, making the number of stale-token re-sends (and the duplicate window) unbounded in wall-clock time.

**Fix:** route the carried re-send through the same budget/give-up logic instead of a raw `_sendStart`. Minimally, in the carried loop guard on the budget:
```dart
for (final type in carriedTypes) {
  final p = _pendingStarts[type];
  if (p == null || !isConnected) continue;
  if (p.attempts >= 3) { _pendingStarts.remove(type)?.timer?.cancel(); _events.add(SessionStartFailed(type)); continue; }
  _sendStart(p);
}
```
(or have the carried loop delegate to a shared "advance-or-give-up" helper that both `_onConfirmTimeout` and `_resolveSettling` call). The deferred-release path is unaffected — those pendings are freshly built with `attempts = 0`.

### [Low] Give-up resets the adapter, which auto-re-starts with a *new* token on the next state emission — repeating the snackbar and minting fresh un-deduped starts

On give-up, `SessionStartFailed(type)` is emitted; the owning adapter resets (`BreathModuleStateChannel.dart:53-58`, `MeditationModuleStateChannel.dart:35-40`), which clears `_started` and `_previousLifecycle`. Because the practice screen keeps emitting `running`/`active` state, the adapter's next emission re-enters the start path (`_handleLifecycle`: `wasInactive && isRunning && !_started`) and calls `_channel.start(...)` again with a **freshly minted** `client_activity_id`. So a give-up is not terminal: it surfaces "Couldn't start session" and then silently launches a brand-new 3-attempt cycle. Give-up only occurs while `isConnected` (the transport-down branch never gives up), i.e. connected-but-server-silent — unusual, so severity is low — but in that state the loop repeats every ~15 s with a new (never-deduped) token each cycle, both spamming the snackbar and widening the duplicate surface. Consider suppressing the immediate auto-restart after a give-up (e.g. require an explicit user re-tap), or debouncing it. This mirrors the existing `ModuleSessionAbandoned` reset-then-re-emit behavior, so it may be acceptable as-is — flagging for a conscious decision.

## Verified-correct (no action needed)

- **Cross-type fix + adopt:** dropping the shared `currentState.status == active` clause and gating on `_registry.childOfType(type)` correctly greens INV-10 cross-type / SC-1 while preserving same-type adopt (registry is upserted with every ACTIVE/RESUMED that flips single-state active, so adopt subsumes the old guard). Adopt precedes the settling defer in `start()` (`:398,414`).
- **Deferred vs carried disjointness:** step-2 pending guard (`:403`) makes a same-type defer impossible while a pending exists; `carriedTypes` is snapshotted before the deferred loop (`:541`) so a released deferred start is never double-sent in one pass.
- **Double-fire guard:** carried timers cancelled on reconnect open (`:203-206`) and only re-armed by `_resolveSettling`; a superseded reopen cancels the prior `_reconcileTimer` (`:192`) and inherits `_deferredStarts`/`_pendingStarts` into the new window rather than stranding them.
- **Timer hygiene:** `_clearPendingStart`, `_resetWholeTree`, and `dispose` all cancel per-pending timers; no leaks. `_sendStart` cancels any prior timer before arming.
- **Type-scoped adapter resets** avoid clearing a live concurrent sibling; whole-tree `ModuleSessionAbandoned`/`SessionTerminated` stay unfiltered as intended.
- **Wiring/compile:** `SessionStartFailed` added to both exhaustive switches (`BiometricStreamClient`, `KeepAliveCoordinator`); the sole `GlobalListeners(` site (`App.dart:319`) supplies the new required `sessionStartFailedStream`; l10n regenerated across arb + all three generated files.
