# Plan Review: Add `BciDevicesGrpcApi`

## Plan Review Summary

**Plan File:** `.ai-factory/plans/35-add-bcidevicesgrpcapi.md`
**Risk Level:** 🔴 High

### Context Gates

- **ARCHITECTURE.md:** WARN — the documented stack flow is `Google Sign-In → Database → GrpcAuthInterceptor → GrpcClient`. The plan deliberately bypasses `GrpcAuthInterceptor` for this new client (see Critical Issue 1), which contradicts the documented auth architecture.
- **RULES.md:** OK — the planned class has no `StreamController`, `StreamSubscription`, or `dispose()`, in line with the "stateless wrappers" rule. DI is via constructor.
- **ROADMAP.md:** OK — task is anchored to Phase 17 ("BCI Device Pairing"), and the next roadmap row depends on `BciDevicesGrpcApi`. However, the roadmap row itself contains the seed of the critical bug (see below).

---

### Critical Issues

#### 1. 🔴 No interceptors → every call will return `UNAUTHENTICATED`

The plan instructs Task 2 to build the service client like this:

```dart
BciDevicesGrpcApi(ClientChannel channel) : _client = BciDevicesServiceClient(channel);
```

and explicitly forbids using the `bciDevicesService` field on `GrpcClient`:

> *"do NOT add a `bciDevicesService` late-final field (the milestone deliberately routes the new API around the established per-service-client pattern by taking a raw channel)."*

Every other service in the project is constructed by `GrpcClient` with `interceptors: _interceptors` (see `lib/Core/Grpc/GrpcClient.dart:30-37`). Those interceptors are `[GrpcAuthInterceptor, GrpcLoggingInterceptor]`, wired in `lib/Core/App.dart:121`. `GrpcAuthInterceptor` is the **only** thing that reads the JWT from `FlutterSecureStorage` and attaches the `authorization: Bearer …` metadata header (see `lib/Core/Grpc/GrpcAuthInterceptor.dart:19-24, 39, 54`).

A `BciDevicesServiceClient` built from the raw channel with **no** `interceptors` list:

- Sends no `authorization` header → the server rejects `list`, `register`, and `delete` with `UNAUTHENTICATED` (gRPC code 16).
- Bypasses `_onUnauthenticatedError` (`GrpcAuthInterceptor.dart:26-30`), so failed BCI calls will not trigger the global logout flow described in `docs/core/jwt-authentication.md`.
- Bypasses `GrpcLoggingInterceptor`, so failures will be invisible in logs even though Setting "Logging: minimal" implicitly assumes interceptor-level coverage (the plan adds no per-method `log()` calls).

This is a showstopper — Tasks 3-8 in the roadmap (`BciDeviceRepository`, `BciDeviceManager`, `BciNotifier`, the entire pairing UI) all depend on `listDevices()`/`register()`/`delete()` succeeding. As written, none of them will work on a real backend.

**Recommended fix** (any of these — list in order of preference):

1. **Follow the existing pattern.** Add `late final bciDevicesService = BciDevicesServiceClient(_channel, interceptors: _interceptors);` to `GrpcClient`, change Task 1 to expose **that** instead of the channel, and change the `BciDevicesGrpcApi` constructor to take `BciDevicesServiceClient` — identical to `PersonalAccessTokenApi(grpcClient.authService)` (`lib/McpModule/PersonalAccessTokenApi.dart:10`). This costs nothing and matches the documented module-boundary convention.
2. If the architect insists on a channel-based constructor, expose both the channel and the interceptor list and forward them: `BciDevicesServiceClient(channel, interceptors: interceptors)`. Strictly worse than option 1 because every caller has to remember the second argument.
3. At minimum, document the auth/logging gap so the next milestone can rewire it.

The plan should also be challenged at the roadmap level — line 81 of `ROADMAP.md` is what seeded the directive (`pass App.shared.grpcClient.channel to constructor`), and that line should change too.

---

### Non-Critical Issues

#### 2. 🟡 Diverges from the project-wide `IXxxApi` interface convention

Every other gRPC API wrapper in `lib/` is paired with an interface:

- `lib/User/AuthApi.dart` ↔ `IAuthApi.dart`
- `lib/User/UserApi.dart` ↔ `IUserApi.dart`
- `lib/BreathModule/Core/BreathSessionApi.dart` ↔ `IBreathSessionApi.dart`
- `lib/McpModule/PersonalAccessTokenApi.dart` ↔ `Core/Api/IPersonalAccessTokenApi.dart`

The plan deliberately omits `IBciDevicesGrpcApi`. With Setting "Testing: no" this is defensible, but the next roadmap row constructs `BciDeviceRepository({required BciDevicesGrpcApi api, …})` — the repository takes the concrete class, which makes the repository untestable without also creating the interface. Worth either adding `IBciDevicesGrpcApi` here or noting explicitly that the repository task will pull it up. The plan should at least acknowledge the deviation.

#### 3. 🟡 Anonymous record type is fine syntactically, but consider a DTO

`Future<List<({String id, String serial})>>` is valid Dart 3 syntax, but a single named DTO (`BciDeviceListEntry` / similar) — sibling to `BciDeviceInfo` already in `lib/Bci/Models/` (created in roadmap task 32) — is friendlier to the repository code that has to consume `(d.id, d.serial)` tuples. Records are also harder to mock and pretty-print. Not blocking; flag for the architect.

#### 4. 🟢 `Empty` import path — verified correct

`Empty` is declared in `package:protobuf/well_known_types/google/protobuf/empty.pb.dart` and is **not** re-exported by `bci_devices.pbgrpc.dart` (only `bci_devices.pb.dart` is re-exported). The plan correctly calls out the separate import. ✅

#### 5. 🟢 Re-export coverage — verified correct

`bci_devices.pbgrpc.dart` line 22 (`export 'bci_devices.pb.dart';`) makes a single import sufficient for `BciDevicesServiceClient`, `RegisterBciDeviceRequest`, `DeleteBciDeviceRequest`, `ListBciDevicesResponse`, and `BciDevice`. ✅

#### 6. 🟢 Server ordering claim — verified plausible

`BciDevice` carries `updatedAt`. The plan's claim that the server returns devices ordered `updated_at DESC` is consistent with the proto comment ("Maps to BciDevice entity in src/bci/entities/bci-device.entity.ts") and the project-wide convention for list endpoints. Worth a one-line sanity check against the API contract before implementation, but not blocking the plan.

#### 7. 🟡 `register()` returns `void` — discards `BciDevice.id`

The server returns the newly-created (or existing) `BciDevice` from `register`. The plan discards it. The next roadmap task (`BciDeviceManager`) calls `repository.registerDevice(serial)` idempotently on every successful connect, but never asks for the `id` back. If `BciDeviceManager` ever needs the device id without doing a `list` round-trip first (for example, to support a "delete this device" gesture on the just-registered device), returning `Future<({String id, String serial})>` from `register()` is essentially free and forward-compatible. Worth raising as an option.

#### 8. 🟢 `GrpcClient.channel` getter — fine

Exposing `ClientChannel get channel => _channel;` is harmless and does not violate encapsulation since the channel is already shared across all `late final` service fields. Only flagged because — if the critical fix above lands — the getter may not even be needed.

---

### Positive Notes

- Plan correctly insists on `async`/`await` rather than leaking `ResponseFuture` to the caller.
- Correctly avoids `try/catch` so the repository layer owns error policy.
- Correctly notes the server's `updated_at DESC` ordering and forbids local re-sorting.
- File location (`lib/Bci/BciDevicesGrpcApi.dart`) and PascalCase naming match `lib/Bci/NeiryBciProvider.dart` and `lib/McpModule/PersonalAccessTokenApi.dart`.
- Plan adheres to RULES.md — stateless wrapper, constructor injection, no `dispose()`.
- Scope is narrow and ordered correctly (channel exposure first, then API).

---

### Verdict

The plan must be revised before implementation. Critical Issue 1 will cause every BCI gRPC call to fail at runtime, which will block the entire Phase 17 roadmap. Issues 2 and 7 are smaller architectural smells worth raising. Issues 4-6 and 8 are verifications, included so the next reviewer doesn't have to re-check them.
