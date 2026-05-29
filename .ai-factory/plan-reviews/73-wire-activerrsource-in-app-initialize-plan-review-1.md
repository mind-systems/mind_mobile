# Plan Review: Wire `activeRrSource` in `App.initialize()`

**Plan:** `.ai-factory/plans/73-wire-activerrsource-in-app-initialize.md`
**Reviewed against:**
- `lib/Core/App.dart` (current state)
- `lib/Biometrics/ActiveRrSource.dart` (Phase 22 M1, already merged)
- `lib/Bci/NeiryBciProvider.dart` (verifies `IRrIntervalSource` implementation)
- `.ai-factory/notes/29-heart-rate-tick-source.md` Milestone 2 (spec)
- `.ai-factory/ROADMAP.md` Phase 22 (milestone definition)
- `.ai-factory/RULES.md`

## Risk Level
🟢 Low — wiring-only edit in a single file, all assumptions verified against the current codebase.

## Context Gates

- **ARCHITECTURE.md** — not re-read in detail, but the change conforms to the existing biometric-infrastructure pattern already present in `App.dart` (`bioStreamRouter` block). No new module/package boundaries are crossed. PASS.
- **RULES.md** — Rule "Never add module-specific state, streams, or triggers to App.dart — App.dart is infrastructure only" applies. `ActiveRrSource` lives under `lib/Biometrics/` and is generic biometric infrastructure (parallel in role to `BioStreamRouter` which is already wired in `App.dart`); it is not module-specific state. No violation. Rule "All dependencies must be injected via constructor" is satisfied — Task 2 adds it as a `required` constructor parameter. PASS.
- **ROADMAP.md** — Plan corresponds exactly to Phase 22, milestone "Wire `activeRrSource` in `App.initialize()`" (line 165), which is the next unchecked item after `[x]` "Create `ActiveRrSource`". Milestone alignment confirmed. PASS.

## Verification Against the Codebase

| Plan claim | Verified? |
|---|---|
| `ActiveRrSource` exists in `lib/Biometrics/ActiveRrSource.dart` with constructor `ActiveRrSource(List<IRrIntervalSource>)` | ✅ (file lines 27–34) |
| `NeiryBciProvider` implements `IRrIntervalSource` | ✅ (`NeiryBciProvider.dart:33`) |
| `bciProvider` instance exists at the right point in `initialize()` and is shared with `bioStreamRouter` | ✅ (`App.dart:160`, registrations at 187–191) |
| Insertion point — immediately after `bioStreamRouter.registerMotionSource(bciProvider);` and before `final biometricStreamClient = …` — is unambiguous | ✅ (`App.dart:191` → `App.dart:192`) |
| No `dispose()` path exists on `App` | ✅ (verified — `App` class has no `dispose()` method) |
| Biometrics import grouping point — adjacent to `BioStreamRouter.dart`, `BiometricBatcher.dart`, `BiometricStreamClient.dart` (lines 56–58) | ✅ |
| Field block grouping — adjacent to `bioStreamRouter` / `biometricStreamClient` / `biometricBatcher` (lines 88–90) | ✅ |
| Style rule (header lines 1–4): single-line initializer, no trailing comma on initializer line, no multi-line named-parameter form for the new `ActiveRrSource([bciProvider])` line | ✅ (matches existing pattern; `App._(…)` invocation itself remains multi-line with trailing commas, consistent with current code) |

## Critical Issues
None.

## Missing Steps / Wrong Assumptions / Architectural Mistakes
None. The plan is a strict subset of the spec in `notes/29-heart-rate-tick-source.md` Milestone 2 and matches the current `App.dart` structure exactly.

## Minor Observations (non-blocking)

- **Task 3 → Task 4 ordering of operations:** Constructing `ActiveRrSource` (Task 3) before invoking `App._(…)` (Task 4) is required and naturally enforced by Dart variable scoping. No ambiguity, just noting it.
- **Construction-time subscription:** `ActiveRrSource`'s constructor subscribes to every source's `rrStream` immediately (lines 30–33 of the class). At the insertion point (`App.dart:192`), `bciProvider` is fully constructed (`App.dart:160`) and already has its underlying Neiry SDK plumbing in place from `BciDeviceManager` (`App.dart:161–168`), so early subscription is safe — `NeiryBciProvider.rrStream` is a broadcast stream that holds no per-listener state. Correctly placed.
- **Plan note about `dispose()`:** Plan correctly observes that no `App.dispose()` exists today and intentionally defers the spec's "dispose order" requirement. Good discipline — out-of-scope spec hygiene is recorded in Notes without expanding the change set.
- **No new tests:** Settings declare `Testing: no`. Reasonable for a four-line wiring change with no behavior delta; `ActiveRrSource`'s own behavior is covered (or will be covered) in M1's own milestone.

## Positive Notes

- Plan is appropriately small — four trivial single-purpose edits in one file. No scope creep.
- File-and-line-level instructions throughout; nothing is left to interpretation.
- Style discipline is called out explicitly (Task 3, Notes section), matching the file header's hard rules.
- Explicit recognition that the architectural point is **sharing the same `bciProvider` instance** between `bioStreamRouter` (merge policy) and `activeRrSource` (single-active policy) — the spec's core invariant is preserved verbatim.
- Out-of-scope items (dispose path, module consumption in M5) are listed and deferred, not silently dropped.

PLAN_REVIEW_PASS
