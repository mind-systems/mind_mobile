# Code Review: Add `BciDevicesGrpcApi`

## Scope
Changes inspected (per `git diff HEAD`):
- `lib/Core/Grpc/GrpcClient.dart` — new `bciDevicesService` late-final.
- `lib/Bci/IBciDevicesGrpcApi.dart` — new interface.
- `lib/Bci/BciDevicesGrpcApi.dart` — new concrete wrapper.
- `.ai-factory/ROADMAP.md` — lines 81 and 87 updated to reflect the corrected constructor argument and `register()` return type.

`flutter analyze lib/Bci/ lib/Core/Grpc/GrpcClient.dart` → `No issues found`.

## Verification against the plan

| Plan task | Status |
|---|---|
| Task 1: `bciDevicesService` added to `GrpcClient` with `interceptors: _interceptors`, positioned between `authService` and `breathSessionService`, no other touches | ✅ |
| Task 2: `IBciDevicesGrpcApi` with the three record-returning signatures | ✅ |
| Task 3: `BciDevicesGrpcApi implements IBciDevicesGrpcApi`, positional constructor taking `BciDevicesServiceClient`, async/await, no try/catch, no dispose | ✅ |
| Task 4: ROADMAP.md lines 81 & 87 rewritten; current milestone not prematurely `[x]`'d | ✅ |

## Correctness checks

1. **Interceptor coverage.** `bciDevicesService` is constructed with `interceptors: _interceptors`, identical to every other service in `GrpcClient` (`auth`, `breathSession`, `device`, etc.). `_interceptors` is wired in `lib/Core/App.dart:121` with `[GrpcAuthInterceptor, GrpcLoggingInterceptor]`, so the three new calls (`list`, `register`, `delete`) will (a) receive the JWT `authorization` header, (b) participate in the global `UNAUTHENTICATED → logout` flow, and (c) be logged. This was the showstopper from plan-review-1 and is now resolved.

2. **Generated stub signatures match the call sites.**
   - `BciDevicesServiceClient.list(Empty request, {CallOptions? options})` → `ResponseFuture<ListBciDevicesResponse>` — call site passes `Empty()` and awaits, then iterates `response.devices` (a `PbList<BciDevice>`). ✅
   - `register(RegisterBciDeviceRequest request, …) → ResponseFuture<BciDevice>` — call site passes `RegisterBciDeviceRequest(serial: serial)` and returns `(id: response.id, serial: response.serial)`. ✅
   - `delete(DeleteBciDeviceRequest request, …) → ResponseFuture<Empty>` — call site passes `DeleteBciDeviceRequest(id: id)` and awaits, discarding the `Empty`. ✅

3. **Import paths.**
   - `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` is the same path used by the generated `bci_devices.pbgrpc.dart` (line 18: `import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $0;`). ✅
   - `package:mind/Core/Grpc/generated/bci_devices.pbgrpc.dart` re-exports `bci_devices.pb.dart` (line 22), so a single import provides `BciDevicesServiceClient`, `RegisterBciDeviceRequest`, `DeleteBciDeviceRequest`, `BciDevice`, and `ListBciDevicesResponse`. ✅
   - `package:mind/Bci/IBciDevicesGrpcApi.dart` uses the project-standard `package:` form (matches `PersonalAccessTokenApi`'s import of `IPersonalAccessTokenApi`). ✅

4. **Record return types.** `({String id, String serial})` is valid Dart 3 record syntax. Both call sites (`listDevices`, `register`) construct the record with named fields matching the type annotation, so destructuring at the call site (`final (:id, :serial) = …`) will work as expected. Protobuf string fields default to `""` rather than `null`, so no NPE risk if the server omits a field — caller will simply see empty strings.

5. **Server ordering.** Plan says "preserve server order". `response.devices.map(...).toList()` retains the `PbList<BciDevice>` iteration order, which is the wire-protocol order produced by the server. No `sort`/`reversed` call slipped in. ✅

6. **Idempotency.** `register()` does not branch on a "already exists" response — it just returns whatever the server sent back. This is correct: the proto contract has the server return the existing `BciDevice` when a row with that `serial` already exists (per the comment in `bci_devices.pb.dart` line 19: "Maps to BciDevice entity"). The repository (next milestone) can call `register(serial)` on every successful connect without special-casing.

7. **No error handling.** Matches the plan's explicit "let gRPC errors propagate" directive. The repository layer (next milestone) owns retry/logout policy.

8. **Stateless wrapper.** No `StreamController`, no `StreamSubscription`, no `dispose()` — complies with `.ai-factory/RULES.md` rule 1.

## Style / lint

- `flutter analyze` clean on the changed files.
- Naming and file placement match `lib/Bci/NeiryBciProvider.dart` and `lib/McpModule/PersonalAccessTokenApi.dart`.
- No unused imports — every imported symbol is referenced.
- No `dart:async` import in either new file (correct — `Future` lives in `dart:core`).

## ROADMAP.md changes

Both edits land exactly where the plan said:
- Line 81 substitutes `bciDevicesService` for `channel` and bumps the `register` signature to `Future<({String id, String serial})>`.
- Line 87 substitutes `grpcClient.bciDevicesService` for `grpcClient.channel` in the `BciNotifier` wiring example so the downstream task stays consistent.
- The current milestone checkbox on line 81 remains `[ ]` — correct, per the plan's instruction to leave that to `/aif-verify`.

## Findings

None. The implementation matches the plan exactly, addresses the auth/logging concern from plan-review-1, type-checks against the generated stubs, and the downstream roadmap row was patched so the next milestone won't reintroduce the channel-based constructor.

REVIEW_PASS
