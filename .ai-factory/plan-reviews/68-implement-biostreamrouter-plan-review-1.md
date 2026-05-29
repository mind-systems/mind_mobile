# Plan Review: Implement `BioStreamRouter`

**Plan:** `.ai-factory/plans/68-implement-biostreamrouter.md`
**Risk Level:** 🟢 Low

## Context Gates

- **ARCHITECTURE.md** — PASS. `lib/Biometrics/` is the hardware-agnostic infrastructure layer established in Phase 19 (note 27 "biometrics refactor"). Adding `BioStreamRouter.dart` next to the existing capability interfaces (`IHeartRateSource.dart`, `IRrIntervalSource.dart`, `IEegBandsSource.dart`, `IEmotionsSource.dart`, `IMotionSource.dart`) follows the same placement rule. No module boundary, ViewModel, or Service-interface concerns apply — this is infrastructure plumbing, not a feature module.
- **RULES.md** — PASS with a note. The "all dependencies injected via constructor" rule is in mild tension with the fan-in registration pattern (`register*` is by definition a post-construction wiring call). However, RULES.md targets Module Services that would otherwise leak state across packages; an aggregator/router whose role is to collect N sources of unknown count is the standard exception. All `register*` calls are performed once in `App.initialize()` before any subscriber attaches, which is what the dartdoc invariant in Task 4 codifies. No rules violation.
- **ROADMAP.md** — PASS. The task is listed verbatim in Phase 23 (line 151) — "Implement `BioStreamRouter`" with pointer to note 28 Milestone 6. Plan matches scope exactly.

## Correctness review

### Spec fidelity
Task 1–3 reproduce the snippet in `.ai-factory/notes/28-biometric-stream-pipeline.md` lines 159–223 field-for-field and method-for-method:
- Five private `List<I…Source>` lists with the same names.
- `Stream<BioSample>? _merged` cache slot.
- Five `register*` methods, each appends + invalidates cache.
- Lazy `samples` getter with `if (cached != null) return cached;` early return, collection-for over each list mapping through the right `BioSample.from*` factory, `Rx.merge(streams).asBroadcastStream()`, cache, return.

Verified each factory exists with the expected signature on `BioSample`:
- `BioSample.fromCardio(CardioData)` ✓
- `BioSample.fromRr(RrInterval)` ✓
- `BioSample.fromNfb(BciNfbData)` ✓
- `BioSample.fromEmotions(BciEmotionsData)` ✓
- `BioSample.fromMotion(MotionData)` ✓

Verified each capability interface exposes the expected stream getter:
- `IHeartRateSource.cardioStream` ✓
- `IRrIntervalSource.rrStream` ✓
- `IEegBandsSource.nfbStream` ✓
- `IEmotionsSource.emotionsStream` ✓
- `IMotionSource.motionStream` ✓

The plan writes `.map(BioSample.fromCardio)` (tear-off) vs the note's `.map((c) => BioSample.fromCardio(c))` (lambda). Semantically identical — the tear-off form is the preferred Dart idiom; no concern.

### Dependencies
- `package:rxdart/rxdart.dart` — present in root `pubspec.yaml` (`rxdart: ^0.28.0`). `Rx.merge` is a static method on rxdart's `Rx` namespace and is available in 0.28.x.
- `dart:async` — std.

### File paths
- `lib/Biometrics/BioStreamRouter.dart` — new file, parent directory exists, no naming collision.
- All relative imports (`BioSample.dart`, `I*Source.dart`) resolve correctly because they sit next to the new file.

## Architectural considerations

### Broadcast stream subscriber lifecycle
`Rx.merge(streams).asBroadcastStream()` produces a broadcast stream whose underlying merged source begins listening only when the first subscriber attaches and stops if all subscribers cancel. If a subscriber ever cancels and a later one re-subscribes, the upstream source streams may already be closed. In practice this is non-issue here because `BiometricBatcher` (the only subscriber per note 28 Milestone 8) holds the subscription for the app lifetime. The plan does not need to address this, but a one-line note in the dartdoc on `samples` ("first listener spins up the merge; do not cancel and resubscribe") would harden the contract. **Not blocking.**

### No `dispose()`
The router holds no resources of its own — only the lazy broadcast stream and a few `List<I…Source>` references. Subscribers (Batcher) own their `StreamSubscription`. Sources own their controllers. So skipping `dispose()` is correct and matches the spec.

### Cache-invalidation race
Task 2 says `register*` sets `_merged = null` to invalidate. Combined with the Task 4 invariant ("register all sources before first subscribe"), this is safe in `App.initialize()`. A late register would leave existing subscribers reading the old merge — the dartdoc in Task 4 explicitly calls this out. No additional guard needed.

## Security review
N/A — pure in-memory stream plumbing, no user input, no persistence, no IPC, no auth boundary crossed.

## Performance review
- `asBroadcastStream()` adds one fan-out hop, negligible.
- Mapping each source stream through a `BioSample.from*` factory creates one small allocation per emission. Expected sample rates (HR ≈ 1 Hz, RR ≈ 1 Hz, EEG bands ≈ 10 Hz, emotions ≈ 1 Hz, motion ≈ 100 Hz from Neiry MEMS) total a few hundred allocations/sec — well within budget.
- `Rx.merge` is O(n) in source count at subscribe time; n ≤ 5 today.

No performance concern.

## Missing steps / gaps

None blocking. Two optional polish items:

1. **(Optional)** In Task 4's dartdoc, add a single sentence on broadcast-subscriber semantics (do not cancel + resubscribe). The Milestone 6 prose covers this implicitly under "Register-before-subscribe invariant" but doesn't spell out the cancel-resubscribe corollary.
2. **(Optional)** The plan does not call out that no `pubspec.yaml` change is needed — implementer should know `rxdart` is already on the dep list. Minor; the implementer can verify in one grep.

Neither blocks implementation.

## Positive notes

- Tight scope — single file, no cross-package changes, no `App.dart` wiring (correctly deferred to Phase 23 wiring task on roadmap line 157).
- Faithful to the spec snippet (line 56 of the plan explicitly anchors to "notes/28… Milestone 6 lines 209–222").
- Invariant about register-before-subscribe is called out explicitly in Task 4 — the most subtle aspect of the lazy-broadcast design is documented up front.
- Reasoning for "no client-side dedup" is captured in Task 2 with the right justification (each sample carries its `source` tag; server-side decides policy).
- Settings (`Testing: no`, `Logging: minimal`, `Docs: no`) match the infrastructure-plumbing nature — no behavioral surface to test in isolation, and the next milestone (Batcher) plus wiring will exercise it end-to-end.

## Verdict

The plan is a faithful, minimal implementation of Milestone 6 in note 28. File paths, imports, interface method names, and `BioSample.from*` factory signatures all verified against the codebase. Architecture and rules gates pass. No blocking issues.

PLAN_REVIEW_PASS
