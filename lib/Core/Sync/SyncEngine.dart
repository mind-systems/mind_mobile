import 'dart:async';
import 'dart:developer';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Api/Models/ChangeEvent.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';
import 'package:mind/Core/Database/ISyncStateDao.dart';
import 'package:mind/User/Models/AuthState.dart';

class SyncEngine {
  final ISyncApi syncApi;
  final ISyncStateDao syncStateDao;
  final IBreathSessionDao breathSessionDao;
  final BreathSessionNotifier breathSessionNotifier;
  late final StreamSubscription<AuthState> _authSubscription;
  Future<void>? _activeSyncOp;

  SyncEngine({required this.syncApi, required this.syncStateDao, required this.breathSessionDao, required this.breathSessionNotifier, required Stream<AuthState> authStream}) {
    _authSubscription = authStream.skip(1).where((s) => s is AuthenticatedState).listen((_) => sync());
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
  }

  Future<void> waitForColdStart(bool isAuthenticated) {
    if (!isAuthenticated) return Future.value();
    return sync().timeout(const Duration(seconds: 5), onTimeout: () {});
  }

  Future<void> sync() async {
    if (_activeSyncOp != null) return;
    try {
      _activeSyncOp = _doSync();
      await _activeSyncOp;
    } finally {
      _activeSyncOp = null;
    }
  }

  Future<void> _doSync() async {
    try {
      final lastEventId = await syncStateDao.getLastEventId();
      final response = await syncApi.fetchChanges(lastEventId);
      if (response.fullResync) {
        if (lastEventId == 0) {
          log('[SyncEngine] server sent fullResync for after=0, skipping to prevent loop', name: 'SyncEngine');
          return;
        }
        await _handleFullResync();
        return;
      }
      if (response.events.isEmpty) return;
      await _processEvents(response.events);
    } catch (e) {
      log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
    }
  }

  Future<void> processEvents(List<ChangeEvent> events) async {
    // Wait for any in-flight sync() to finish before processing socket events,
    // so we don't interleave REST-poll writes with socket-push writes.
    if (_activeSyncOp != null) {
      await _activeSyncOp;
    }
    await _processEvents(events);
  }

  Future<void> _processEvents(List<ChangeEvent> events) async {
    if (events.isEmpty) return;
    events.sort((a, b) => a.id.compareTo(b.id));
    final grouped = <String, List<ChangeEvent>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.entity, () => []).add(event);
    }
    for (final entry in grouped.entries) {
      if (entry.key == 'breath_session') {
        await _handleBreathSessionEvents(entry.value);
      } else {
        log('[SyncEngine] unknown entity: ${entry.key}', name: 'SyncEngine');
      }
    }
    final maxEventId = events.map((e) => e.id).reduce((a, b) => a > b ? a : b);
    final currentId = await syncStateDao.getLastEventId();
    if (maxEventId > currentId) {
      await syncStateDao.setLastEventId(maxEventId);
    }
  }

  Future<void> _handleBreathSessionEvents(List<ChangeEvent> events) async {
    final deleteIds = <String>{};
    final upsertIds = <String>{};
    for (final event in events) {
      if (event.action == 'deleted') {
        deleteIds.add(event.refId);
      } else {
        upsertIds.add(event.refId);
      }
    }
    upsertIds.removeAll(deleteIds);
    if (upsertIds.isNotEmpty) {
      final response = await syncApi.fetchSessionsBatch(upsertIds.toList());
      await breathSessionDao.saveSessions(response.data);
    }
    for (final id in deleteIds) {
      await breathSessionDao.deleteSession(id);
    }
    breathSessionNotifier.invalidate();
  }

  Future<void> _handleFullResync() async {
    await breathSessionDao.deleteAllSessions();
    await syncStateDao.reset();
    breathSessionNotifier.invalidate();
  }
}
