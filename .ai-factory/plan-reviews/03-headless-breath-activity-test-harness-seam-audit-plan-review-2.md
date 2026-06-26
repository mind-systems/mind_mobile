# Plan Review: Headless breath-activity test harness + seam audit (round 2)

**Plan:** `.ai-factory/plans/03-headless-breath-activity-test-harness-seam-audit.md`
**Risk Level:** 🟢 Low — accurate, feasible, well-anchored to the codebase.

## Verification summary

Every file path, line citation, and API reference in the plan was checked against the
actual source. All are correct:

| Claim in plan | Verified |
|---|---|
| `BreathModule.buildSession()` wiring at `BreathModule.dart:34-59`, factory `46-55` | ✅ exact |
| `ITickService` exported from `breath_module.dart:36`, abstract interface | ✅ abstract, 6 members |
| `IBreathSessionService` / `IBreathSessionCoordinator` exports `breath_module.dart:12-13`, abstract | ✅ both abstract |
| `ModuleStateChannel` is a **concrete** class (not abstract) | ✅ `ModuleStateChannel.dart:16` `class` |
| `BreathModuleInstructionStream` is a **concrete** class | ✅ `BreathModuleInstructionStream.dart:4` `class` |
| `vm.stream` is a broadcast controller at `BreathSessionViewModel.dart:57`, no replay | ✅ `StreamController.broadcast()` |
| Initial `SessionLoadState.ready` emission fires inside `initState()` → `_setupEngine` | ✅ `:152-153` sets `state` with `ready` |
| Public controls `pause/resume/complete/restartEngine` at `:276-286` | ✅ exact |
| `build()` registers `ref.onDispose` at `:78-88` (cancels subs, disposes SM + tick + controller) | ✅ exact |
| `attachModuleChannel({onDispose, onReset})` exists `:39-45` | ✅ |
| `BreathModuleStateChannel` has `reset()` `:147` and `dispose()` `:160` | ✅ |
| `BreathModuleStateChannel` ctor signature (channel / stateStream / instructionStream / sessionId) | ✅ `:32-43` |
| Existing private fakes prove fakeability: `_FakeChannel`/`_FakeInstructionStream` (`breath_module_state_channel_test.dart:18,56`), `FakeTickService` (`breath_session_state_machine_test.dart:10`), service/coordinator (`breath_view_model_publication_test.dart:49-81`) | ✅ all present and as described |
| `test/BreathModule/Fakes/` exists with `FakeSmoothedRrSource.dart` (established convention) | ✅ |
| `makeExercise`/`makeSession` builders at `breath_session_state_machine_test.dart:38-63` | ✅ |

The seam-audit verdict — **no interface extraction needed**, concrete classes are
fakeable via `implements` + `noSuchMethod` — is correct and already demonstrated by the
shipping test suite. The plan's explicit call-out of the "concrete class, not declared
interface" distinction (Task 1) is the right thing to record.

The "no platform bindings" claim is proven: `breath_view_model_publication_test.dart`
already runs `initState → resume → tick` against a bare `ProviderContainer` with no
`TestWidgetsFlutterBinding` and no `App.shared`. The harness reuses exactly this path.

## Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — present. Plan stays test-only; no
  production wiring or boundary changes. No conflict. (PASS)
- **Rules (`.ai-factory/RULES.md`)** — present. Plan is additive test infra, follows the
  existing `test/BreathModule/Fakes/` convention. No violation observed. (PASS)
- **Roadmap (`.ai-factory/ROADMAP.md`)** — present. This is milestone 03 in the breath
  lifecycle-refactor note chain (03 → 04 → 05 …); the harness is the declared TDD vehicle
  for downstream notes. Linkage is explicit via the `[[05-...]]` reference. (PASS)
- **skill-context** — `.ai-factory/skill-context/aif-review/SKILL.md` not present. (WARN, optional)

## Observations (non-blocking)

These are refinements, not corrections. None block implementation.

1. **`phaseTickCalls` is unobservable without seeding a `ModuleState`.** Task 3 lists
   `phaseTickCalls` as output channel #2, but `BreathModuleStateChannel` only dispatches
   `sendSample` once `_moduleSessionId` is non-null (`BreathModuleStateChannel.dart:46-48`),
   and that id arrives only from a `ModuleState` pushed onto `channel.state`. The harness's
   `FakeModuleStateChannel` never receives one unless a test seeds it, so phase-change
   instructions stay buffered in `_pendingInstruction` and `phaseTickCalls` stays empty.
   The Task 4 smoke test does not assert on `phaseTickCalls`, so it passes regardless — but
   the channel is advertised as functional. **Recommendation:** have the harness expose a
   small helper (e.g. `emitModuleSession(String id)` that pushes
   `ModuleState(moduleSessionId: id, status: ModuleStateStatus.active)` onto the fake's
   state controller), or at minimum note in the harness doc-comment that instruction
   observability requires seeding a module session first. Otherwise the next author
   (note 04/05 golden-master tests) will see an always-empty list and assume it's broken.

2. **Async settling not called out in the smoke test (Task 4).** Every existing channel/VM
   test interleaves `await pumpEventQueue()` (or `await Future<void>.delayed(Duration.zero)`)
   between each emission and its assertion, because state flows VM → broadcast stream →
   channel asynchronously. The smoke test must do the same between `resume`, each `tick`,
   `complete`, and the assertions, or `startCalls`/`endCount` will read stale. Worth stating
   explicitly in Task 4 so the implementer doesn't write a synchronous assertion that flakes.

3. **The `isLive` placeholder hook will likely become redundant.** Note
   `05-breath-derive-lifecycle-islive.md` derives `isLive` as a field **on
   `BreathSessionState` itself** and names this harness as the TDD vehicle ("write the red
   contract tests first via [[03-breath-headless-activity-harness]]: isLive true through
   pause…"). Once 05 lands, tests will read `recordedStates.last.isLive` directly through
   output channel #1 (the recorded state sequence), making a separate harness-level getter
   dead weight. The placeholder is harmless *now* (the field doesn't exist yet), but the
   harness owner should plan to retire it / redirect it to the recorded-state field when 05
   lands rather than wiring real logic into the harness. Consider a one-line comment to that
   effect so it isn't mistaken for a permanent seam.

4. **Member-count wording nit (Task 2).** `ITickService` has six abstract members
   (`tickStream`, `source`, `nominalIntervalMs`, `sourceChanges`, `trySwitchTo`, `dispose`);
   the plan says "all five interface members … plus a `dispose()`". The enumerated list is
   complete and correct — only the count phrasing is off by the separately-mentioned
   `dispose`. Cosmetic.

5. **Directory split is fine.** Fakes → `test/BreathModule/Fakes/` (existing), harness →
   `test/BreathModule/Support/` (new). The `Support/` directory does not exist yet and will
   be created by Task 3 — expected, just noting it's a new path, not a typo of an existing one.

## Positive notes

- Line-precise anchoring throughout; the implementing agent has near-zero guesswork.
- The subscribe-before-`initState()` ordering rationale (broadcast stream has no replay; the
  `ready` emission fires inside `initState`) is exactly right and is the one subtle trap a
  naive implementation would hit.
- Disposal story is correct: routing teardown through `container.dispose()` →
  `ref.onDispose` reuses the real production cleanup path instead of hand-rolling it.
- Dependency ordering (Task 1 audit → Task 2 fakes → Task 3 harness → Task 4 smoke) is sound
  and each task is independently checkable.
- "Keep additive — do not modify existing test files" (Task 2) protects the shipping suite
  while consolidating fakes.

## Verdict

The plan is technically accurate, architecturally sound, and feasible as written. The
observations above are quality refinements (chiefly: make `phaseTickCalls` actually
reachable, and call out async settling in the smoke test) — none are blocking errors.

PLAN_REVIEW_PASS
