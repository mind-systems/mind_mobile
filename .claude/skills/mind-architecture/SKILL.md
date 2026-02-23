---
name: mind-architecture
description: Use when implementing new features or modules in the mind Flutter app. Enforces the layered architecture pattern (Repository → Notifier → Service → ViewModel → Screen + Coordinator) with strict domain/module boundary rules.
---

# mind-architecture skill

Use this skill whenever you are adding a new feature, module, screen, or domain entity to the mind Flutter app. It enforces the project's layered architecture, boundary rules, and naming conventions as they exist in the codebase today.

---

## 1. Layer overview

```
Repository (Drift DB + Dio API)
    ↕  pure Dart — no Flutter, no Riverpod
Notifier (RxDart BehaviorSubject — domain state + typed events)
    ↕
Service (implements IXxxService declared at module boundary;
         converts domain models → module-local DTOs)
    ↕  domain models stop here; DTOs cross this line
ViewModel (Riverpod StateNotifier — module boundary)
    ↕
Screen + Coordinator (Flutter UI + navigation/side-effects)
```

**Hard rules:**

| Layer | Allowed imports |
|-------|----------------|
| Repository | `Database` (Drift), `ApiService` (Dio), domain models |
| Notifier | Repository, other Notifiers, domain models, `rxdart` |
| Service (concrete) | Notifier, domain models, module DTOs, module service interface |
| ViewModel | Module service interface (`IXxxService`), module DTOs, `flutter_riverpod` |
| Screen | ViewModel provider, module view models, Flutter widgets |
| Coordinator | `BuildContext`, `go_router` — nothing domain-related |

Domain layer (Repository + Notifier) must be **pure Dart** — no `flutter/*` or `flutter_riverpod` imports allowed.

---

## 2. Notifier pattern (RxDart BehaviorSubject + typed events)

Reference: `lib/BreathModule/Core/BreathSessionNotifier.dart`

### 2a. Event file — `lib/XxxModule/Core/Models/XxxNotifierEvent.dart`

```dart
import 'package:mind/XxxModule/Models/XxxItem.dart';

// Use a sealed class — exhaustive switch in listeners.
sealed class XxxNotifierEvent {}

class XxxPageLoaded extends XxxNotifierEvent {
  final int page;
  final List<XxxItem> items;
  final bool hasMore;
  XxxPageLoaded({required this.page, required this.items, required this.hasMore});
}

class XxxItemCreated extends XxxNotifierEvent {
  final XxxItem item;
  XxxItemCreated(this.item);
}

class XxxItemUpdated extends XxxNotifierEvent {
  final XxxItem item;
  XxxItemUpdated(this.item);
}

class XxxItemDeleted extends XxxNotifierEvent {
  final String id;
  XxxItemDeleted(this.id);
}

class XxxItemsInvalidated extends XxxNotifierEvent {}
```

### 2b. State + Notifier — `lib/XxxModule/Core/XxxNotifier.dart`

```dart
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:mind/XxxModule/Core/XxxRepository.dart';
import 'package:mind/XxxModule/Models/XxxItem.dart';
import 'package:mind/XxxModule/Core/Models/XxxNotifierEvent.dart';
import 'package:mind/User/UserNotifier.dart';

class XxxState {
  final Map<String, XxxItem> byId;
  final List<String> order;
  final XxxNotifierEvent? lastEvent;

  const XxxState({
    required this.byId,
    required this.order,
    required this.lastEvent,
  });

  List<XxxItem> get orderedItems => order.map((id) => byId[id]!).toList();
}

class XxxNotifier {
  final XxxRepository repository;
  final UserNotifier userNotifier;

  final BehaviorSubject<XxxState> _subject = BehaviorSubject.seeded(
    const XxxState(byId: {}, order: [], lastEvent: null),
  );

  bool _isLoading = false;
  StreamSubscription<String>? _userSubscription;

  XxxNotifier({required this.repository, required this.userNotifier}) {
    _userSubscription = userNotifier.stream
        .map((s) => s.user.id)
        .distinct()
        .skip(1)
        .listen(_onUserIdChanged);
  }

  void _onUserIdChanged(String _) async {
    await repository.deleteAll();
    _subject.add(XxxState(byId: {}, order: [], lastEvent: XxxItemsInvalidated()));
  }

  Stream<XxxState> get stream => _subject.stream;
  XxxState get currentState => _subject.value;

  Future<void> load(int page, int pageSize) async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final items = await repository.fetch(page, pageSize);
      final hasMore = items.length >= pageSize;
      final state = _subject.value;

      final Map<String, XxxItem> updatedById;
      final List<String> updatedOrder;
      final List<XxxItem> newItems;

      if (page == 0) {
        updatedById = {for (final i in items) i.id: i};
        updatedOrder = items.map((i) => i.id).toList();
        newItems = items;
      } else {
        updatedById = Map.from(state.byId);
        updatedOrder = List.from(state.order);
        newItems = [];
        for (final item in items) {
          if (!state.byId.containsKey(item.id)) {
            updatedById[item.id] = item;
            updatedOrder.add(item.id);
            newItems.add(item);
          }
        }
      }

      _subject.add(XxxState(
        byId: updatedById,
        order: updatedOrder,
        lastEvent: XxxPageLoaded(page: page, items: newItems, hasMore: hasMore),
      ));
    } finally {
      _isLoading = false;
    }
  }

  Future<void> create(XxxItem item) async {
    await repository.save(item);
    final state = _subject.value;
    final updatedById = Map<String, XxxItem>.from(state.byId)..[item.id] = item;
    final updatedOrder = [item.id, ...state.order];
    _subject.add(XxxState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: XxxItemCreated(item),
    ));
  }

  Future<void> delete(String id) async {
    await repository.delete(id);
    final state = _subject.value;
    final updatedById = Map<String, XxxItem>.from(state.byId)..remove(id);
    final updatedOrder = List<String>.from(state.order)..remove(id);
    _subject.add(XxxState(
      byId: updatedById,
      order: updatedOrder,
      lastEvent: XxxItemDeleted(id),
    ));
  }

  void dispose() {
    _userSubscription?.cancel();
    _subject.close();
  }
}
```

Key rules:
- `BehaviorSubject.seeded(...)` — always has a current value.
- Every mutation sets `lastEvent` to a typed event. Listeners switch on `lastEvent`, not on state diffs.
- No Flutter or Riverpod imports anywhere in this file.

---

## 3. Repository pattern

Reference: `lib/BreathModule/Core/BreathSessionRepository.dart`

```dart
import 'package:mind/Core/Api/ApiService.dart';
import 'package:mind/Core/Database/Database.dart';
import 'package:mind/XxxModule/Models/XxxItem.dart';

class XxxRepository {
  final Database _db;
  final ApiService _api;

  XxxRepository({required Database db, required ApiService api})
      : _db = db,
        _api = api;

  Future<List<XxxItem>> fetch(int page, int pageSize) async {
    final cached = await _db.xxxDao.getAll();
    if (cached.isNotEmpty) return cached;
    final remote = await _api.fetchXxxItems(page, pageSize);
    await _db.xxxDao.saveAll(remote);
    return remote;
  }

  Future<void> save(XxxItem item) async {
    await _api.saveXxxItem(item);
    await _db.xxxDao.save(item);
  }

  Future<void> delete(String id) async {
    await _api.deleteXxxItem(id);
    await _db.xxxDao.delete(id);
  }

  Future<void> deleteAll() async {
    await _db.xxxDao.deleteAll();
  }
}
```

---

## 4. Service interface at the module boundary

Reference: `lib/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart`

The service **interface** lives inside the presentation module, not in the domain. This means the module declares what it needs; the concrete implementation is outside the module boundary.

### 4a. Interface + module-local events — `lib/XxxModule/Presentation/XxxList/IXxxListService.dart`

```dart
import 'package:mind/XxxModule/Presentation/XxxList/Models/XxxListItemDTO.dart';

/// Declared inside the module — the ViewModel depends only on this interface.
/// The concrete implementation lives at lib/XxxModule/XxxListService.dart.
abstract class IXxxListService {
  /// Stream of all change events. May replay cached data on subscribe.
  Stream<XxxListEvent> observeChanges();

  Future<void> fetchPage(int page, int pageSize);
  Future<void> refresh(int pageSize);
}

// Module-local event hierarchy (DTOs, not domain models)
sealed class XxxListEvent {}

class XxxPageLoadedEvent extends XxxListEvent {
  final int page;
  final List<XxxListItemDTO> items;
  final bool hasMore;
  XxxPageLoadedEvent({required this.page, required this.items, required this.hasMore});
}

class XxxItemsRefreshedEvent extends XxxListEvent {
  final List<XxxListItemDTO> items;
  final bool hasMore;
  XxxItemsRefreshedEvent({required this.items, required this.hasMore});
}

class XxxItemCreatedEvent extends XxxListEvent {
  final XxxListItemDTO item;
  XxxItemCreatedEvent(this.item);
}

class XxxItemUpdatedEvent extends XxxListEvent {
  final XxxListItemDTO item;
  XxxItemUpdatedEvent(this.item);
}

class XxxItemDeletedEvent extends XxxListEvent {
  final String id;
  XxxItemDeletedEvent(this.id);
}

class XxxItemsInvalidatedEvent extends XxxListEvent {}
```

---

## 5. Service concrete implementation (domain → DTO bridge)

Reference: `lib/BreathModule/BreathSessionListService.dart`

The concrete service lives **outside** the presentation module at `lib/XxxModule/XxxListService.dart`. It:
1. Subscribes to the Notifier stream.
2. Translates domain events (typed `XxxNotifierEvent`) into module-local events (typed `XxxListEvent`).
3. Converts domain models (`XxxItem`) into module-local DTOs (`XxxListItemDTO`).

```dart
import 'dart:async';
import 'package:mind/XxxModule/Core/XxxNotifier.dart';
import 'package:mind/XxxModule/Core/Models/XxxNotifierEvent.dart';
import 'package:mind/XxxModule/Models/XxxItem.dart';
import 'package:mind/XxxModule/Presentation/XxxList/IXxxListService.dart';
import 'package:mind/XxxModule/Presentation/XxxList/Models/XxxListItemDTO.dart';

class XxxListService implements IXxxListService {
  final XxxNotifier notifier;

  final StreamController<XxxListEvent> _controller =
      StreamController<XxxListEvent>.broadcast();

  late final StreamSubscription _subscription;

  XxxListService({required this.notifier}) {
    _subscription = notifier.stream.listen(_onNotifierState);
  }

  @override
  Stream<XxxListEvent> observeChanges() => _controller.stream;

  @override
  Future<void> fetchPage(int page, int pageSize) =>
      notifier.load(page, pageSize);

  @override
  Future<void> refresh(int pageSize) => notifier.refresh(pageSize);

  // Translate notifier state → module-local events with DTO conversion.
  void _onNotifierState(XxxState state) {
    final event = state.lastEvent;
    if (event == null) return;

    switch (event) {
      case XxxPageLoaded e:
        _controller.add(XxxPageLoadedEvent(
          page: e.page,
          items: e.items.map(_toDTO).toList(),
          hasMore: e.hasMore,
        ));

      case XxxItemCreated e:
        _controller.add(XxxItemCreatedEvent(_toDTO(e.item)));

      case XxxItemUpdated e:
        _controller.add(XxxItemUpdatedEvent(_toDTO(e.item)));

      case XxxItemDeleted e:
        _controller.add(XxxItemDeletedEvent(e.id));

      case XxxItemsInvalidated _:
        _controller.add(XxxItemsInvalidatedEvent());
    }
  }

  // All domain-model-to-DTO conversion lives here — never in the ViewModel.
  XxxListItemDTO _toDTO(XxxItem item) {
    return XxxListItemDTO(
      id: item.id,
      title: item.name,
      // ... map other fields
    );
  }

  void dispose() {
    _subscription.cancel();
    _controller.close();
  }
}
```

---

## 6. Module-local DTOs

Reference: `lib/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart`

DTOs live inside the module. They contain only primitive types and module-local enums — never domain models.

```dart
// lib/XxxModule/Presentation/XxxList/Models/XxxListItemDTO.dart

class XxxListItemDTO {
  final String id;
  final String title;
  final String subtitle;
  // Primitive fields only. No domain model references.

  const XxxListItemDTO({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}
```

---

## 7. ViewModel (Riverpod StateNotifier)

Reference: `lib/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart`

The ViewModel is the **module boundary**. It depends only on:
- `IXxxListService` (the module-local interface)
- `IXxxListCoordinator` (the module-local coordinator interface)
- Module-local DTOs and state types

```dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/XxxModule/Presentation/XxxList/IXxxListService.dart';
import 'package:mind/XxxModule/Presentation/XxxList/IXxxListCoordinator.dart';
import 'package:mind/XxxModule/Presentation/XxxList/Models/XxxListItemDTO.dart';
import 'package:mind/XxxModule/Presentation/XxxList/Models/XxxListState.dart';

// Provider throws by default — must be overridden in the router.
final xxxListViewModelProvider =
    StateNotifierProvider<XxxListViewModel, XxxListState>((ref) {
  throw UnimplementedError(
    'XxxListViewModel must be provided via override in the router',
  );
});

class XxxListViewModel extends StateNotifier<XxxListState> {
  final IXxxListService service;
  final IXxxListCoordinator coordinator;
  final int pageSize;

  StreamSubscription<XxxListEvent>? _subscription;

  XxxListViewModel({
    required this.service,
    required this.coordinator,
    this.pageSize = 50,
  }) : super(XxxListState.initialLoading()) {
    _subscription = service.observeChanges().listen(_onEvent);
    _loadFirst();
  }

  void _onEvent(XxxListEvent event) {
    switch (event) {
      case XxxPageLoadedEvent e:
        _handlePageLoaded(e);
      case XxxItemCreatedEvent e:
        _handleCreated(e);
      case XxxItemDeletedEvent e:
        _handleDeleted(e);
      case XxxItemsInvalidatedEvent _:
        _reset();
    }
  }

  void _handlePageLoaded(XxxPageLoadedEvent e) {
    // Transform DTOs into view models — string formatting, display logic.
    final cells = e.items.map(_dtoToCell).toList();
    state = state.copyWith(items: cells, hasMore: e.hasMore);
  }

  void onItemTap(String id) => coordinator.openItem(id);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

Key rules:
- The provider must `throw UnimplementedError` — it is always overridden in `router.dart`.
- Domain models must never appear in this file.
- String formatting and display logic lives here (e.g., `_formatDuration`, `_formatPatterns`).
- Navigation calls go through `coordinator`, not directly via `BuildContext` or GoRouter.

---

## 8. Coordinator pattern

Reference: `lib/BreathModule/Presentation/BreathSessionsList/IBreathSessionListCoordinator.dart` and `lib/BreathModule/BreathSessionListCoordinator.dart`

### 8a. Interface — inside the module

```dart
// lib/XxxModule/Presentation/XxxList/IXxxListCoordinator.dart

abstract class IXxxListCoordinator {
  void openItem(String id);
  void openConstructor();
}
```

### 8b. Concrete coordinator — outside the module

```dart
// lib/XxxModule/XxxListCoordinator.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind/XxxModule/Presentation/XxxDetail/XxxDetailScreen.dart';
import 'package:mind/XxxModule/Presentation/XxxList/IXxxListCoordinator.dart';

class XxxListCoordinator implements IXxxListCoordinator {
  final BuildContext context;

  XxxListCoordinator(this.context);

  @override
  void openItem(String id) => context.push(XxxDetailScreen.path, extra: id);

  @override
  void openConstructor() => context.push('/xxx/new');
}
```

Navigation and side-effects go in the Coordinator, **not** in the ViewModel or Screen. The Screen calls `viewModel.onItemTap(id)`; the ViewModel calls `coordinator.openItem(id)`.

---

## 9. Screen

Reference: `lib/BreathModule/Presentation/BreathSessionsList/BreathSessionListScreen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind/XxxModule/Presentation/XxxList/XxxListViewModel.dart';

class XxxListScreen extends ConsumerStatefulWidget {
  const XxxListScreen({super.key});

  static String name = 'xxx_list';
  static String path = '/$name';

  @override
  ConsumerState<XxxListScreen> createState() => _XxxListScreenState();
}

class _XxxListScreenState extends ConsumerState<XxxListScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(xxxListViewModelProvider);
    // Render from state. All user actions go through the ViewModel:
    // ref.read(xxxListViewModelProvider.notifier).onItemTap(id);
    return Scaffold(/* ... */);
  }
}
```

The Screen must not access `App.shared`, repositories, notifiers, or perform navigation directly.

---

## 10. Wiring in router.dart

Reference: `lib/router.dart`

The router is where the concrete implementations (Service, Coordinator, ViewModel) are instantiated and wired together via `ProviderScope.overrides`.

```dart
GoRoute(
  path: XxxListScreen.path,
  name: XxxListScreen.name,
  builder: (context, state) {
    final app = App.shared;

    // 1. Instantiate concrete Service (bridges domain → module)
    final service = XxxListService(
      notifier: app.xxxNotifier,
      userNotifier: app.userNotifier,
    );

    // 2. Instantiate concrete Coordinator (holds BuildContext)
    final coordinator = XxxListCoordinator(context);

    // 3. Override the provider with a concrete ViewModel
    return ProviderScope(
      overrides: [
        xxxListViewModelProvider.overrideWith(
          (ref) => XxxListViewModel(service: service, coordinator: coordinator),
        ),
      ],
      child: const XxxListScreen(),
    );
  },
),
```

---

## 11. DI via App.shared

Reference: `lib/Core/App.dart`

When adding a new domain Notifier or Repository, register it in `App`:

```dart
class App {
  static late App shared;

  // Add fields for new repositories and notifiers:
  final XxxRepository xxxRepository;
  final XxxNotifier xxxNotifier;

  // ...
}
```

Initialization order in `App.initialize()`:

```
1. Firebase.initializeApp()
2. Database()          — Drift
3. AuthInterceptor()
4. ApiService()        — Dio
5. XxxRepository(db, api)
6. XxxNotifier(repository, userNotifier)
7. runApp(ProviderScope(...))
```

Never reorder these — each step depends on the previous one.

---

## 12. Module directory structure

When adding a new module `FooModule`, follow the BreathModule layout:

```
lib/FooModule/
├── Core/
│   ├── Models/
│   │   └── FooNotifierEvent.dart     # sealed class hierarchy
│   ├── FooNotifier.dart              # RxDart BehaviorSubject, pure Dart
│   └── FooRepository.dart            # Drift + Dio, pure Dart
├── Models/                           # domain models (pure Dart)
│   └── FooItem.dart
├── Presentation/
│   └── FooList/
│       ├── Models/
│       │   ├── FooListItemDTO.dart   # module-local DTO
│       │   ├── FooListItem.dart      # UI list item sealed class
│       │   └── FooListState.dart     # ViewModel state
│       ├── Views/                    # sub-widgets
│       ├── IFooListService.dart      # service interface + event types (module boundary)
│       ├── IFooListCoordinator.dart  # coordinator interface (module boundary)
│       ├── FooListViewModel.dart     # Riverpod StateNotifier
│       └── FooListScreen.dart        # ConsumerStatefulWidget
├── FooListService.dart               # concrete service (domain → DTO bridge)
└── FooListCoordinator.dart           # concrete coordinator (holds BuildContext)
```

---

## 13. Checklist for a new module

Use this checklist when adding a new feature module end-to-end:

**Domain layer (pure Dart)**
- [ ] Create `lib/FooModule/Models/FooItem.dart` — domain model
- [ ] Create `lib/FooModule/Core/Models/FooNotifierEvent.dart` — sealed event hierarchy
- [ ] Create `lib/FooModule/Core/FooRepository.dart` — Drift + API calls
- [ ] Create `lib/FooModule/Core/FooNotifier.dart` — BehaviorSubject, emits typed events
- [ ] Verify: no `flutter/*` or `flutter_riverpod` imports in Repository or Notifier

**App.shared wiring**
- [ ] Add `FooRepository` and `FooNotifier` fields to `App`
- [ ] Instantiate them in `App.initialize()` in dependency order
- [ ] Verify initialization order: DB → API → Repository → Notifier

**Module boundary**
- [ ] Create `IFooListService.dart` inside Presentation — interface + sealed event hierarchy using DTOs
- [ ] Create `IFooListCoordinator.dart` inside Presentation — navigation interface
- [ ] Create `FooListItemDTO.dart` — module-local DTO (primitives only)
- [ ] Create `FooListState.dart` — ViewModel state

**Service (bridge)**
- [ ] Create `lib/FooModule/FooListService.dart` — implements `IFooListService`
- [ ] Subscribe to `FooNotifier.stream`, switch on `lastEvent`
- [ ] Map each domain event to the corresponding module event, converting domain models to DTOs
- [ ] Implement `dispose()` — cancel subscription, close stream controller

**Presentation**
- [ ] Create `FooListViewModel.dart` — `StateNotifier<FooListState>`, depends only on `IFooListService` and `IFooListCoordinator`
- [ ] Provider throws `UnimplementedError` by default
- [ ] Create `FooListCoordinator.dart` — implements `IFooListCoordinator`, holds `BuildContext`, uses GoRouter
- [ ] Create `FooListScreen.dart` — `ConsumerStatefulWidget`, reads state from provider, delegates actions to ViewModel

**Router wiring**
- [ ] Add route to `lib/router.dart`
- [ ] Instantiate `FooListService`, `FooListCoordinator`, wrap in `ProviderScope` with `overrideWith`

**Validation**
- [ ] Search for domain model type names in Presentation files — none should appear
- [ ] Search for `App.shared` in Screen files — must not appear
- [ ] Search for `context.push` / `GoRouter` in ViewModel files — must not appear
- [ ] Run `flutter test` and `flutter analyze`
