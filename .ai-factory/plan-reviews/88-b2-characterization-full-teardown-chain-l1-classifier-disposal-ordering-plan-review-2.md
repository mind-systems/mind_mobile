# Plan Review 2: B2 · Characterization — full teardown chain (L1 + classifier-disposal ordering)

**Plan file:** `.ai-factory/plans/88-b2-characterization-full-teardown-chain-l1-classifier-disposal-ordering.md`
**Target:** `test/Bci/neiry_bci_provider_full_teardown_test.dart` (new), `lib/Bci/NeiryBciProvider.dart` (read-only unless a red probe forces a gate fix)
**Risk Level:** 🟢 Low — all four concerns from review 1 are folded in; the plan is accurate against the current code and ready to implement.

## What changed since review 1

Review 1 withheld pass solely on Concern #1 (zone binding for Task 5) and listed three low-severity precision notes (#2–#4). All four are now addressed in the plan text:

| Review-1 concern | Status | Where addressed |
|---|---|---|
| #1 `runZonedGuarded` must also wrap `connect()` (listen-time zone) | ✅ Resolved | Task 5 now mandates inlining the whole flow (construction + `connect()` + drop + `_completeTeardown`) in one `runZonedGuarded`, with the listen-time-zone rationale and the explicit "do not reuse the outer-zone `_connectThenDrop`" instruction. |
| #2 per-case `closeControllers()` | ✅ Resolved | Task 4 enumerates each case (classifier-only / device-only); Task 5 calls for closing **both**. |
| #3 enumerate `StreamSubscription` surface | ✅ Resolved | Task 2 now lists `onData`, `onError`, `onDone`, `pause`, `resume`, `isPaused`, `asFuture<E>([E? futureValue])` to delegate. |
| #4 recorder threading order | ✅ Resolved | Task 3 now states "recorder → registry → locator → device", "do not use a late global", and the `if (instances.isNotEmpty)` guard for `'locatorCreate'`. |

## Verification performed (re-confirmed against current code)

- **Line-number mapping table** — re-checked line by line against `lib/Bci/NeiryBciProvider.dart`:
  - `:409` `try { await device?.stopStream(); } catch (_) {}` ✓
  - `:412-421` ten `await sub?.cancel()`, `connectionSub` first at `:412` ✓
  - `:425` `await classifierSet?.dispose();` inside try/catch `:424-428` ✓
  - `:432`/`:433` device disconnect/dispose inside try/catch `:431-436` ✓
  - `:437-439` `finally { await _resetLocatorSession(); }` (try/**finally**, no catch — confirms the throwing-cancel propagation claim) ✓
  - `:365` `_locator = _locatorFactory();` recreate ✓
  - `:189` `_connectionSub = _device!.connectionStateStream.listen(...)` inside `_subscribeDeviceStreams()`, called at `:185` from `connect()` ✓ (Task 5's listen-time-zone premise holds)
  - Constructor `NeiryBciProvider({locatorFactory, classifierFactory})` injectable ✓
- **B1 harness** (`test/Bci/neiry_bci_provider_locator_device_races_test.dart`): `GatedFakeDevicePort` (`throwOnDisconnect`/`throwOnDispose`, three gating completers, `emitConnection`, `closeControllers`), `RecordingLocatorPort` (double-dispose `StateError`), `RecordingLocatorRegistry` (`locatorFactory`, `instances`, `liveCount`, `createdCount`, `assertNoOrphan`), `_DropSetup`, `_connectThenDrop` (`:329`), `_completeTeardown` (`:375`) all exist exactly as the plan describes. ✓
- **A3 `FakeClassifierSet`** (`test/Bci/neiry_bci_provider_classifier_port_test.dart:120-165`): has `int disposeCallCount` + `bool throwOnDispose`, seven broadcast controllers, no `closeControllers()` yet — matches the plan's "use the A3 variant and add a `closeControllers()` helper". ✓
- **Throw-propagation (Task 5):** confirmed the microtask body is `try { … } finally { _resetLocatorSession(); }` with no intervening catch — a throwing `cancel()` at `:412` short-circuits the chain, the `finally` still recreates, and the rejected microtask is unobserved in a pure drop. ✓
- **Ordering (Task 6):** the execution order in `_teardownAfterUnexpectedDrop` is exactly `stopStream → (connectionSub.cancel first) → classifierDispose → deviceDisconnect → deviceDispose → locatorDispose → locatorCreate`, matching the canonical list. ✓

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`):** present. Test-only suite exercising existing A1/A2/A3 port seams; no boundary or dependency impact. WARN: none.
- **Rules (`.ai-factory/RULES.md`):** present; rules concern module Service statelessness / DI / App.dart wiring — none apply to a characterization test file. No violation.
- **Roadmap (`.ai-factory/ROADMAP.md`):** present. Plan is milestone B2 of the BCI characterization → C1-refactor track and explicitly frames itself as the second half of the contract (with B1) that the C1 actor refactor must keep green. Linkage stated. WARN: none.
- **skill-context `aif-review/SKILL.md`:** not present — no project-specific review overrides.

## Critical Issues

None.

## Minor observations (non-blocking — implementer will handle naturally)

1. **Single `'cancelFanIn'` record under a wrapped classifier stream.** Task 2 wires *two* streams through `ThrowOnCancelStream` (device `connectionStateStream` **and** a classifier stream, e.g. `nfbStateStream`), while Task 3's label map assigns `'cancelFanIn'` only to the connection-sub `cancel()`. For Task 6's canonical-order equality to hold, the classifier-stream wrapper must record **no** order label (only the connection wrapper appends). Task 2's "optionally append a label" wording supports this, and Task 3's label table is authoritative, so this is already implied — just keep the nfb-wrapper's order label unset so the pure-drop sequence stays exactly seven steps.

2. **`runZonedGuarded` with an async body (Task 5).** The inlined flow is async, so the body must be awaited (`await runZonedGuarded(() async { … }, onError)` or equivalent) before the extra `Future<void>.delayed(Duration.zero)` pumps and assertions run. Trivial, but worth keeping in mind so the test doesn't assert before the guarded body has progressed.

Neither blocks implementation.

## Positive Notes

- **All four review-1 concerns are addressed in the plan text**, not hand-waved — Task 5 in particular now carries the full listen-time-zone explanation and the explicit instruction not to reuse the outer-zone helper, which was the only substantive risk last round.
- **Line remapping remains exact.** The stale-spec → current-code mapping is correct line by line, including the subtle try/**finally**-without-catch detail that the entire Task 5 propagation argument depends on.
- **"Throw after cancelling" wrapper semantics** correctly mirror the spec's "thrown anywhere in the cancel chain still recreates" without leaking an un-cancelled inner controller.
- **Behavioral-only assertions** (create/dispose counts, `assertNoOrphan`, observed step labels) with the explicit no-coupling-to-`_teardownComplete` constraint future-proof the suite against the C1 actor refactor — consistent with B1's design.
- **Churn caveat** under the concurrent-`disconnect()` race (`liveCount <= 1` + `assertNoOrphan` instead of a tight create count) matches how B1 already handles the same interleaving, and is sound: `disconnect()` awaits `_teardownComplete` first, so the drop unit stays contiguous before any disconnect-driven reset churn.
- **Task 5 decision rule** (if the recreate invariant comes back red, fix the gate minimally by wrapping `:412-421`; never weaken the invariant) is a well-reasoned escape hatch that keeps the characterization honest.

## Recommendation

The plan is technically solid, accurately grounded in the current code, and resolves every concern raised in review 1. The two observations above are precision notes the implementer will handle in the natural course of writing the suite. Ready to implement.

PLAN_REVIEW_PASS
