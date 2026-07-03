## Code Review Summary

**Plan:** `27-give-up-surface-golden-master-tests.md` (test-only golden master; no production code change)
**Files Reviewed:** plan + 6 production/test surfaces it references
**Risk Level:** 🟢 Low

### Context Gates

- **Architecture (`.ai-factory/ARCHITECTURE.md`)** — WARN: not opened; the plan touches no module boundary, only adds a sibling test file under `test/Core/Grpc/`. No boundary/dependency alignment concern.
- **Rules (`.ai-factory/RULES.md`)** — PASS: the three listed rules (stateless Module Services, no module state in App.dart, constructor injection) do not apply — this is additive test code that reads existing seams. In particular the plan does **not** add anything to `App.dart`; it only *reproduces* the `App.dart:323` transform inside the test.
- **Roadmap (`.ai-factory/ROADMAP.md:98`)** — PASS: the milestone line matches the plan title and `Spec:` note (`27-rootchild-startrace-giveup-golden-master.md`) exactly. The note correctly routes these tests to `test/Core/Grpc/` and off `ROADMAP_TESTS.md` (impl-chain golden master, not a test-coverage task) — consistent with the plan's file target.
- **Commit anchor** — PASS with note: `93f3e92` exists and is the production-code tip. Current `HEAD` is `858714d "Roadmap update"` (roadmap file only, no production change), so "green on the current tree" still holds against the same production behaviour.

### Verification of the plan's factual claims (all confirmed against source)

- **Give-up budget mechanics** — `_sendStart` (`ModuleStateChannel.dart:483`) increments `attempts` and arms a 5s timer; `_onConfirmTimeout` (`:502`) gives up when `attempts >= 3`, else re-sends while `isConnected`. Driving a start + `elapse(5s)` ×3 reaches `_giveUp` → `SessionStartFailed`. **Confirmed** (line refs `:502/:523` accurate).
- **Carried-path give-up** — `_resolveSettling` (`:551`) snapshots `carriedTypes`, and for a carried pending with `attempts >= 3` calls `_giveUp` instead of `_sendStart` (`:563-571`). At reconnect-open each carried pending's own timer is cancelled (`:203-206`), so only the 3s reconcile timer fires. **Confirmed** — Task 2's "no 4th send + exactly one `SessionStartFailed`" is exactly what the code produces.
- **Type-scoped reset filter** — `BreathModuleStateChannel.dart:55` (`event is SessionStartFailed && event.type == ActivityType.breath → reset()`) and `MeditationModuleStateChannel.dart:37` (mirror for meditation). A give-up of the *other* type does not touch this adapter. **Confirmed** — the golden-master assertion genuinely locks the `event.type ==` filter: removing it would flip the surviving adapter's `moduleSessionId` to `null` and fail the test.
- **`moduleSessionId` seam** — both adapters expose a public `String? get moduleSessionId` (breath `:63`, meditation `:45`) fed from the shared `channel.state` and nulled in `reset()`/`_reset()`. `_giveUp` emits only an event (does not mutate `_state`), so the surviving adapter's recorded id is never overwritten during the other type's give-up. **Confirmed** — the seam behaves as the plan describes.
- **Snackbar wire** — `App.dart:323` is verbatim `...events.where((e) => e is SessionStartFailed).map((_) {})`. **Confirmed exact.**
- **Types & imports** — `SessionStartFailed(this.type)` with `final ActivityType type` (`ModuleStateEvent.dart:35`); `enum ActivityType { breath, meditation, root }` (`ActivityType.dart:1`). The extra imports the plan lists (`ModuleStateEvent`, `ActivityType`, generated proto) beyond `start_race_contract_test.dart`'s block are correct and necessary.
- **Harness API** — `wireConcurrent()`, `connectAndFlush`, `disconnectAndFlush`, `runningBreathState()`, `activeMeditationState()`, `childActiveFrame(type,id)`, `f.service.calls`, `f.breathAdapter/meditationAdapter`, `f.connManager.pushConnected()` all exist with the signatures the plan uses. **Confirmed.**
- **Ordering pin** — `connectAndFlush` before driving adapters is required or `channel.start` is dropped by the null-sink guard; the plan calls this out and every task follows it. **Confirmed.**

### Critical Issues

None. The plan is precise, grounded in the actual code, and each scenario traces cleanly to a green outcome on the current tree with no production change.

### Minor Observations (non-blocking)

- **Subscribe-before-drive for Task 1.** `channel.events` is a `PublishSubject` (`ModuleStateChannel.dart:50`) — it drops events emitted before a listener subscribes. The plan states "subscribe before driving" explicitly for Tasks 2 and 3 but only says Task 1 "adds `_collectFailures`". Since Task 1's give-up fires only after the 3×5s elapse, subscribing anywhere near the top of the test is sufficient — but the implementer should subscribe the collector immediately after `wireConcurrent()`/`connectAndFlush`, before the elapses, to observe the `SessionStartFailed`. Worth stating so it isn't left to inference.
- **`.map((_) {})` emits `null`.** The App.dart:323 transform maps each `SessionStartFailed` to a `null` unit event. Task 3's "emitted exactly one unit event" therefore means asserting the collector's `length == 1` (the collected value is `null`, not a truthy token). Trivial and implementer-obvious, but noting so the assertion isn't written as a non-null check.
- **Line drift in note vs. plan (cosmetic).** The note cites `BreathModuleStateChannel.dart:53-58`; the actual filter sits at `:55-59` (block `:52-60`, as the plan states). No impact — the plan's range is correct.

### Positive Notes

- The seam choice (`adapter.moduleSessionId` + `SessionStartFailed` collection) avoids private-field access and is a true behavioural lock: each of the three surfaces would fail loudly if regressed by note 28's lift.
- The carried-path test correctly stops at two elapses (attempts 2 and 3) to force resolution through `_resolveSettling` rather than `_onConfirmTimeout`, isolating the exact INV-12 overshoot review 2 caught — a well-targeted regression pin.
- Explicit "do not modify the harness / do not weaken existing assertions / green on 93f3e92" guards are carried from the note into every task and the Verify step.

PLAN_REVIEW_PASS
