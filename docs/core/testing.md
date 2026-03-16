# Testing Approach

## Philosophy

Tests should verify **black boxes**, not implementation details.

A black box is a unit with a well-defined contract:
- **Observable inputs** — method calls, injected streams
- **Observable outputs** — returned values, emitted stream events, calls made to fakes

The internals of the box (private fields, internal loops, helper methods) are not the subject of tests. If a refactor leaves inputs and outputs unchanged, all tests should still pass.

> Analogy: test that a function computes the correct result, not that it uses a specific algorithm internally.

---

## What to Test

### Test these layers

| Layer | Why |
|-------|-----|
| **Domain Notifiers** (`BreathSessionNotifier`, `UserNotifier`, `LiveSessionNotifier`) | Complex state machines with pagination, event emission, race condition guards — high regression risk |
| **Repositories** (`BreathSessionRepository`, `UserRepository`, `AppSettingsRepository`) | Cache/fallback logic, data mapping — behaviour is non-obvious from reading the code |
| **Pure calculators / data structures** (`ComplexityCalculator`, `TelemetryBuffer`) | Deterministic functions with non-trivial formulas — cheap to test, high value |
| **State machines** (`BreathSessionStateMachine`) | Phase transitions driven by external ticks — core UX logic |
| **Deep link parsers / handlers** (`AuthCodeDeeplinkHandler`, `BreathSessionDeeplinkHandler`) | URI contracts are easy to break silently |

### Do not test these

| Layer | Why |
|-------|-----|
| **ViewModels** (Riverpod `Notifier`) | They orchestrate, they don't compute. The logic they expose is already covered by the domain layer beneath them. Testing `isLoading = true` after a call tests Riverpod, not your code. |
| **Services** (bridge between domain and presentation) | Thin translation layers. Their inputs and outputs are the domain notifier and the ViewModel interface — both of which are already tested at their own level. |
| **Mappers / converters** | Mechanical field assignments. Bugs here are caught immediately at runtime and are obvious to read. |
| **Navigation coordinators** | Routing calls — easy to verify manually, hard to fake correctly, low regression risk. |
| **Infrastructure** (`LiveSocketService`, `AuthInterceptor`, `HttpClient`) | Require mocking socket.io / Dio. Fragile, expensive to maintain, simple logic. |
| **Animation coordinators** | Exception: keep existing animation tests that guard against known regressions (pause/resume bugs). Don't add new ones. |

---

## How to Write Fakes

Use hand-written `Fake*` classes, not mocking libraries.

```dart
// Good — clear, readable, explicit
class FakeBreathSessionRepository implements IBreathSessionRepository {
  final List<BreathSession> _store = [];
  bool deleteAllCalled = false;

  @override
  Future<BreathSession> create(BreathSession session) async {
    _store.add(session);
    return session;
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCalled = true;
    _store.clear();
  }
  // ... other methods
}
```

**Rules for fakes:**
- Implement the interface, not the concrete class
- Store state in plain lists/maps — no real I/O
- Expose `Completer`s for async methods that need manual control (see `FakeUserRepository` pattern in `UserNotifier_test.dart`)
- Expose flags (`deleteAllCalled`) only when the test needs to verify a side effect
- Keep fakes in the test file that uses them — do not share across test files

### Injecting streams

When a class subscribes to a `Stream<T>` (e.g. `authStream`), inject a `StreamController` and emit events on demand:

```dart
final authController = StreamController<AuthState>.broadcast();
final notifier = BreathSessionNotifier(
  repository: fakeRepo,
  authStream: authController.stream,
);

// In test:
authController.add(AuthenticatedState(newUser));
await Future.delayed(Duration.zero); // let the listener run
```

This is why `BreathSessionNotifier` and `LiveSessionNotifier` accept `Stream<AuthState>` instead of `UserNotifier` — streams are trivially injectable; concrete notifiers are not.
