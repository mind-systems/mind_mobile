import 'dart:async';
import 'dart:developer';

import 'package:mind/Core/Api/Models/ChangeEvent.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/Core/Sync/SyncEngine.dart';

class SyncSocketListener {
  final ILiveSocketService liveSocketService;
  final SyncEngine syncEngine;

  late final StreamSubscription<Map<String, dynamic>> _subscription;

  SyncSocketListener({required this.liveSocketService, required this.syncEngine}) {
    _subscription = liveSocketService.syncChangedEvents.listen(_onSyncChanged);
  }

  void _onSyncChanged(Map<String, dynamic> payload) {
    final rawEvents = payload['events'];
    if (rawEvents is! List) return;
    final events = rawEvents
        .whereType<Map<String, dynamic>>()
        .map(ChangeEvent.fromJson)
        .toList();
    syncEngine.processEvents(events).catchError((e) {
      log('[SyncSocketListener] processEvents failed: $e', name: 'SyncSocketListener');
    });
  }

  void dispose() {
    _subscription.cancel();
  }
}
