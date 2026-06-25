# Derive BreathLifecycle + isLive on the output schema (additive) (T3)

**Date:** 2026-06-24
**Source:** conversation context (breath lifecycle FSM refactor planning)

## Key Findings

- The keep-alive signal can be delivered **without touching** the engine's progression or its internal representation: add a computed `BreathLifecycle lifecycle` + `bool isLive` to the emitted state, **derived** from the existing `status` + `_hasStarted`. This de-risks the whole effort — consumers ([[168-breath-audio-islive]] / [[169-breath-fgs-local-keepalive]] / [[170-breath-channel-explicit-lifecycle]]) migrate on this alone, and the risky internal extraction ([[171-breath-extract-owned-lifecycle-fsm]]) becomes pure behavior-preserving cleanup.
- Derivation: `complete → completed`; `status ∈ {breath,rest} → running`; `status == pause & _hasStarted → paused`; `status == pause & !_hasStarted → notStarted`. `isLive = lifecycle ∈ {running, paused}` — true through manual pause, false for not-started and completed (matches the confirmed keep-alive window).

## Details

- **`BreathSessionState.dart`** — add `enum BreathLifecycle { notStarted, running, paused, completed }`; add field `BreathLifecycle lifecycle` + `bool get isLive => lifecycle == BreathLifecycle.running || lifecycle == BreathLifecycle.paused`. Add to the constructor / `copyWith` (`:112`). **Include `lifecycle` in `equalsIgnoringTickFields` (`:95`)** — it is a structural field and must trigger Riverpod publication.
- **`BreathSessionStateMachineState`** (`BreathSessionStateMachine.dart:13`) — add the same `lifecycle` field; compute it in every `_emit`/`_initialRestState`/`_initialBreathState`/`pause`/`resume`/`complete` construction from `(status, _hasStarted)` (both in scope). The progression math (`_onBreathTick`/`_onRestTick`/`_advanceExercise`/`_startRest`/`_startNewCycle`) is **not** touched — only the emitted struct gains a field.
- **`BreathViewModel`** — carry `lifecycle` through the full-constructor sites `_setupEngine` (`:152`) and `_onEngineState` (`:189`).
- **TDD:** write the red contract tests first (via [[165-breath-headless-activity-harness]]): `isLive` true through pause, false not-started/completed; the lifecycle transition table. Then make green by adding the derived field.

## Guards

- **Purely additive** — `status` stays and keeps its current semantics; nothing reads `lifecycle` yet (consumers migrate in T4–T6). Do **not** remove `_hasStarted` here (that is [[171-breath-extract-owned-lifecycle-fsm]]). Keep progression untouched.

## Verify

- New `lifecycle`/`isLive` suite green; the [[166-breath-activity-characterization-golden-master]] golden master still green (`status` semantics unchanged).
