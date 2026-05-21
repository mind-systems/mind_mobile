# Plan Review: Add `BciDevicesGrpcApi` (iteration 2)

## Plan Review Summary

**Plan File:** `.ai-factory/plans/35-add-bcidevicesgrpcapi.md`
**Risk Level:** 🟢 Low

### Context Gates

- **ARCHITECTURE.md:** OK — the revised plan re-establishes the documented `GrpcClient → service client (with interceptors)` flow. `bciDevicesService` is added next to the other `late final` service clients in `GrpcClient`, so `GrpcAuthInterceptor` + `GrpcLoggingInterceptor` apply automatically. Constructor injection (Service interface declared near the consumer) matches the layered/module convention.
- **RULES.md:** OK — wrapper is stateless, no `StreamController`/`StreamSubscription`/`dispose()`, DI via positional constructor. Empty interceptor list is no longer a risk because the field uses `_interceptors`.
- **ROADMAP.md:** OK — task is anchored to the current Phase 17 row (line 81) and Task 4 explicitly updates both lines 81 and 87 so the directive chain stays consistent for the next milestone (`BciNotifier` wiring). No other roadmap rows reference the previous `channel`-based signature.

---

### Critical Issues

None. All three blocking issues from review 1 (no interceptors, `Empty` import correctness, `register()` returning `void`) are resolved:

- **Auth/logging restored** — Task 1 routes through `_interceptors`, identical to the eight existing service clients on `GrpcClient` (verified in `lib/Core/Grpc/GrpcClient.dart:30-37`). `_interceptors` already contains `[GrpcAuthInterceptor, GrpcLoggingInterceptor]` (wired in `lib/Core/App.dart:121`), so JWT attach + global logout on `UNAUTHENTICATED` will work uniformly.
- **`register()` returns the device record** — `Future<({String id, String serial})>` matches `BciDevicesServiceClient.register` returning `BciDevice` (verified in generated `bci_devices.pbgrpc.dart:43-48` and `BciDevice` definition in `bci_devices.pb.dart:22-109`). The forward-compatibility argument from review 1 issue 7 is properly addressed.
- **`Empty` import path** — `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` matches the path used by the generated stub itself (`bci_devices.pbgrpc.dart:18`), so it resolves with no extra dependency. ✅

---

### Non-Critical Issues

#### 1. 🟡 Interface convention divergence — minor

The plan adds `IBciDevicesGrpcApi` at `lib/Bci/IBciDevicesGrpcApi.dart`, paired with its implementation in the same folder. That mirrors `lib/User/IAuthApi.dart` ↔ `AuthApi.dart` and `lib/BreathModule/Core/IBreathSessionApi.dart` ↔ `BreathSessionApi.dart`. ✅

However, the class is named `BciDevicesGrpcApi` (with the `Grpc` infix), while every comparable wrapper in the project drops it: `AuthApi`, `UserApi`, `StatsApi`, `BreathSessionApi`, `PersonalAccessTokenApi`. None encode the transport in the type name even though every one of them wraps a gRPC service client. The `Grpc` infix is therefore a small naming inconsistency. Two options for the architect:

- Accept the deviation — the explicit `Grpc` infix is defensible because `lib/Bci/` may later add a non-gRPC adapter (`NeiryBciProvider` is already there for BLE), and the more specific name disambiguates.
- Rename to `BciDevicesApi` / `IBciDevicesApi` to match the rest of the codebase.

Not blocking. Just flag it so the architect doesn't sleepwalk into a divergent convention. Worth noting that ROADMAP.md line 81 and the next two roadmap rows already use the name `BciDevicesGrpcApi`, so renaming has a slightly wider blast radius.

#### 2. 🟡 Record DTO at the wrapper boundary — preserved from review 1

`({String id, String serial})` records are valid Dart 3.3+ (project is on `@dart = 3.3`, see any generated file). The plan's choice is fine for this layer. But the next roadmap row (`BciDeviceRepository.fetchKnownSerials()`) downgrades the record to `List<String>` immediately, which means the `id` is thrown away one layer up. Two cases to consider:

- If the repository will eventually need `id` (e.g. to support "delete the device I just connected" without a `list` round-trip), the records pay off. The plan's `register()` return type signals exactly this forward intent — good.
- If `id` will never be consumed mobile-side and the only callers want `List<String>`, returning a record is slightly over-engineered. Either is defensible; the plan's choice is the more conservative one.

Not blocking.

#### 3. 🟢 GrpcClient field placement & alphabetical ordering — verified

Plan says "alphabetical-by-feature, between `authService` and `breathSessionService`". Checked `lib/Core/Grpc/GrpcClient.dart:30-37`: the existing list is `authService`, `breathSessionService`, `deviceService`, `moduleStateService`, `instructionStreamService`, `statsService`, `syncService`, `userService` — it is **not** strictly alphabetical (`instructionStreamService` follows `moduleStateService`). So "alphabetical-by-feature" is aspirational rather than enforced. Placing `bciDevicesService` between `authService` and `breathSessionService` is still a sensible position (`b` < `br`) and matches the plan's directive. Minor: the implementer might want to confirm the position with the architect, but it doesn't change correctness.

#### 4. 🟢 `BciDevice` field names — verified

Generated message exposes `id`, `serial`, `createdAt`, `updatedAt` (see `bci_devices.pb.dart:22-109`). Plan only reads `id` and `serial` from `register` response and from each `BciDevice` in `ListBciDevicesResponse.devices`. ✅

#### 5. 🟢 Re-export coverage — verified

`bci_devices.pbgrpc.dart:22` (`export 'bci_devices.pb.dart';`) means a single import gives access to `BciDevicesServiceClient`, `RegisterBciDeviceRequest`, `DeleteBciDeviceRequest`, `ListBciDevicesResponse`, and `BciDevice`. The plan's import list is minimal and correct. ✅

#### 6. 🟡 Server `updated_at DESC` ordering — still unverified mobile-side

Plan asserts the server returns devices ordered by `updated_at DESC` and forbids local re-sorting. Nothing in the generated proto or in `mind_mobile/` can confirm this — the assertion lives in `mind_api/` controller/service code. Recommend the implementer (or `/aif-verify`) confirms once by reading the corresponding `mind_api/src/bci/...` controller. Not blocking for this plan since the comment in the wrapper is descriptive and the wrapper itself does not reorder.

#### 7. 🟢 `register` idempotency claim — propagated through the layer correctly

Plan documents server-side idempotency on `serial` and uses it to justify the next roadmap row's "register on every successful connect" behaviour. Same caveat as #6 — verify against `mind_api/src/bci/...` if not already done. Not blocking the wrapper.

#### 8. 🟢 No regression on `_channel` exposure

Task 1 explicitly forbids exposing `_channel` publicly. The earlier draft would have leaked the channel as a getter; the revised plan no longer needs it because the late-final service does the channel binding internally. Encapsulation preserved. ✅

#### 9. 🟢 ROADMAP cascade — Task 4 scope

Task 4 updates ROADMAP.md lines 81 and 87 only. Lines 89+ (`bci_module` package work) do not reference `BciDevicesGrpcApi` directly, so no further roadmap edits are needed. Grep-verified scope: only the current milestone row and the `BciNotifier` row reference `grpcClient.channel` or `BciDevicesGrpcApi`. ✅

#### 10. 🟢 Patterns/conventions parity

- Constructor style (`BciDevicesGrpcApi(this._client);`) matches `PersonalAccessTokenApi(this._authService)` exactly (verified in `lib/McpModule/PersonalAccessTokenApi.dart:10`).
- All methods `async`/`await`; no leaked `ResponseFuture`s.
- No `try/catch` — error policy correctly owned by the repository layer.
- File naming uses PascalCase (`BciDevicesGrpcApi.dart`) consistent with `NeiryBciProvider.dart` and `PersonalAccessTokenApi.dart`.

---

### Positive Notes

- Critical fix from review 1 is correctly absorbed and the rationale is documented in the "Deviation from roadmap directive" section — future readers won't be confused by the directive change.
- Task 4 closes the loop on the roadmap so the chain (`BciDevicesGrpcApi` → `BciDeviceRepository` → `BciDeviceManager` → `BciNotifier`) stays consistent. This is the kind of small bookkeeping that often gets skipped.
- Plan adopts review 1 issue 7 (record-bearing `register`) without over-engineering — `({String id, String serial})` is the minimal forward-compatible shape.
- Phasing is sensible: client registration → interface → implementation → roadmap fix. Each phase has a single concern.
- Imports are pinned to exact paths and re-export coverage is checked, removing one implementation-time guess.
- Scope is narrow: three methods, one new field on `GrpcClient`, no domain types, no notifier, no caching — matches "thin infrastructure adapter".

---

### Verdict

Plan is ready to implement. All critical issues from review 1 are resolved. The remaining items are stylistic flags (naming convention `BciDevicesGrpcApi` vs `BciDevicesApi`) and verifications (server `updated_at DESC` ordering, server idempotency) that can be confirmed without changing the plan.

PLAN_REVIEW_PASS
