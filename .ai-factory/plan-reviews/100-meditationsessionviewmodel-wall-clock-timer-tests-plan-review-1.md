## Plan Review: MeditationSessionViewModel wall-clock timer tests

**Plan:** `100-meditationsessionviewmodel-wall-clock-timer-tests.md`
**Files cross-checked:** 6
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** WARN — present, but this is a pure test-authoring task adding one spec file under `test/`; it introduces no production code, no module boundary crossing, and no new dependency. No architectural boundary impact. The harness pattern (`ProviderContainer` + `overrideWith`) matches existing repo convention.
- **Rules (`.ai-factory/RULES.md`):** PASS — the relevant rules concern Module Services statelessness and App.dart purity. Neither applies; the plan touches only a test file and reads (does not modify) the ViewModel.
- **Roadmap (`ROADMAP_TESTS.md`):** PASS — milestone present (line 37, "MeditationSessionViewModel wall-clock timer tests"). The plan correctly traces to it and, importantly, surfaces a wording mismatch (see below).
- **skill-context (`aif-review/SKILL.md`):** absent — no project-specific overrides to apply.

### Verification Performed
Every key assumption in the plan was checked against source:

- **Injection seams exist** — `MeditationSessionViewModel` constructor (lines 12–17) exposes `clock = DateTime.now` and `timerFactory = Timer.periodic`. ✅ No "Test Infra" refactor is outstanding; the plan's "prerequisite already satisfied" claim is correct.
- **`timerFactory` signature** — confirmed `Timer Function(Duration, void Function(Timer))` (line 15). The plan's emphasis that the spy must capture `void Function(Timer)` (not `void Function()` as in `ActiveRrSource`) is accurate and a genuine footgun avoided.
- **Elapsed time is NOT on state** — `MeditationSessionState` holds only `status` + `poseId` (model file). `elapsedSeconds` is a public `final ValueNotifier<int>` (line 23). The plan's "IMPORTANT DISCREPANCY" callout correctly overrides the milestone's `state.elapsedSeconds == 30` wording with `vm.elapsedSeconds.value`. ✅ This is the single most important correction and the plan nails it.
- **Wall-clock recompute** — timer callback is `elapsedSeconds.value = _clock().difference(_startedAt!).inSeconds` (line 51). The "advance 30 s, fire 5×, expect 30" guard is valid: each fire reads `now`, so 5 fires at `T+30` all yield 30. ✅
- **Re-exports** — `meditation_module.dart` exports both `MeditationSessionState.dart` (carrying `MeditationSessionState` + `MeditationSessionStatus`) and `MeditationSessionViewModel.dart` (carrying the class + `meditationSessionViewModelProvider`). The plan's single-import claim holds. ✅
- **Harness pattern matches repo convention** — `test/BreathModule/.../breath_view_model_publication_test.dart` uses the exact `ProviderContainer(overrides: [provider.overrideWith(() => vm)])` → `container.read(provider.notifier)` → tearDown-dispose flow the plan prescribes. ✅
- **Fakes already exist to mirror** — `_FakeTimer` (cancelled/cancel/isActive/tick) and the mutable-`now` + `spyFactory` pattern are present in `active_rr_source_test.dart`. ✅
- **Deps** — `meditation_module` (path) and `flutter_riverpod: ^3.0.0` are in `pubspec.yaml`; `overrideWith` for `NotifierProvider` is exercised by existing passing tests. ✅
- **Paths** — target spec `test/MeditationModule/meditation_session_viewmodel_timer_test.dart` sits beside the existing `meditation_module_state_channel_test.dart`. ✅

### Critical Issues
None. The plan is implementation-ready and its assertions are physically achievable against the real code.

### Minor Notes (non-blocking — optional polish during implementation)

1. **Broadcast stream has no buffer — attach listener before `start()`/`stop()`.** Tasks 1 and 3 assert emissions on `vm.stream`, which is a `StreamController.broadcast()` (line 22). A listener attached *after* the synchronous `start()` call will miss the event. The implementer must subscribe first, then call `start()`, and `await` an event (e.g. `expectLater(vm.stream, emits(...))` set up before the call, or a pre-attached collector). Worth stating explicitly so the test isn't flaky-by-omission.

2. **`elapsedSeconds` is disposed on container teardown.** `build()` registers `ref.onDispose(() => elapsedSeconds.dispose())` (lines 31–35). Reading `vm.elapsedSeconds.value` after `container.dispose()` would throw. All reads occur before teardown in the described tasks, so this is fine — just keep assertions before `addTearDown` fires. No change needed.

3. **Task 3 "preserve last elapsedSeconds after stop()" is correct by code** — `stop()` (lines 56–61) nulls `_timer`/`_startedAt` and flips status but never touches `elapsedSeconds`, so the "still 3" assertion holds. The plan's "do NOT manually fire a cancelled timer's callback (null `_startedAt` deref)" warning is genuinely important — firing post-stop would hit `_startedAt!` on null. Good catch retained.

4. **Optional coverage gap (not required):** there is no task asserting the `build()` initial state is `idle` with the injected `poseId` before any `start()`. Cheap to add and would lock the `MeditationSessionState.initial` contract, but it is outside the milestone's stated scope and safely omittable.

### Positive Notes
- The plan does the hard part of test planning: it reconciles the milestone's loose wording (`state.elapsedSeconds`) against the actual API surface and tells the implementer exactly what to assert. This single correction is what makes the suite compile-able.
- The "advance clock vs. fire count" decoupling rationale — and the explicit reason `fake_async.elapse` cannot express it — is precisely why the manual `spyFactory`/`_FakeTimer` approach is mandated. Sound engineering judgment, not cargo-culting.
- File paths, imports, provider name, fake patterns, and dependency availability were all verifiable and all correct. No fantasy APIs.

PLAN_REVIEW_PASS
