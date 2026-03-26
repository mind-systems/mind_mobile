## Code Review Summary

**Files Reviewed:** 3 (+ generated stubs verified)
**Risk Level:** Low

### Context Gates
- **ARCHITECTURE.md:** WARN — none. DI wiring follows the documented `App.initialize()` chain: `Database -> HTTP client -> Auth Interceptor -> Repositories -> ...`. The interceptor is infrastructure, correctly placed in `App.dart`.
- **RULES.md:** WARN — none. No module-specific state added to `App.dart`; `GrpcAuthInterceptor` is pure infrastructure (auth token attachment + logout trigger). All dependencies injected via constructor.
- **ROADMAP.md:** WARN — none. Roadmap item "Instantiate once in `App._init()`" under 2.4 is checked off. Implementation matches the description.

### Files Reviewed in Full

1. **`lib/Core/Grpc/GrpcClient.dart`** (43 lines)
   - `_interceptors` stored as `final List<ClientInterceptor>`, assigned in initializer list alongside `_channel`. Follows the existing pattern.
   - All 8 `late final` stub initializers pass `interceptors: _interceptors`. The `late final` initializer correctly accesses instance field (not constructor param), which Dart allows.
   - Default `const []` keeps `GrpcClient` usable without interceptors (e.g. tests). Non-breaking.
   - Verified generated stubs: `AuthServiceClient(super.channel, {super.options, super.interceptors})` — the `interceptors:` named parameter is accepted via super forwarding in all 8 clients.

2. **`lib/Core/App.dart`** (238 lines)
   - `grpcAuthInterceptor` created at line 119, after `logoutNotifier` (line 116) and `appLifecycleService` (line 118). All dependencies available. Correct ordering.
   - `const FlutterSecureStorage()` — compile-time constant, no instantiation concern. Same constant used elsewhere (`authApi` at line 121). Consistent.
   - `interceptors: [grpcAuthInterceptor]` passed to `GrpcClient`. Single interceptor in the list — clean and extensible.
   - Import added at line 45, alphabetically placed. Correct.
   - Single-line style maintained per App.dart style rule. No trailing commas.

3. **`lib/Core/Grpc/GrpcAuthInterceptor.dart`** (68 lines, read for context — unchanged by this milestone)
   - `interceptUnary`: async token read via `CallOptions` provider, `GrpcError` code 16 triggers `LogoutNotifier.triggerLogout()`. `unawaited()` on error handler doesn't swallow the error from the caller — the original `ResponseFuture` is returned as-is.
   - `interceptStreaming`: uses `_cachedToken` synchronously (set by prior unary calls). By design per roadmap decision: streaming calls are only opened after a successful unary call.
   - No subscriptions or disposable resources — pure interceptor, no cleanup needed.

### Critical Issues

None.

### Suggestions

None.

### Positive Notes

- Clean, minimal change — only two files touched, with a precise scope.
- `_interceptors` field follows the established `_channel` pattern in `GrpcClient`, making the code consistent and easy to extend.
- Default parameter `const []` preserves backward compatibility.

REVIEW_PASS
