## Plan Review Summary

**Plan:** Session registry contract — `ModuleSession` + `SessionRegistry` skeleton + red routing tests
**Files Reviewed:** plan + targeted codebase (`ActivityType.dart`, `ModuleState.dart`, `test/Core/Grpc/module_state_channel_test.dart`, `analysis_options.yaml`, notes 13/14/22, ROADMAP.md, plan-review-1)
**Risk Level:** 🟢 Low

### Context Gates
- **Architecture:** PASS. `lib/Core/Grpc/` is the documented home for gRPC transport + `ModuleStateChannel`; adding `ModuleSession`/`SessionRegistry` alongside it fits. Pure-Dart (no Flutter/Riverpod) matches the domain/gRPC boundary. Verified the directory already holds `ModuleState.dart`, `ModuleStateChannel.dart`, `ActivityType.dart`.
- **Rules:** PASS. The registry is a routing layer, not an `IXxxService` Module Service, so its held state + `dispose()` are permitted.
- **Roadmap:** PASS. Milestone present at `ROADMAP.md:52` with `Spec: .ai-factory/notes/22-rootchild-registry-contract.md`. The contract line's surface (`rootId`, `childOfType`, `upsert`, `removeTerminal`, streams — no bodies; stateful double not pass-through stub; RED tests over the five silent points) maps 1:1 to the plan's tasks. The impl/green step is correctly deferred to note 14 (`ROADMAP.md:53`).

### Round-1 follow-up (all four warnings resolved)
- **W1 (analyze-clean risk from premature unused state/imports):** RESOLVED. Task 2 now states explicitly "Signatures only — do not declare stored state (`_sessions` map, subjects) or `import 'package:rxdart/rxdart.dart';` in this milestone (note 14 adds them)", cites `unused_field`/`unused_import` breaking the Verify gate, and offers the scoped `// ignore:` escape hatch. ✅
- **W2 (`removeTerminal` wording vs. `status` field type):** RESOLVED. Task 2 now clarifies the terminal-status decision (`COMPLETED`/`INTERRUPTED`/`ABANDONED`) lives in the caller (`ModuleStateChannel`, note 14), and `removeTerminal` is an unconditional remove-by-id that does not branch on `ModuleSession.status` (only `{idle, active}`). ✅
- **W3 (`dispose()` stub):** RESOLVED. Task 2 now mandates an **empty no-op** `dispose()` (not `UnimplementedError`) so a `tearDown` call doesn't error the suite; RED comes only from the routing accessors. ✅
- **W4 (pin the `sess` helper default):** RESOLVED. Task 3 now specifies the helper must supply a concrete default (`status = ModuleStateStatus.active`) since `status` is required in the `const` constructor. ✅

### Codebase verification
- `ActivityType.dart` = `enum ActivityType { breath, meditation, root }` — `root` present as assumed (added by note 13). ✅
- `ModuleState.dart:1` = `enum ModuleStateStatus { idle, active }` — matches the `status` field type and the `.dart:1` reference in Task 1. ✅
- `test/Core/Grpc/` exists; `module_state_channel_test.dart` present as the convention source, imports `ActivityType`/`ModuleState`/proto stubs — Task 3's "follow the conventions there" is achievable. ✅
- No `equatable` dependency → manual `==`/`hashCode` (implied by Task 1) is the correct choice. ✅
- `flutter analyze` non-zero-on-warnings concern is real (default Flutter analyzer behavior), and W1's guidance correctly neutralizes it.

### Critical Issues
None.

### Positive Notes
- Clean contract/impl split: types + signatures + RED tests as one compiling red commit; routing bodies explicitly deferred to note 14. Matches note 22 exactly.
- Test target is right: drives the **real** stateful `SessionRegistry` (m36 rationale carried through), and the RED-not-erroring distinction (fail on `UnimplementedError`, not on missing symbols) is called out.
- Scopes tests to the silent-failure routing surface and excludes loud surfaces (proto decode / enum mapping — covered by note 13's compile), consistent with the project's test philosophy.
- The five test cases map exactly to note 22's five silent-failure points.

PLAN_REVIEW_PASS
