# Plan Review: Add `BreathLifecycle` + `isLive`, derived from status + `_hasStarted`

**Plan:** `.ai-factory/plans/05-add-breathlifecycle-islive-derived-from-status-hasstarted.md`
**Reviewed against:** actual codebase state (breath_module package + test suite)
**Risk Level:** 🟡 Medium — one blocking gap that, if unaddressed, prevents the suite from compiling (and thus prevents the TDD red→green flow the milestone mandates). Everything else is accurate and well-scoped.

## Context Gates

- **Architecture** (`.ai-factory/ARCHITECTURE.md` present): ✅ No boundary violation. The change is confined to the `breath_module` package (output schema + state machine + ViewModel) plus its test support. Domain-model-stops-at-ViewModel and module-boundary invariants are respected; nothing in `lib/` is touched. **PASS.**
- **Rules** (`.ai-factory/RULES.md` present): ✅ No applicable rule violated. The only structural rule (constructor-DI, line 9) is unrelated to this additive field. **PASS.**
- **Roadmap** (`.ai-factory/ROADMAP.md` present): ✅ Strong linkage. The plan maps 1:1 to Phase 58 → "Add `BreathLifecycle` + `isLive`, derived from status + `_hasStarted`". Derivation rule, `equalsIgnoringTickFields` inclusion, VM carry-through sites, and the "purely additive" guard all match the roadmap entry verbatim. **PASS.**

## Verified Correct (recon spot-checks)

All line numbers and structural claims in the plan were checked against the source and are accurate:

- `BreathSessionState.dart` — enum block at top (`:5`), const constructor (`:40`), `factory .initial()` (`:60`), `equalsIgnoringTickFields` (`:95`), `copyWith` (`:112`). ✔
- `BreathSessionStateMachine.dart` — the 9 full-constructor emit sites (`:117/:141/:167/:191/:216/:278/:315/:343/:373`) are exactly the construction points; `_hasStarted` is an in-scope instance field at all of them; `_hasStarted = true` flips *after* the `resume()` emit (`:205`). ✔
- `BreathSessionViewModel.dart` — `_setupEngine` full constructor (`:152`) and `_onEngineState` full constructor (`:189`); all other writes are `copyWith` and never change `status`. ✔
- `BreathActivityHarness.dart` — placeholder `bool get isLive => false;` (`:64`), doc comment (`:62-63`), `states` recorded from the raw `_vm.stream`. ✔
- The barrel re-exports `BreathSessionState.dart` wholesale, so `BreathLifecycle` is exported with no barrel edit. ✔
- The raw stream (`_stateController`) fires on **every** `set state` regardless of `equalsIgnoringTickFields`, so `harness.states` is unaffected by adding `lifecycle` to that equality method — the golden master's recorded sequence will not shift. ✔ (This validates the Task 5 "golden master stays green" claim *at the assertion level* — but see Critical Issue below for the *compilation* level.)
- Derivation rule is internally consistent and the rest-only-session path to a `running`/rest emit (Task 1's rest case) is reachable: a rest-only first exercise + `resume()` emits `status == rest` → `running`. ✔

## Critical Issues

### 1. Making `lifecycle` a `required` field breaks 3 existing test files — the suite will not compile (BLOCKING)

Task 2 says: *"Add `required this.lifecycle` to the const constructor."* Task 3 makes it `required` on `BreathSessionStateMachineState` too. The plan's recon only accounted for production construction sites (the 2 VM sites + 9 SM sites) and **missed every other full-constructor call site of `BreathSessionState`**.

There are **5 external full-constructor calls across 3 test files** that pass no `lifecycle` and will fail to compile the moment the field becomes required:

- `test/BreathModule/Presentation/BreathSession/breath_session_state_equality_test.dart` — `:29` (the `_state()` helper), `:72`, `:98`
- `test/BreathModule/Presentation/BreathSession/breath_session_enriched_state_test.dart` — `:569` (a `const BreathSessionState(...)`)
- `test/BreathModule/breath_module_state_channel_test.dart` — `:111` (a state-builder helper)

Why this is blocking, not cosmetic: in Dart, a single compile error in any file under `test/` fails the **entire** `flutter test` target. So:

- **Task 1's red suite never reaches a meaningful "red"** — it won't even compile alongside these now-broken siblings.
- **Task 5's claim that the golden master "stays green" cannot be satisfied** — the golden master is in the same target and won't compile either.

The plan therefore cannot reach green as written.

**Resolution — pick one and add it explicitly to the task list:**

- **Option A (recommended, lowest-risk, most "additive"):** give the field a default instead of making it required — `this.lifecycle = BreathLifecycle.notStarted` on `BreathSessionState` (and on `BreathSessionStateMachineState`). All existing call sites — including the `const` one at `enriched_state_test:569` — keep compiling untouched. Production correctness is unaffected because every production emit site sets `lifecycle` explicitly (Tasks 3–4). The default is only ever observed by these pre-existing tests, which don't assert on `lifecycle`. This also better honors the milestone's "purely additive" guard (existing constructions stay valid).
- **Option B:** keep `required` and add a Task to update all 5 call sites in the 3 test files to pass `lifecycle: BreathLifecycle.notStarted` (or a status-appropriate value). More edits, more churn, and the `const` site at `enriched_state_test:569` must stay `const`-compatible.

Note: `BreathSessionStateMachineState` has **no** external full-constructor callers (only the 9 in-file sites + its own `copyWith`), so `required` there is safe either way. The breakage is specific to `BreathSessionState`.

## Minor Notes (non-blocking)

- **Task 1, rest-case authoring:** the harness default session (`makeSession([makeExercise()])`) has inhale=2/exhale=2 and **no rest step**, so a `rest`-phase running emit requires a custom session. The plan acknowledges this ("use a rest-only session via `makeSession`"). Confirmed reachable; just flag it so the implementer builds the custom DTO rather than expecting the default session to produce a rest emit.
- **Consideration — central derivation vs per-site:** the plan computes `lifecycle` at each of the 9 sites via a `_lifecycleFor(status, hasStarted)` helper. A DRYer alternative is to derive once inside `_emit` from `newState.status` + `_hasStarted` (the only site where timing matters is `resume()`, and there `status ∈ {breath,rest}` → `running` independent of `_hasStarted`, which is still `false` at emit time — so a central derivation yields the identical result). Not a defect — the per-site approach is correct and matches the existing full-constructor style — but worth noting as a smaller-surface option if the implementer prefers it.
- **`_onEngineState` copyWith passthrough:** the VM's `toggleStar`/`tickSource`/error writes use `copyWith` and never change `status`, so the `lifecycle ?? this.lifecycle` passthrough keeps them consistent. Verified — the plan's claim holds. (One subtlety the implementer should keep in mind: `copyWith` can't *clear* `lifecycle`, but there's never a reason to, so this is fine.)

## Positive Notes

- Recon on the production surface is precise — all 11 production construction sites and every cited line number check out against the current source.
- The TDD ordering (red contract tests → additive green) and the atomic single-commit rationale are sound, *given* the compile gap above is closed.
- Correctly identifies the `_hasStarted`-flips-after-resume timing subtlety and neutralizes it (status-based mapping makes `_hasStarted` irrelevant at the `resume()` emit).
- Correctly includes `lifecycle` in `equalsIgnoringTickFields` for Riverpod publication, and correctly leaves the raw-stream cadence path untouched.
- Strong roadmap/spec traceability — matches Phase 58 and note 05 field-for-field.

## Verdict

The plan is architecturally correct and almost complete, but it will **not compile-and-pass as written** because making `lifecycle` required breaks 5 pre-existing full-constructor call sites in 3 test files that the recon missed. Close that gap (Option A preferred) and the plan is ready.

Address Critical Issue #1, then proceed.
