import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breath_module/breath_module.dart' show IBreathSessionListCoordinator, IBreathSessionListService, BreathSessionListItemDTO, BreathSessionListState, BreathSessionListViewModel, breathSessionListViewModelProvider, BreathSessionListEvent, SessionOwnership, ListSection, ListUpdatedEvent, SectionHeaderType, SectionHeaderModel, BreathSessionListCellModel;

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeCoordinator implements IBreathSessionListCoordinator {
  @override
  void openSession(String sessionId) {}

  @override
  void openConstructor() {}
}

class _FakeService implements IBreathSessionListService {
  final _controller = StreamController<BreathSessionListEvent>.broadcast();
  final Completer<void> _loadCompleter = Completer();

  @override
  Stream<BreathSessionListEvent> observeChanges() => _controller.stream;

  @override
  Future<void> loadNext(int pageSize) => _loadCompleter.future;

  @override
  Future<void> refresh(int pageSize) async {}

  @override
  List<BreathSessionListItemDTO> currentItems() => const [];

  void emit(BreathSessionListEvent event) => _controller.add(event);

  void completeLoad() {
    if (!_loadCompleter.isCompleted) _loadCompleter.complete();
  }

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathSessionListItemDTO _makeDTO({
  required String id,
  required ListSection section,
  SessionOwnership ownership = SessionOwnership.mine,
  bool isStarred = false,
}) {
  return BreathSessionListItemDTO(
    id: id,
    description: 'Session $id',
    patterns: const [],
    totalDurationSeconds: 60,
    complexity: 0,
    ownership: ownership,
    isStarred: isStarred,
    section: section,
  );
}

List<SectionHeaderType> _extractHeaders(BreathSessionListState state) {
  return state.items
      .whereType<SectionHeaderModel>()
      .map((h) => h.type)
      .toList();
}

List<String> _extractCellIds(BreathSessionListState state) {
  return state.items
      .whereType<BreathSessionListCellModel>()
      .map((c) => c.id)
      .toList();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _FakeService service;
  late ProviderContainer container;
  late BreathSessionListViewModel vm;

  setUp(() {
    service = _FakeService();
    container = ProviderContainer(
      overrides: [
        breathSessionListViewModelProvider.overrideWith(
          () => BreathSessionListViewModel(
            service: service,
            coordinator: _FakeCoordinator(),
          ),
        ),
      ],
    );
    vm = container.read(breathSessionListViewModelProvider.notifier);
    service.completeLoad();
  });

  tearDown(() {
    container.dispose();
    service.dispose();
  });

  group('_buildItemsWithSections — server sections', () {
    test('mine-only → only mySessions header', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: '1', section: ListSection.mine),
          _makeDTO(id: '2', section: ListSection.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [SectionHeaderType.mySessions]);
      expect(_extractCellIds(vm.state), ['1', '2']);
    });

    test('starred section appears first before mine and shared', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 's1', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 'm1', section: ListSection.mine),
          _makeDTO(id: 'u1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.starredSessions,
        SectionHeaderType.mySessions,
        SectionHeaderType.sharedSessions,
      ]);
      expect(_extractCellIds(vm.state), ['s1', 'm1', 'u1']);
    });

    test('no starred section → starredSessions header omitted', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'm1', section: ListSection.mine),
          _makeDTO(id: 'u1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.mySessions,
        SectionHeaderType.sharedSessions,
      ]);
    });

    test('no mine section → mySessions header omitted', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 's1', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 'u1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.starredSessions,
        SectionHeaderType.sharedSessions,
      ]);
    });

    test('no shared section → sharedSessions header omitted', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'm1', section: ListSection.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [SectionHeaderType.mySessions]);
    });

    test('all three groups present → STARRED first, then MINE, then SHARED', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 's1', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 's2', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 'm1', section: ListSection.mine),
          _makeDTO(id: 'm2', section: ListSection.mine),
          _makeDTO(id: 'u1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final items = vm.state.items;
      expect(items[0], isA<SectionHeaderModel>());
      expect((items[0] as SectionHeaderModel).type, SectionHeaderType.starredSessions);
      expect((items[1] as BreathSessionListCellModel).id, 's1');
      expect((items[2] as BreathSessionListCellModel).id, 's2');

      expect((items[3] as SectionHeaderModel).type, SectionHeaderType.mySessions);
      expect((items[4] as BreathSessionListCellModel).id, 'm1');
      expect((items[5] as BreathSessionListCellModel).id, 'm2');

      expect((items[6] as SectionHeaderModel).type, SectionHeaderType.sharedSessions);
      expect((items[7] as BreathSessionListCellModel).id, 'u1');
    });

    test('shared-only → no starred or mine headers', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'u1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [SectionHeaderType.sharedSessions]);
    });
  });

  group('duplication — same id in multiple sections', () {
    test('session appears under both STARRED and MINE (duplicate ids allowed)', () async {
      // The server can return the same session id in both STARRED and MINE sections.
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'own1', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 'own1', section: ListSection.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids.where((id) => id == 'own1').length, 2,
          reason: 'own1 should appear twice (once in STARRED, once in MINE)');
      expect(_extractHeaders(vm.state), [
        SectionHeaderType.starredSessions,
        SectionHeaderType.mySessions,
      ]);
    });

    test('session appears under both STARRED and SHARED', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'shared1', section: ListSection.starred, ownership: SessionOwnership.shared, isStarred: true),
          _makeDTO(id: 'shared1', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids.where((id) => id == 'shared1').length, 2,
          reason: 'shared1 should appear twice (once in STARRED, once in SHARED)');
    });
  });

  group('within-section ordering', () {
    test('starred section preserves server-provided order', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 's-new', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 's-old', section: ListSection.starred, isStarred: true),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids, ['s-new', 's-old']);
    });

    test('mine section preserves server-provided order', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'm-new', section: ListSection.mine),
          _makeDTO(id: 'm-old', section: ListSection.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids, ['m-new', 'm-old']);
    });

    test('shared section preserves server-provided order', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'u-new', section: ListSection.shared, ownership: SessionOwnership.shared),
          _makeDTO(id: 'u-old', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids, ['u-new', 'u-old']);
    });

    test('mixed sections each preserve their own server-provided order', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 's-new', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 's-old', section: ListSection.starred, isStarred: true),
          _makeDTO(id: 'm-new', section: ListSection.mine),
          _makeDTO(id: 'm-old', section: ListSection.mine),
          _makeDTO(id: 'u-new', section: ListSection.shared, ownership: SessionOwnership.shared),
          _makeDTO(id: 'u-old', section: ListSection.shared, ownership: SessionOwnership.shared),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final ids = _extractCellIds(vm.state);
      expect(ids, ['s-new', 's-old', 'm-new', 'm-old', 'u-new', 'u-old']);
    });
  });

  group('full list replacement (no append logic in ViewModel)', () {
    test('second ListUpdatedEvent replaces first completely', () async {
      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'a', section: ListSection.mine),
          _makeDTO(id: 'b', section: ListSection.mine),
        ],
        hasMore: true,
      ));
      await Future.microtask(() {});

      service.emit(ListUpdatedEvent(
        items: [
          _makeDTO(id: 'a', section: ListSection.mine),
          _makeDTO(id: 'b', section: ListSection.mine),
          _makeDTO(id: 'c', section: ListSection.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractCellIds(vm.state), ['a', 'b', 'c']);
      expect(vm.state.hasMore, isFalse);
    });
  });
}
