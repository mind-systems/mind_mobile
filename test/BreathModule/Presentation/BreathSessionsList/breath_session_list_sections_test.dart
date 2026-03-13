import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListCoordinator.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/IBreathSessionListService.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItem.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListItemDTO.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/Models/BreathSessionListState.dart';
import 'package:mind/BreathModule/Presentation/BreathSessionsList/BreathSessionListViewModel.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeCoordinator implements IBreathSessionListCoordinator {
  @override
  void openSession(String sessionId) {}
}

class _FakeService implements IBreathSessionListService {
  final _controller = StreamController<BreathSessionListEvent>.broadcast();
  final Completer<void> _fetchCompleter = Completer();

  @override
  Stream<BreathSessionListEvent> observeChanges() => _controller.stream;

  @override
  Future<void> fetchPage(int page, int pageSize) => _fetchCompleter.future;

  @override
  Future<void> refresh(int pageSize) async {}

  void emit(BreathSessionListEvent event) => _controller.add(event);

  void completeFetch() {
    if (!_fetchCompleter.isCompleted) _fetchCompleter.complete();
  }

  void dispose() => _controller.close();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

BreathSessionListItemDTO _makeDTO({
  required String id,
  required SessionOwnership ownership,
  bool isStarred = false,
}) {
  return BreathSessionListItemDTO(
    id: id,
    description: 'Session $id',
    patterns: const [],
    totalDurationSeconds: 60,
    ownership: ownership,
    isStarred: isStarred,
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
  late BreathSessionListViewModel vm;

  setUp(() {
    service = _FakeService();
    vm = BreathSessionListViewModel(
      service: service,
      coordinator: _FakeCoordinator(),
    );
    service.completeFetch();
  });

  tearDown(() {
    vm.dispose();
    service.dispose();
  });

  group('_buildItemsWithSections', () {
    test('mine-only → only mySessions header', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: '1', ownership: SessionOwnership.mine),
          _makeDTO(id: '2', ownership: SessionOwnership.mine),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [SectionHeaderType.mySessions]);
      expect(_extractCellIds(vm.state), ['1', '2']);
    });

    test('starred-others present → starredSessions header appears between my and shared', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: 'm1', ownership: SessionOwnership.mine),
          _makeDTO(id: 's1', ownership: SessionOwnership.shared, isStarred: true),
          _makeDTO(id: 'u1', ownership: SessionOwnership.shared, isStarred: false),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.mySessions,
        SectionHeaderType.starredSessions,
        SectionHeaderType.sharedSessions,
      ]);
      expect(_extractCellIds(vm.state), ['m1', 's1', 'u1']);
    });

    test('no starred-others → starredSessions header omitted', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: 'm1', ownership: SessionOwnership.mine),
          _makeDTO(id: 'u1', ownership: SessionOwnership.shared, isStarred: false),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.mySessions,
        SectionHeaderType.sharedSessions,
      ]);
    });

    test('no unstarred-shared → sharedSessions header omitted', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: 'm1', ownership: SessionOwnership.mine),
          _makeDTO(id: 's1', ownership: SessionOwnership.shared, isStarred: true),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [
        SectionHeaderType.mySessions,
        SectionHeaderType.starredSessions,
      ]);
    });

    test('all three groups present → correct ordering', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: 'm1', ownership: SessionOwnership.mine),
          _makeDTO(id: 'm2', ownership: SessionOwnership.mine),
          _makeDTO(id: 's1', ownership: SessionOwnership.shared, isStarred: true),
          _makeDTO(id: 's2', ownership: SessionOwnership.shared, isStarred: true),
          _makeDTO(id: 'u1', ownership: SessionOwnership.shared, isStarred: false),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      final items = vm.state.items;
      expect(items[0], isA<SectionHeaderModel>());
      expect((items[0] as SectionHeaderModel).type, SectionHeaderType.mySessions);
      expect((items[1] as BreathSessionListCellModel).id, 'm1');
      expect((items[2] as BreathSessionListCellModel).id, 'm2');

      expect((items[3] as SectionHeaderModel).type, SectionHeaderType.starredSessions);
      expect((items[4] as BreathSessionListCellModel).id, 's1');
      expect((items[5] as BreathSessionListCellModel).id, 's2');

      expect((items[6] as SectionHeaderModel).type, SectionHeaderType.sharedSessions);
      expect((items[7] as BreathSessionListCellModel).id, 'u1');
    });

    test('shared-only → no mySessions header', () async {
      service.emit(PageLoadedEvent(
        page: 0,
        items: [
          _makeDTO(id: 'u1', ownership: SessionOwnership.shared, isStarred: false),
        ],
        hasMore: false,
      ));
      await Future.microtask(() {});

      expect(_extractHeaders(vm.state), [SectionHeaderType.sharedSessions]);
    });
  });
}
