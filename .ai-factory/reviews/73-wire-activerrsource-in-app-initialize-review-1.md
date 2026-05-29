# Code Review: Wire `activeRrSource` in `App.initialize()`

**Plan:** `.ai-factory/plans/73-wire-activerrsource-in-app-initialize.md`
**Spec:** `.ai-factory/notes/29-heart-rate-tick-source.md` — Milestone 2
**Files changed:** `lib/Core/App.dart` (+4 lines, 0 deletions)

## Scope verification

`git status` confirms only one source file changed (`lib/Core/App.dart`); the other staged entries are the plan and plan-review documents. Diff inspected in full.

## Correctness

| Check | Verdict |
|---|---|
| Import path `package:mind/Biometrics/ActiveRrSource.dart` matches the existing file at `lib/Biometrics/ActiveRrSource.dart` | ✅ |
| Import placement (line 56) sits with the other `lib/Biometrics/...` imports, between `NeiryBciProvider.dart` and `BioStreamRouter.dart` — alphabetical and grouped | ✅ |
| Field `final ActiveRrSource activeRrSource;` (line 90) declared next to the other biometrics fields, between `bioStreamRouter` and `biometricStreamClient` — matches plan Task 2 | ✅ |
| `App._({...})` constructor parameter list (line 117) adds `required this.activeRrSource,` in the same relative position as the field — order parity preserved | ✅ |
| Construction `final activeRrSource = ActiveRrSource([bciProvider]);` (line 195) lands immediately after `bioStreamRouter.registerMotionSource(bciProvider);` (line 194) and before `final biometricStreamClient = ...` (line 196) — matches spec's "after the Phase 21 `bioStreamRouter` registration block" | ✅ |
| `App._(...)` invocation (line 224) wires `activeRrSource: activeRrSource,` in matching relative order (after `bioStreamRouter`, before `biometricStreamClient`) — three-way order parity (field / param / call-site) intact | ✅ |
| Same `NeiryBciProvider` instance (`bciProvider`, line 163) is the one passed both to `bioStreamRouter.registerRrIntervalSource` (line 191) and to `ActiveRrSource([bciProvider])` (line 195) — preserves the spec's "two consumers, one source" invariant | ✅ |
| `NeiryBciProvider` implements `IRrIntervalSource` (verified via mixin in `lib/Bci/NeiryBciProvider.dart`), so the `List<IRrIntervalSource>` parameter type is satisfied — no type error | ✅ |
| House-style rules from header (lines 1–4): single-line initializer, no trailing comma on the initializer line, no multi-line named-parameter formatting | ✅ — new line 195 obeys all three |

## Runtime behavior

- **Subscription timing.** `ActiveRrSource`'s constructor immediately subscribes to each source's `rrStream` (M1 spec lines 80–83). At the insertion point, `bciProvider` is fully constructed (line 163) and its `rrStream` broadcast is live. `BciDeviceManager` (line 164) holds its own subscription via `cardioSource: bciProvider`, but `NeiryBciProvider.rrStream` is a `BehaviorSubject`/broadcast stream — a second subscriber is safe and side-effect-free. No race.
- **Eager construction before any RR data flows.** Sessions cannot start before `App._` resolves (`shared` is set after this block), so the `ActiveRrSource` exists and is listening before any consumer can read it from `App.shared`. Correct ordering.
- **No leak surface in this change.** No `App.dispose()` exists today (verified — no `dispose` symbol on the `App` class), and the plan correctly defers the dispose-order requirement to a future change. The `ActiveRrSource` is owned by the long-lived `App` singleton — leak is bounded by app lifetime, identical to `bioStreamRouter` and `bciProvider` themselves.

## Potential issues considered and ruled out

- **Field-order drift between declaration / constructor / call-site.** All three are insertions in the same relative slot (between `bioStreamRouter` and `biometricStreamClient`). Named parameters mean position is non-load-bearing for compile-time correctness, but the codebase keeps them aligned for readability — this change preserves that. No issue.
- **Accidental shadowing.** The local `activeRrSource` inside `initialize()` (line 195) and the field `this.activeRrSource` are in different scopes; the call-site `activeRrSource: activeRrSource,` correctly passes the local into the named parameter. No issue.
- **Double subscription to `bciProvider.rrStream`.** `BioStreamRouter.registerRrIntervalSource` (line 191) and `ActiveRrSource` (line 195) both subscribe. This is by design — the spec calls this out explicitly ("Both register the same `NeiryBciProvider` instance. The two consumers have opposite policies — that's the whole point"). Broadcast streams support N listeners; no behavior conflict.
- **Order vs `BiometricBatcher`.** `BiometricBatcher` (line 197) starts pulling from the router. `ActiveRrSource` is constructed between the router setup and the batcher — no contract requires a specific order here; both consumers attach independently to `bciProvider`. No issue.
- **`unawaited(bciRepository.fetchKnownSerials()...)` on line 172.** This async call may resolve and trigger Bluetooth scanning later; it has no bearing on `ActiveRrSource` construction order. No issue.

## Style compliance

The new initializer line (195) is one of the simplest in the block — `final activeRrSource = ActiveRrSource([bciProvider]);` — and trivially satisfies the file header's three rules (single-line, no trailing comma, no multi-line named-parameter form).

## Plan adherence

Every plan task (1–4) is implemented exactly as described, with no scope creep:
1. Import added ✅
2. Field + constructor parameter added ✅
3. Construction at the specified location ✅
4. Pass into `App._(...)` invocation ✅

No extra edits, no incidental refactors, no spec drift.

REVIEW_PASS
