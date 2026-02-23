# Architecture: Layered Flutter Architecture with Domain/Module Boundary

## Overview

The app uses a strict layered architecture where each layer has a single responsibility and dependencies flow top-to-bottom. The critical design decision is the **domain/module boundary** — the Service layer acts as a translation zone that converts domain models to DTOs, ensuring that the presentation module is fully decoupled from the domain and could be extracted into its own package without modification.

This was chosen because the app has meaningful business logic (breathing phases, pagination, auth token lifecycle) that benefits from isolation in a pure-Dart domain, while the Flutter UI layer evolves independently for UX and theming concerns.

## Decision Rationale

- **Project type:** Flutter mobile app with offline-first local DB + remote API sync
- **Tech stack:** Dart/Flutter, Riverpod (presentation), RxDart (domain), Drift (SQLite), Dio (HTTP)
- **Key factor:** Domain logic must be testable without Flutter; UI must be replaceable without touching business logic

## Layer Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Screen + Coordinator   (Flutter UI + GoRouter navigation)      │
├─────────────────────────────────────────────────────────────────┤
│  ViewModel              (Riverpod StateNotifier — module root)  │
├─── MODULE BOUNDARY ─────────────────────────────────────────────┤
│  Service Interface      (declared in module, implemented below) │
├─────────────────────────────────────────────────────────────────┤
│  Service (concrete)     (maps domain events → DTOs)             │
├─────────────────────────────────────────────────────────────────┤
│  Notifier               (RxDart BehaviorSubject, typed events)  │
├─────────────────────────────────────────────────────────────────┤
│  Repository             (Drift DB + Dio API)                    │
└─────────────────────────────────────────────────────────────────┘
```

## Folder Structure

```
lib/
├── Core/                           # App infrastructure (shared across modules)
│   ├── App.dart                    # Manual DI — initialization root
│   ├── Database/                   # Drift schema + DAOs
│   ├── Api/                        # Dio client + AuthInterceptor
│   └── GlobalUI/                   # GlobalKeys, GlobalListeners
│
├── <FeatureModule>/                 # One folder per feature (e.g. BreathModule, User)
│   ├── Core/                       # Domain layer (pure Dart)
│   │   ├── Models/                 # Domain models + typed event enums
│   │   ├── <Feature>Notifier.dart  # RxDart BehaviorSubject + event emission
│   │   └── <Feature>Repository.dart
│   │
│   ├── Models/                     # Domain-level shared models
│   ├── <Feature>Service.dart       # Concrete service: domain → module DTOs
│   ├── <Feature>DTOMapper.dart     # (optional) Shared domain→DTO mapping helpers
│   │
│   └── Presentation/
│       └── <ScreenName>/           # One folder per screen
│           ├── I<Screen>Service.dart      # Service interface + DTO event types
│           ├── I<Screen>Coordinator.dart  # Coordinator interface
│           ├── <Screen>ViewModel.dart     # Riverpod StateNotifier
│           ├── <Screen>Screen.dart        # Flutter Widget
│           └── Models/                    # Screen-local DTOs + UI state
│
└── Views/                          # Shared UI components
```

## Dependency Rules

```
Screen         → ViewModel, Coordinator interface
ViewModel      → Service interface, Coordinator interface (no domain types)
Service (impl) → Notifier, domain models (converts to DTOs)
Notifier       → Repository (pure Dart only)
Repository     → Drift DAOs, Dio ApiService
```

- ✅ ViewModel depends on Service **interface** (declared in the module)
- ✅ Concrete Service depends on Notifier and maps domain → DTOs
- ✅ Coordinator depends on GoRouter + other Screen paths
- ❌ ViewModel must NOT import domain models (`BreathSession`, etc.)
- ❌ Screen must NOT call Repository or Notifier directly
- ❌ Notifier and Repository must NOT import `flutter/` or `riverpod`
- ❌ Domain models must NOT appear in Screen or ViewModel files

## Layer Communication

### Domain → Module: Typed Event Streams

The Notifier emits a sealed event class via RxDart. The Service subscribes, maps events to DTOs, and re-emits a module-local sealed event class.

```dart
// Domain layer (lib/BreathModule/Core/Models/)
sealed class BreathSessionNotifierEvent {}
class SessionCreated extends BreathSessionNotifierEvent {
  final BreathSession session; // domain model
  SessionCreated(this.session);
}

// Module boundary (lib/BreathModule/Presentation/BreathSessionsList/)
sealed class BreathSessionListEvent {}
class SessionCreatedEvent extends BreathSessionListEvent {
  final BreathSessionListItemDTO session; // DTO only — no domain model
  SessionCreatedEvent(this.session);
}
```

### Service Interface (declared at module boundary)

The interface is defined inside `Presentation/<ScreenName>/`, alongside the ViewModel. This ensures the module depends only on its own contract.

```dart
// lib/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart
abstract class IBreathSessionListService {
  Stream<BreathSessionListEvent> observeChanges();
  Future<void> fetchPage(int page, int pageSize);
  Future<void> refresh(int pageSize);
}
```

### Coordinator Interface (declared at module boundary)

Navigation belongs to the Coordinator, not the ViewModel. The ViewModel only calls the interface.

```dart
// I<Screen>Coordinator.dart — inside the module
abstract class IBreathSessionListCoordinator {
  void openSession(String sessionId);
}

// <Screen>Coordinator.dart — outside the module, depends on GoRouter
class BreathSessionListCoordinator implements IBreathSessionListCoordinator {
  final BuildContext context;
  BreathSessionListCoordinator(this.context);

  @override
  void openSession(String sessionId) {
    context.push(BreathSessionScreen.path, extra: sessionId);
  }
}
```

### ViewModel (Riverpod StateNotifier)

Subscribes to the Service stream, converts DTOs to UI models, delegates navigation to Coordinator. Never holds domain types.

```dart
class BreathSessionListViewModel extends StateNotifier<BreathSessionListState> {
  final IBreathSessionListService service;
  final IBreathSessionListCoordinator coordinator;

  BreathSessionListViewModel({required this.service, required this.coordinator})
      : super(BreathSessionListState.loading()) {
    service.observeChanges().listen(_onEvent);
  }

  void _onEvent(BreathSessionListEvent event) {
    switch (event) {
      case SessionCreatedEvent e: _handleCreated(e.session); break;
      case SessionDeletedEvent e: _handleDeleted(e.id); break;
      // ...
    }
  }

  void onSessionTap(String sessionId) => coordinator.openSession(sessionId);
}
```

### DI Wiring (App.dart)

Manual DI in `App.shared`. Initialization order is fixed:

```
Firebase → Drift DB → Dio ApiService → AuthInterceptor
→ Repositories → Domain Notifiers → DeeplinkRouter
→ runApp(ProviderScope(overrides: [...]))
```

The Riverpod provider is declared with `throw UnimplementedError` and overridden at the `ProviderScope` level:

```dart
final breathSessionListViewModelProvider =
    StateNotifierProvider<BreathSessionListViewModel, BreathSessionListState>(
      (ref) => throw UnimplementedError('Must be overridden at ProviderScope'),
    );

// In App.dart / main:
ProviderScope(
  overrides: [
    breathSessionListViewModelProvider.overrideWith(
      (ref) => BreathSessionListViewModel(
        service: app.breathSessionListService,
        coordinator: BreathSessionListCoordinator(navigatorKey.currentContext!),
      ),
    ),
  ],
  child: MyApp(),
)
```

## Creating a New Module — Checklist

When adding a new feature `FooModule`:

1. **Domain** — `lib/FooModule/Core/`
   - [ ] `FooNotifierEvent.dart` — sealed class with all event types
   - [ ] `FooNotifier.dart` — `BehaviorSubject<FooNotifierEvent>`, pure Dart
   - [ ] `FooRepository.dart` — Drift DAO + Dio calls, pure Dart

2. **Service**
   - [ ] `lib/FooModule/FooService.dart` — implements `IFooService`, subscribes to `FooNotifier`, maps domain → DTOs

3. **Presentation** — `lib/FooModule/Presentation/FooScreen/`
   - [ ] `IFooService.dart` — interface + module-local sealed event class + DTOs
   - [ ] `IFooCoordinator.dart` — navigation interface
   - [ ] `FooViewModel.dart` — `StateNotifier<FooState>`, depends only on `IFooService` + `IFooCoordinator`
   - [ ] `FooScreen.dart` — Flutter widget, reads from `fooViewModelProvider`
   - [ ] `Models/FooState.dart` — UI state (no domain types)

4. **Wiring**
   - [ ] Register `FooRepository`, `FooNotifier`, `FooService` in `App.dart`
   - [ ] Add `fooViewModelProvider` override in `ProviderScope`
   - [ ] Add `FooCoordinator` (concrete) — implements `IFooCoordinator`, uses GoRouter
   - [ ] Add route to `lib/router.dart`

## Key Principles

1. **Domain is pure Dart** — No `import 'package:flutter/...'` or `import 'package:riverpod/...'` in Notifier or Repository.
2. **DTOs stop at the boundary** — The Service converts domain models to DTOs; the ViewModel never sees raw domain models.
3. **Service interface lives in the module** — The interface is declared alongside the ViewModel, not in the domain layer.
4. **Navigation belongs to Coordinator** — The ViewModel calls `coordinator.openFoo()`, never `context.push(...)` or `GoRouter.of(context)`.
5. **Events are typed, not ad-hoc** — Add a new event class rather than using raw booleans or strings to communicate domain changes.
6. **Providers are overridden at the root** — All concrete dependencies are injected at `ProviderScope` level; providers throw by default.

## Anti-Patterns

- ❌ Importing `BreathSession` (domain model) inside a ViewModel or Screen
- ❌ Calling `Repository` methods from the ViewModel or Screen
- ❌ Using `context.push(...)` inside a ViewModel — delegate to Coordinator
- ❌ Emitting bare `bool` or `String` from a Notifier instead of a typed event class
- ❌ Declaring the Service interface in the domain layer (it belongs in the module)
- ❌ Adding Riverpod `ref` or Flutter imports to a Notifier or Repository
- ❌ Skipping the DTO conversion and passing domain models directly to the ViewModel
