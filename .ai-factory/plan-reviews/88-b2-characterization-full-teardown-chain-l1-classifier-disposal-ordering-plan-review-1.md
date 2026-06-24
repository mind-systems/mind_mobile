# Plan Review: B2 · Characterization — full teardown chain (L1 + classifier-disposal ordering)

**Plan file:** `.ai-factory/plans/88-b2-characterization-full-teardown-chain-l1-classifier-disposal-ordering.md`
**Target:** `test/Bci/neiry_bci_provider_full_teardown_test.dart` (new), `lib/Bci/NeiryBciProvider.dart` (read-only unless a red probe forces a gate fix)
**Risk Level:** 🟡 Medium — one real technical gap (zone binding in Task 5) worth closing before implementation; everything else is accurate.

## Verification performed

I read the production target and both reuse sources in full and cross-checked every line reference:

- **Line-number mapping table is accurate** against the current `lib/Bci/NeiryBciProvider.dart`:
  - `:409` `try { await device?.stopStream(); } catch (_) {}` ✓
  - `:412-421` ten `await sub?.cancel()` ✓ (connectionSub first at `:412`)
  - `:425` `await classifierSet?.dispose();` inside try/catch `:424-428` ✓
  - `:432`/`:433` device disconnect/dispose inside try/catch `:431-436` ✓
  - `:437-439` `finally { await _resetLocatorSession(); }` ✓
  - `_resetLocatorSession()` recreate at `:365` `_locator = _locatorFactory();` ✓
  - Constructor `NeiryBciProvider({locatorFactory, classifierFactory})` injectable ✓
- **B1 harness fakes exist as described** in `test/Bci/neiry_bci_provider_locator_device_races_test.dart`: `GatedFakeDevicePort` (with `throwOnDisconnect`/`throwOnDispose`, three gating completers, `emitConnection`, `closeControllers`), `RecordingLocatorPort` (double-dispose `StateError`), `RecordingLocatorRegistry` (`locatorFactory`, `instances`, `liveCount`, `createdCount`, `assertNoOrphan`), `_DropSetup`, `_connectThenDrop` (`:329-370`), `_completeTeardown` (`:375-384`). ✓
- **A3 `FakeClassifierSet` variant** at `test/Bci/neiry_bci_provider_classifier_port_test.dart:120-165` has `int disposeCallCount` + `bool throwOnDispose` exactly as cited. ✓ Note: it does **not** yet have a `closeControllers()` helper — the plan correctly calls for adding one (Task 1).
- **Ordering claim (Task 6) matches the microtask body** in `_teardownAfterUnexpectedDrop` (`:404-440`): `stopStream → cancelFanIn → classifierDispose → deviceDisconnect → deviceDispose → locatorDispose → locatorCreate` is the exact execution order. ✓
- **Throw-propagation analysis (Task 5) is correct**: the cancels at `:412-421` are NOT individually wrapped, so a throwing `cancel()` short-circuits the chain and propagates to the `finally` at `:437-439`, which still runs `_resetLocatorSession()` → recreate reached; the rejected microtask is unobserved in a pure drop. ✓

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present. No boundary impact — this is a test-only suite exercising existing A1/A2/A3 ports. WARN: none.
- **Rules (`.ai-factory/RULES.md`):** present; rules concern module Service statelessness / DI / App.dart — none apply to a characterization test file. No violation.
- **Roadmap (`.ai-factory/ROADMAP.md`):** present. This is milestone B2 of the BCI characterization → C1-refactor track; the plan explicitly frames itself as the second half of the contract (with B1) that the C1 actor refactor must keep green. Linkage is stated. WARN: none.
- **skill-context `aif-review/SKILL.md`:** not present — no project-specific review overrides to apply.

## Critical Issues

None that block, but one item below should be addressed to avoid a wasted green-up round.

## Concerns (should address before implementing)

### 1. Task 5 `runZonedGuarded` will not capture the async error unless `connect()` also runs inside the guarded zone (Medium)

The plan says: *"Run the drop + teardown completion inside `runZonedGuarded`, capturing async errors into a list."* This is insufficient as written.

The rejected future is `_teardownComplete = Future.microtask(() async {...})`. `Future.microtask` binds to the zone that is current **when `_teardownAfterUnexpectedDrop()` runs** — and that method runs synchronously inside the `_onConnectionStatus` callback, which executes in the zone where the subscription was **registered** (`_subscribeDeviceStreams()`'s `device.connectionStateStream.listen(...)`). That `listen()` happens at the end of `connect()` (`:185`/`:189`). Dart binds stream-event delivery to the **listen-time zone**, not the `add()`/`emitConnection()`-time zone.

Consequence: if `connect()` (via `_connectThenDrop`) runs in the outer test zone and only the `emitConnection` + gate-completion runs inside `runZonedGuarded`, the unhandled rejection surfaces in the **outer** zone → flutter_test reports it as an uncaught async error and the test **fails**, while the `runZonedGuarded` error list stays empty.

**Fix (pick one, and state it in the plan):**
- Run the whole flow — provider construction + `connect()` + drop + `_completeTeardown` — inside the single `runZonedGuarded` body (i.e. don't reuse the outer-zone `_connectThenDrop`; inline an equivalent, or give it an optional zone-aware variant). This is the robust option.
- Or, if the error need not be asserted, drop `runZonedGuarded` and instead `await provider.disconnect()` (or `scan().first`) after the drop — those paths `await _teardownComplete` inside `try { … } catch (_) {}` (`:160`, `:475`), swallowing the rejection cleanly — but then the "captured error list contains the injected `StateError`" assertion is no longer possible. Since the plan explicitly wants that assertion, the first option is the intended one.

Recommend amending Task 5 to state explicitly that `connect()` must execute within the same guarded zone as the drop, with a one-line rationale (listen-time zone binding). After completing teardown, pump a couple extra `await Future<void>.delayed(Duration.zero)` so the unhandled-rejection report reaches the guarded handler before asserting.

### 2. Task 4 — both `closeControllers()` may be needed, not just one (Low)

The plan notes closing controllers in cleanup when a `dispose()` throws. Worth being explicit per case so the implementer doesn't leak a controller and get a "stream was not closed" warning:
- `classifierSet.throwOnDispose = true`: classifier dispose (`:425`) throws and is swallowed; device disconnect/dispose still run → call `classifierSet.closeControllers()` only.
- `device.throwOnDisconnect = true`: disconnect (`:432`) throws, so device `dispose()` (`:433`) is **skipped** (same try-block) → device controllers stay open **and** classifier set was disposed normally → call `device.closeControllers()` only.
- `device.throwOnDispose = true`: disconnect succeeds, dispose throws after the disconnect → device controllers stay open → call `device.closeControllers()` only.

Note the throwing-cancel probe (Task 5) is the only case where **both** classifier dispose and device dispose are skipped (cancel short-circuits before either), so that test needs both `device.closeControllers()` and `classifierSet.closeControllers()`. Calling this out in Task 5's cleanup avoids an un-closed-controller flake.

### 3. Task 2 — enumerate the `StreamSubscription` surface to delegate (Low)

`_ControllableCancelSubscription<T> implements StreamSubscription<T>` must delegate the full surface, not just the data callbacks: `onData`, `onError`, `onDone`, `pause`, `resume`, `cancel` (overridden), `isPaused`, and `asFuture<E>`. The plan says "delegates all methods" — fine, but listing `asFuture`/`isPaused` explicitly prevents an "abstract method not implemented" compile error, since the provider only ever calls `cancel()` and the others are easy to forget.

### 4. Recorder threading — construct before L0 (Low / confirm)

Task 3's `TeardownOrder` must be injected into the registry **before** the provider is built, because the registry's `locatorFactory` vends L0 inside the `NeiryBciProvider` constructor and the factory needs the recorder to (a) append `'locatorCreate'` on replacement and (b) hand the recorder to each `RecordingLocatorPort`, which in turn hands it to each `GatedFakeDevicePort` it vends via `createDevice`. The "skip initial L0 construction" rule is cleanly implementable as `if (instances.isNotEmpty) order.steps.add('locatorCreate')` since L0 is the only call made while `instances` is empty. No change needed — just confirming the wiring order (recorder → registry → locator → device) is feasible and should be stated so the implementer threads it through constructors rather than as a late global.

## Positive Notes

- **Line-number remapping is exactly right.** The plan caught that the spec/milestone use stale pre-A3-port numbers and produced an accurate current-code mapping — verified line by line. This is the highest-risk part of a characterization plan and it's correct.
- **Self-contained-fakes decision is sound** and matches the existing codebase convention (A3 and B1 each define their own `FakeClassifierSet`). Explicitly forbidding edits to the committed, already-green B1 file is the right call for a contract suite.
- **"Throw after cancelling" semantics** for the wrapper is the correct design — it mirrors the spec's "thrown anywhere in the cancel chain still recreates" without leaving the underlying controller un-cancelled, which would otherwise leak.
- **Behavioral-only assertions** (create/dispose counts, `assertNoOrphan`, observed step labels) with the explicit no-coupling-to-`_teardownComplete` constraint correctly future-proof the suite against the C1 actor refactor that removes the gate field — consistent with B1's stated design.
- **Churn caveat** (`liveCount <= 1` + `assertNoOrphan` instead of tight create counts under the concurrent-`disconnect()` race) is the right relaxation and matches how B1 already handles the same interleaving (`:441-502`).
- **Task 5 decision rule** (if the recreate invariant comes back red, fix the gate minimally by wrapping `:412-421` in try/catch; never weaken the invariant) is a well-reasoned escape hatch that keeps the characterization honest.

## Recommendation

The plan is technically solid and well-grounded in the actual code. The only substantive item is Concern #1 (zone binding for Task 5's `runZonedGuarded`), which will otherwise cost a red round during green-up. Concerns #2–#4 are low-severity precision notes. Recommend folding Concern #1 into Task 5 (and the cleanup note from #2 into Tasks 4–5) before implementation; with that one clarification the plan is ready.

Withholding pass solely for Concern #1.
