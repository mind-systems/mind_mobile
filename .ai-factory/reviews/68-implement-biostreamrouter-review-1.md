# Code Review: Implement `BioStreamRouter`

**Plan:** `.ai-factory/plans/68-implement-biostreamrouter.md`
**Files changed:**
- `lib/Biometrics/BioStreamRouter.dart` (new, 98 LOC)
- `.ai-factory/plans/68-implement-biostreamrouter.md` (new, plan doc)
- `.ai-factory/plan-reviews/68-implement-biostreamrouter-plan-review-1.md` (new, plan review)

Reviewed against `.ai-factory/notes/28-biometric-stream-pipeline.md` §Milestone 6, `lib/Biometrics/BioSample.dart`, and the five capability interface files.

## Spec fidelity

The router faithfully reproduces the snippet in note 28 lines 159–223:

- Five private `List<I…Source>` lists, names match the spec exactly (`_heartRates`, `_rrIntervals`, `_eegBands`, `_emotions`, `_motions`).
- `Stream<BioSample>? _merged` cache slot — present.
- Five public `register*` methods, each appends to the matching list and sets `_merged = null`. No `StateError`, no dedup, matches the "per-sample `source` tag is server-side concern" rationale.
- `Stream<BioSample> get samples` is a lazy getter, returns the cached `_merged` when non-null, otherwise constructs the merged broadcast stream via `Rx.merge(streams).asBroadcastStream()` and caches it.
- Collection-for over each capability list emits per-source mapped streams; empty lists contribute nothing — matches the spec.

Factory tear-offs (`BioSample.fromCardio`, `BioSample.fromRr`, etc.) used in place of the spec's lambdas. Verified each factory exists on `BioSample` with a single positional parameter of the matching type, so the tear-off has signature `(T) → BioSample` and is a valid argument to `Stream<T>.map`. Idiomatic improvement over the lambda form; no behavior change.

## Interface and stream-getter cross-check

Verified each capability interface exposes the stream getter the router reads:

| Interface | Reads | Interface declares |
|---|---|---|
| `IHeartRateSource` | `s.cardioStream` | `Stream<CardioData> get cardioStream;` ✓ |
| `IRrIntervalSource` | `s.rrStream` | `Stream<RrInterval> get rrStream;` ✓ |
| `IEegBandsSource` | `s.nfbStream` | `Stream<BciNfbData> get nfbStream;` ✓ |
| `IEmotionsSource` | `s.emotionsStream` | `Stream<BciEmotionsData> get emotionsStream;` ✓ |
| `IMotionSource` | `s.motionStream` | `Stream<MotionData> get motionStream;` ✓ |

Each emitted element type matches the input parameter of the corresponding `BioSample.from*` factory.

## Dependencies

- `rxdart: ^0.28.0` is in `pubspec.yaml`. `Rx.merge<T>(Iterable<Stream<T>>)` is the static API surfaced by 0.28.x; resolution is fine.
- `dart:async` is required (the `Stream<BioSample>?` field uses `Stream` from `dart:async`; it is not re-exported from `dart:core`). Import present.

## Correctness review

### Empty `Rx.merge(streams)` edge case
If `samples` is read before any source is registered, `streams` is empty and `Rx.merge([])` returns an already-closed stream that is then cached. Future `register*` calls invalidate the cache, so any subsequent subscriber receives a fresh merge — but an early subscriber who tried to listen to the empty/closed stream is permanently bound to nothing. This is exactly the "register-before-subscribe" invariant the dartdoc documents, and matches the spec's stated behavior. No bug.

### Cache invalidation race
Single-threaded Dart execution rules out a concurrent-modification race during `register*`. The Task 4 invariant ensures wiring order in `App.initialize()` is correct. Non-issue.

### Broadcast subscriber lifecycle
`Rx.merge(streams).asBroadcastStream()` produces a broadcast stream backed by an internal subscription that starts when the first listener attaches. The default `asBroadcastStream()` behavior cancels the upstream when all listeners cancel; a later re-subscribe attaches to an already-closed stream. In the production pipeline `BiometricBatcher` is the sole subscriber and holds for app lifetime, so this is benign. The plan-review (lines 60-62) flagged this as a non-blocking polish note; the implementation does not add the corollary sentence, which is acceptable given the canonical reference is note 28 §Milestone 6.

### No `dispose()`
The router owns no controllers, subscriptions, or timers. Sources own their controllers; the batcher owns its `StreamSubscription`. Skipping `dispose()` is the right call.

### Mutable lists exposed by reference?
The five `_heartRates`, `_rrIntervals`, etc. lists are private. The class returns nothing that references them. The merged stream snapshots the lists at build time via collection-for. After cache invalidation, the new merge re-reads the (now-larger) lists — correct. No external mutation surface.

## Architecture / Rules gates

- **`.ai-factory/RULES.md`** — the "all dependencies injected via constructor" rule targets Module Services that would otherwise leak state across packages. An aggregator that fans in N sources of unknown count is the standard exception — and all `register*` calls are funneled into `App.initialize()` (per the dartdoc invariant and Phase 23 wiring task on the roadmap). No rule violation.
- **`mind_mobile/CLAUDE.md`** — placement in `lib/Biometrics/` matches the "hardware-agnostic biometric streaming" responsibility documented in the directory table.
- **No module/UI imports** — the router does not depend on `packages/bci_module` or any UI code; correct, this is infrastructure that lives entirely inside `lib/`.

## Security / performance

- No user input, no persistence, no IPC boundary crossed. N/A.
- Per-emission allocation: one `BioSample` per source emission. Expected aggregate rate (Neiry MEMS ≈ 100 Hz, EEG ≈ 10 Hz, HR/RR/emotions ≈ 1 Hz) ≈ a few hundred allocations/sec. Negligible.
- `Rx.merge` setup is O(n) in source count; n ≤ 5 today.

## Minor / cosmetic (non-blocking)

1. **Import grouping.** Convention (and the `directives_ordering` lint) prefers a blank line between `package:` and relative imports. The file groups `dart:async` separately but then runs `package:rxdart` directly into the relative imports without a separator. Cosmetic; many files in this repo skip the separator too.

2. **Dartdoc references unresolved symbols.** The class doc references `[BiometricBatcher]`, which lands in the next milestone — until then dartdoc will emit a broken-link warning. Will resolve when Milestone 8 lands.

3. **`[register*]` is not a valid Dart identifier.** Used as a shorthand in the dartdoc to mean "any of the five `register*` methods"; dartdoc will not produce a link. Purely cosmetic; intent is clear.

None of these affect runtime behavior.

## Verdict

Implementation is a faithful, minimal, idiomatic rendering of Milestone 6. All field names, method signatures, stream getter, factory wiring, and cache-invalidation semantics line up with the spec and with the capability interfaces in the surrounding codebase. The register-before-subscribe invariant is documented prominently. No correctness, security, or performance issues.

REVIEW_PASS
