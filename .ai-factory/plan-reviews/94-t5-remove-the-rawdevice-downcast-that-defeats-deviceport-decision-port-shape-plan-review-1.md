# Plan Review — Remove the `rawDevice` downcast that defeats DevicePort (T5)

**Plan:** `94-t5-remove-the-rawdevice-downcast-that-defeats-deviceport-decision-port-shape.md`
**Files Reviewed:** plan + 11 source/test files + spec note 169 + ROADMAP/RULES context
**Risk Level:** 🟡 Medium (one verification-affecting gap; several minor test-migration under-specifications)

## Context Gates

- **Roadmap (PASS):** T5 milestone is real and correctly referenced — `ROADMAP.md:311` ("Remove the `rawDevice` downcast that defeats DevicePort (DECISION: port shape)"), spec `notes/169`. The plan's decision section accurately summarizes the milestone's two options and the "DECISION: pin one" framing.
- **Spec note 169 (PASS):** The plan's **Option 2** choice ("the adapter constructs its own classifier set") matches note 169's Option 2 parenthetical exactly. Deleting the `ClassifierFactory` port entirely is a *slight extension* of the note's literal Option 2 wording ("keep `build(DevicePort)`"), but the note's own "(e.g. the adapter constructs its own classifier set)" sanctions it. Defensible; the blast-radius reasoning (leaves `LocatorPort` untouched, no `createDevice` return-shape ripple) is correct.
- **Rules (PASS):** `RULES.md` rules concern Module Services / App.dart / constructor injection. Removing the `classifierFactory` constructor seam does not violate the constructor-injection rule — the `DevicePort` is still injected via `locatorFactory`, and tests now drive the set through the injected device fake.
- **Architecture (PASS):** `buildClassifierSet()` on `DevicePort` keeps the port vendor-clean — `ClassifierSet` and its imports (`BciNfbData`, `BciEmotionsData`, `CardioData`, `RrInterval`, `MotionData`) are all neiry-free. No circular import: `ClassifierSet.dart` does not import `DevicePort.dart`.

## Verified Accurate

- All production line numbers check out: `NeiryDeviceAdapter.rawDevice` getter `:29`; `NeiryBciProvider` imports `:27`/`:31`, `_classifierFactory` field `:44`, constructor params `:52`/`:54`, build site `:183`, quarantine doc-comment `:38`.
- Quarantine claim is correct: `neiry_kit` is currently imported by exactly 5 files (`NeiryBciProvider`, `NeiryLocatorAdapter`, `NeiryDeviceAdapter`, `NeiryClassifierSet`, `NeiryClassifierFactory`); deleting `NeiryClassifierFactory` shrinks the set to 4 as stated.
- No production caller passes `classifierFactory:` — the only `classifierFactory` references in `lib/` are inside `NeiryBciProvider.dart` itself, so removing the constructor param is safe.
- Test file/line references are accurate: classifier-port A2 regression group (`:353`, plan says `:351`–`:374`), default-ctor smoke (`:341`–`:349`); device_port connect-cleanup test (`:138`–`:170`); races "Phase 4 — partial L1" (`:766`–`:812`) and `_ThrowingDeviceLocatorPort` (`:824`–`:833`).
- The catch-block flow is preserved: `buildClassifierSet()` throwing lands at the same point the cast `TypeError` did (after `device.connect()`, before `device.start()`), so the cleanup `disconnect()`/`dispose()` counts in the migrated failure-path tests remain 1 each.

## Critical Issues

**1. Dangling doc-comment references to deleted `NeiryClassifierFactory` will fail Task 8's own grep.**
Two surviving files reference the symbol the plan deletes, and no task removes these references:
- `lib/Bci/Ports/NeiryClassifierSet.dart:21` — *"This is one of two files (with [NeiryClassifierFactory]) permitted to import `neiry_kit`."*
- `lib/Bci/Ports/ClassifierSet.dart:9` — *"Production default: [NeiryClassifierFactory] (A3)."*

Task 8 greps `lib/` and `test/` for `ClassifierFactory` and **expects zero matches**. Because `grep ClassifierFactory` also matches the substring `NeiryClassifierFactory`, these two comments will keep the verification grep non-empty and also leave dangling dartdoc references to a deleted class. The plan's Settings ("Docs: update affected inline doc-comments only") puts this *in scope*, but no task enumerates the edit.
**Fix:** Add to Task 2 (or Task 4): update `NeiryClassifierSet.dart:21` (now the sole — not "one of two" — neiry-permitted classifier file) and `ClassifierSet.dart:9` (drop the `NeiryClassifierFactory` "production default" line, since construction now goes through the device).

## Minor Issues / Under-specifications

**2. Task 6 — `device_port_test.dart` and `locator_port_test.dart` need a `ClassifierSet` impl + import that the plan does not call out.**
Both files gain `buildClassifierSet()` but currently have **no `FakeClassifierSet` class and no `import '.../ClassifierSet.dart';`**. Even though neither file's `buildClassifierSet()` is hit at runtime (locator_port tests only exercise `scan()`; device_port's connect test will throw via `throwOnBuildClassifierSet`), the method's return type forces a `ClassifierSet` value to exist for the file to compile. The plan says "return a `FakeClassifierSet`" without enumerating that these two files must add the class (or a minimal stub) and the import. The implementer will hit compile errors; make it explicit.

**3. Task 5 — the "build called once" assertion needs a counter on the device fake.**
The happy-path test currently asserts `fakeFactory.buildCallCount == 1`. After the migration there is no factory. The plan says assertions are "retargeted onto the device-built set" but does not state that `FakeDevicePort` needs a `buildClassifierSetCallCount` (or equivalent) to preserve the "called exactly once per connect()" check. Spell this out so the assertion isn't silently dropped.

**4. Task 7 — threading the set into locator-vended device fakes is the trickiest part and is under-specified.**
`RecordingLocatorPort.createDevice()` and `_ThrowingDeviceLocatorPort.createDevice()` construct **fresh** `GatedFakeDevicePort` instances internally (and vend new ones on reconnect). "Pass the `fakeSet` to the device fake instead" doesn't resolve *how* the vending locator supplies the set to each created device — either the locator must hold the set and inject it per `createDevice()`, or each device fake must own its own `FakeClassifierSet`. Since no test asserts shared-set identity across reconnects, "each device owns its own set" is simpler — but the plan should pick one. Also note `_connectThenDrop`'s `_DropSetup.classifierSet` (currently sourced from the injected `fakeSet`, races test `:331`/`:368`) must be re-sourced from the device after the factory is removed.

## Positive Notes

- Decision section is genuinely reasoned, not boilerplate — the Option-2-over-Option-1 blast-radius analysis (avoiding the `LocatorPort.createDevice` return-shape change and the 6 locator-fake ripple) is correct and is the right call.
- The plan correctly identified all 5 affected test files and the distinct fake-class names per file (`FakeClassifierFactory` / `_FakeClassifierFactory`, `GatedFakeDevicePort` / `_GatedFakeDevicePort`, `FakeClassifierSet` / `_FakeClassifierSet`).
- Commit split (1–4 production, 5–8 tests) is clean and matches the dependency ordering. Sequencing (port → adapter → provider → delete → tests → verify) is sound.
- Quarantine accounting is precise and verified against the codebase.

## Verdict

The plan is well-researched and the core design is sound. It is **not** ready as written because Issue #1 makes its own Task 8 verification step fail and leaves dangling references to a deleted symbol — a concrete, in-scope edit the task list omits. Issues #2–#4 are compile-time / fidelity gaps in the test migration that an implementer would have to improvise. Address #1 explicitly (and ideally #2–#4) before implementation.
