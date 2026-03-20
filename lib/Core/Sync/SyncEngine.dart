import 'dart:developer';

import 'package:mind/BreathModule/Core/BreathSessionNotifier.dart';
import 'package:mind/Core/Api/ISyncApi.dart';
import 'package:mind/Core/Api/Models/ChangeEvent.dart';
import 'package:mind/Core/Database/IBreathSessionDao.dart';
import 'package:mind/Core/Database/ISyncStateDao.dart';

class SyncEngine {
  final ISyncApi syncApi;
  final ISyncStateDao syncStateDao;
  final IBreathSessionDao breathSessionDao;
  final BreathSessionNotifier breathSessionNotifier;

  bool _isSyncing = false;

  SyncEngine({required this.syncApi, required this.syncStateDao, required this.breathSessionDao, required this.breathSessionNotifier});

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final lastEventId = await syncStateDao.getLastEventId();
      final response = await syncApi.fetchChanges(lastEventId);
      if (response.fullResync) {
        await _handleFullResync();
        return;
      }
      if (response.events.isEmpty) return;
      await processEvents(response.events);
    } catch (e) {
      log('[SyncEngine] sync failed: $e', name: 'SyncEngine');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> processEvents(List<ChangeEvent> events) async {
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
