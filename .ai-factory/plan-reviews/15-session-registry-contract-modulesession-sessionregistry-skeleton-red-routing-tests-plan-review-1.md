## Plan Review Summary

**Plan:** Session registry contract — `ModuleSession` + `SessionRegistry` skeleton + red routing tests
**Files Reviewed:** plan + targeted codebase (`ActivityType.dart`, `ModuleState.dart`, `ModuleStateChannel.dart`, `test/Core/Grpc/module_state_channel_test.dart`, notes 13/14/22, ROADMAP.md, RULES.md, ARCHITECTURE.md, analysis_options.yaml)
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture (`.ai-factory/ARCHITECTURE.md`):** PASS. `lib/Core/Grpc/` is the documented home for gRPC transport + `ModuleStateChannel`; adding `ModuleSession`/`SessionRegistry` there fits. Pure-Dart (no Flutter/Riverpod) matches the "Repository / gRPC — pure Dart" boundary.
- **Rules (`.ai-factory/RULES.md`):** PASS. The "Module Services must be stateless / no dispose" rule targets `IXxxService` implementations — `SessionRegistry` is a routing layer, not a Module Service, so its held state + `dispose()` are allowed.
- **Roadmap (`.ai-factory/ROADMAP.md`):** PASS. Milestone present at `ROADMAP.md:52` with `Spec: .ai-factory/notes/22-rootchild-registry-contract.md`. Plan tasks map cleanly to note 22's skeleton + red-test list; the impl/green step is correctly deferred to note 14. Naming, silent-failure rationale, and "stateful double not pass-through stub" (m36) all carried through.

### Critical Issues
None. Field types, file paths, and referenced symbols all verified against the codebase:
- `ActivityType.dart` = `{ breath, meditation, root }` — `root` present as the plan assumes (note 13). ✅
- `ModuleStateStatus` = `{ idle, active }` at `ModuleState.dart:1` — matches the `status` field type in Task 1. ✅
- `test/Core/Grpc/` exists; convention source file exists. ✅
- No `equatable` dependency in the project → manual `==`/`hashCode` (as the plan implies) is the correct choice. ✅

### Warnings / Non-blocking

**W1 — "analyze clean" is at risk from premature unused state/imports (medium).**
Task 2 describes the class as one that "will hold a `Map<String, ModuleSession>`" and says "RxDart allowed, matching `ModuleStateChannel`." In a signatures-only skeleton where every body `throw UnimplementedError()`, if the implementer declares a private `_sessions` map or adds `import 'package:rxdart/rxdart.dart';` now, the analyzer emits `unused_field` / `unused_import` warnings — and `flutter analyze` exits non-zero on warnings, breaking the Verify item "`flutter analyze` is clean." Recommend the plan state explicitly: **the skeleton is signatures only — do not declare stored state or import RxDart in this milestone (note 14 adds them); if a stub field/import is unavoidable, suppress with `// ignore:`.**

**W2 — `removeTerminal` wording vs. the `status` field type (minor, clarity).**
The plan documents `removeTerminal` as "will remove on terminal status (`COMPLETED`/`INTERRUPTED`/`ABANDONED`)", but its signature is `void removeTerminal(String id)` and `ModuleSession.status` is `ModuleStateStatus {idle, active}`, which cannot represent any of those terminal values. This is actually correct by design — the terminal decision lives in the caller (note 14 / `ModuleStateChannel`, which reads proto `ActivityStatus`), and `removeTerminal` is an unconditional remove-by-id. Worth one clarifying sentence so an implementer doesn't try to branch on a `ModuleStateStatus` that can't carry terminal states.

**W3 — `dispose()` stub should be a no-op, not `UnimplementedError` (minor).**
Task 2 allows the `dispose()` body to be "empty or `throw UnimplementedError()`." If the test's `tearDown` calls `registry.dispose()` and it throws, the suite errors during teardown rather than producing the intended clean RED assertion failure. Prefer specifying an **empty** `dispose()` body (or have tests not call it) so RED comes only from the routing accessors.

**W4 — pin the `sess` helper's default `status` (minor).**
Task 1 makes `status` required in the `const` constructor; Task 3's helper `sess(id, type, {status, isPaused})` therefore needs a concrete default (e.g. `ModuleStateStatus.active`) for fixtures that omit it to compile. Small implementer detail — pin it to avoid ambiguity.

### Positive Notes
- Correct milestone decomposition: contract (types + signatures + RED tests) as one compiling, red commit; routing bodies explicitly deferred to note 14. Matches note 22 exactly.
- Test target is right: drives the **real** stateful `SessionRegistry` (not a pass-through stub), and the RED-not-erroring distinction (fail on `UnimplementedError`, not on missing symbols) is called out.
- Correctly scopes tests to the silent-failure surface (routing) and excludes loud surfaces (proto decode / enum mapping — covered by note 13's compile), consistent with the project's test philosophy.
- File paths, imports, and enum references all verified accurate against the current tree.
