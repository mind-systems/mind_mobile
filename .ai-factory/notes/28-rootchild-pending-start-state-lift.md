# Root/child — pending-start state lift (behaviour-preserving)

**Date:** 2026-07-04
**Source:** conversation context (milestone-rescue of task 26); structural root-cause analysis of the 3-round review chain

## Key Findings

- Task 26's three-round review chain all shared **one** root cause: the pending-start subsystem has multiple resolution sites, and each new site re-implemented the "how to send / when to give up" contract by hand and missed a precondition. Round 1: `_resolveSettling` sent without the `isConnected` guard `_onConfirmTimeout` had. Round 2: `_resolveSettling` sent without the 3-attempt **budget** guard `_onConfirmTimeout` had. Round 3: the give-up surface those fixes created shipped untested. Three symptoms, one structural defect.
- The pending-start state is currently **implicit and scattered**: which map a start lives in (`_pendingStarts` vs `_deferredStarts`) + a nullable timer (armed vs carried) + `_settlingActive` together encode ~5 states (armed / carried / deferred / confirmed / given-up) with no single owner of the transitions. This is exactly the "implicit and scattered connection state" that note 25 replaced with an explicit `ConnectionLifecycle` FSM — but note 25 **explicitly excluded** pending-start from that FSM ("keeps `_isPendingStart`/`_isPendingPause` out of the FSM"), correctly, *because at the time it was a single bool `_isPendingStart`*. Task 26 then grew that single bool into a multi-state subsystem **without revisiting the exclusion** — that is the spec gap this task closes.
- Fix shape: make the states **explicit** and route **every** resolution trigger (`_onConfirmTimeout`, `_resolveSettling`, confirm-clear, and the future per-child reconcile of note 29) through **one guarded chokepoint** that owns the `isConnected` + budget preconditions, so a new resolution site **cannot** skip a precondition. The `_giveUp` consolidation (task 26, review 2) is half of this already — extend it so the *send* decision is equally centralised.
- **The enum is secondary; the chokepoint is load-bearing.** Do not cargo-cult a full `_transition` hub mirroring `ConnectionLifecycle` if a lighter explicit-state + single-chokepoint form suffices — the failure mode is a skipped precondition, which the chokepoint prevents, not the enum.
- **Behaviour-preserving.** Lands under note 27's golden master **and** the existing `start_race_contract_test.dart`; no invariant changes, no observable behaviour change. Same discipline as the note-25 lift.

## Details

### Current state (exact — commit `93f3e92`)
- `_pendingStarts` (armed, own confirm timer) and `_deferredStarts` (awaiting settling) — membership + nullable `timer` field encode the state.
- `_settlingActive` gates the reconnect settling window; `_resolveSettling` `ModuleStateChannel.dart:~530-570` resolves carried + deferred starts.
- Guards live in the **callers**: `_onConfirmTimeout` `:~505-517` checks `isConnected` and budget; `_resolveSettling` `:544-569` had to re-add both (`isConnected` at `:544-546`, budget via `_giveUp` at `:566-569`).

### Change (refactor — behaviour-preserving)
- Introduce an explicit pending-start state representation (armed / carried / deferred / confirmed / given-up) — enum or equivalent — replacing the implicit map-membership + nullable-timer + `_settlingActive` encoding where it clarifies transitions.
- Introduce a **single guarded chokepoint** through which all send/advance decisions flow, with the `isConnected` + 3-attempt-budget preconditions **inside** it. `_onConfirmTimeout`, `_resolveSettling` (carried and deferred-release paths), and confirm-clear all route through it; no caller re-checks the preconditions.
- Keep the pending-start logic **command-level** (note 25 §Guards — out of the `ConnectionLifecycle` FSM); this lift is orthogonal to the connection FSM, it only makes the command-level state explicit.

### Guards
- No invariant change: INV-8/9/10/11/12 and SC-1/2/3/7 stay green on `start_race_contract_test.dart` **unmodified**.
- Note 27's golden-master assertions stay green **unmodified** — this is the proof the lift preserved behaviour.
- Do not fold in note 29 (per-child consumption) — that is a separate concern that *lands on* this chokepoint but ships independently.

### Verify
- `flutter test test/Core/Grpc/` fully green — note 27 tests + `start_race_contract_test.dart` unchanged — after the refactor.
- A new resolution site (note 29) can plug into the chokepoint without re-stating `isConnected` or budget guards.
