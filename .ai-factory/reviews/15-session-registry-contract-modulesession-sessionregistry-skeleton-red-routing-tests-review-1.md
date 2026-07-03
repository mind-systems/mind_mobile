# Code Review — Session registry contract (`ModuleSession` + `SessionRegistry` skeleton + red routing tests)

**Scope:** `git diff HEAD` / `git status` — three new code files plus planning artifacts.
- `lib/Core/Grpc/ModuleSession.dart` (new)
- `lib/Core/Grpc/SessionRegistry.dart` (new)
- `test/Core/Grpc/session_registry_test.dart` (new)

**Milestone intent (note 22):** lay the `ModuleSession` value type + `SessionRegistry` signatures with **no routing bodies**, plus RED tests over the silent-failure routing points. The commit must compile, analyze clean, and be RED; the impl milestone (note 14) greens it.

---

## Verification performed

- **`flutter analyze` on all three files:** `No issues found!` — no `unused_import` / `unused_field` warnings (W1 from plan-review-1 was avoided: no premature `_sessions` map or RxDart import).
- **`flutter test test/Core/Grpc/session_registry_test.dart`:** all 11 tests fail, and **every failure is a thrown `UnimplementedError`** from the skeleton accessors — not a compile/missing-symbol error. This is precisely the intended RED-not-erroring state. The suite compiles and links against the real `SessionRegistry`.

## Correctness assessment

- **`ModuleSession`** — immutable value type with the four contract fields (`id`, `activityType`, `status`, `isPaused`); `const` constructor (`isPaused` defaults `false`), `copyWith`, and value `==`/`hashCode` over all four fields via `Object.hash`. `==` includes `runtimeType` and short-circuits on `identical`. Pure Dart (imports only `ActivityType` / `ModuleState`). Correct and idiomatic; matches the project's manual-equality convention (no `equatable` dependency).
- **`SessionRegistry`** — full surface declared: `upsert`, `removeTerminal`, `rootId`, `childOfType`, `rootIdChanges`, `changes`, `dispose`. All routing accessors `throw UnimplementedError()`; `dispose()` is an **empty no-op** (W3 honored) so the test `tearDown` calling `dispose()` does not error the suite. Doc comments correctly document the *intended* greened behavior and defer bodies/state to note 14. `removeTerminal` doc clarifies the terminal-status decision lives in the caller and does not branch on `ModuleSession.status` (W2 honored).
- **Tests** — drive the **real** stateful `SessionRegistry`, not a pass-through stub (m36 satisfied). The `sess` helper pins `status = ModuleStateStatus.active` / `isPaused = false` defaults (W4 honored). The five silent-failure points from note 22 are each covered: upsert-by-id (no duplicate, latest wins), removeTerminal remove-only-child (+ root not dropped), `rootId` = ROOT-entry / null / never-a-child, `childOfType` sole-of-type / null / not-root-not-other-type, and route-by-`activity_type` yielding two distinct resolvable entries. Loud surfaces (proto decode / enum mapping) are correctly excluded.

No bugs, type mismatches, security issues, migrations, or race conditions apply — this is a pure-Dart, stateless-skeleton + test commit with no runtime wiring, no I/O, and no consumers yet importing it.

## Non-blocking observation (not a defect)

- Because **all** skeleton bodies throw, every test currently short-circuits on the first `upsert(...)` call, so the accessor each test targets (e.g. `removeTerminal`, `childOfType`) is not yet exercised in the RED state. This is inherent to a signatures-only skeleton and self-resolves once note 14 implements `upsert`; no action needed.
- The upsert-by-id "no duplicate" test asserts on the observable resolution (`childOfType` returns the latest frame) rather than an entry count, since the registry exposes no size accessor. This is the correct observable to assert given note 14 backs the registry with a `Map<String,ModuleSession>` (keyed by id → duplication is structurally impossible). Adequate as written.

REVIEW_PASS
