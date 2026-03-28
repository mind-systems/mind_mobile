# Patch: 44-delete-livesessiongrpcservice

**Source:** `44-delete-livesessiongrpcservice-review-1.md`
**Scope:** 1 suggestion (0 critical issues)

---

## Fix 1: Stale `LiveSessionGrpcService` reference in testing docs

**File:** `docs/core/testing.md`
**Line:** 37
**Problem:** The "Do not test these" table still lists `LiveSessionGrpcService` as an example infrastructure class. The class was deleted in milestone 7.4 — this reference is now misleading.

**Current:**
```
| **Infrastructure** (`LiveSessionGrpcService`, `GrpcAuthInterceptor`, `GrpcClient`) | Require mocking gRPC. Fragile, expensive to maintain, simple logic. |
```

**Replace with:**
```
| **Infrastructure** (`GrpcConnectionManager`, `ModuleInstructionStream`, `GrpcAuthInterceptor`, `GrpcClient`) | Require mocking gRPC. Fragile, expensive to maintain, simple logic. |
```

**Rationale:** `GrpcConnectionManager` and `ModuleInstructionStream` are the current infrastructure classes that replaced `LiveSessionGrpcService`. They carry the same "don't unit-test" reasoning (gRPC mocking is fragile). `ModuleStateChannel` is omitted because it already has event-driven logic complex enough that it could warrant testing in the future — listing it here would preemptively discourage that.
