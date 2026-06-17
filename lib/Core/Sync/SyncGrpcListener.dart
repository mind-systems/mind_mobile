import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:mind/Logger.dart';
import 'package:mind/Core/Api/Models/ChangeEvent.dart';
import 'package:mind/Core/Database/ISyncStateDao.dart';
import 'package:mind/Core/Grpc/generated/sync.pb.dart' as syncProto;
import 'package:mind/Core/Grpc/generated/sync.pbgrpc.dart' show SyncServiceClient;
import 'package:mind/Core/Sync/SyncEngine.dart';
import 'package:mind/User/Models/AuthState.dart';

class SyncGrpcListener {
  final SyncServiceClient syncService;
  final SyncEngine syncEngine;
  final ISyncStateDao syncStateDao;

  late final StreamSubscription<AuthState> _authSubscription;
  StreamSubscription<syncProto.ChangeEvent>? _watchSubscription;
  Timer? _reconnectTimer;
  bool _isAuthenticated = false;

  SyncGrpcListener({
    required this.syncService,
    required this.syncEngine,
    required this.syncStateDao,
    required Stream<AuthState> authStream,
  }) {
    _authSubscription = authStream.listen((state) {
      if (state is AuthenticatedState) {
        _isAuthenticated = true;
        _startWatching();
      } else if (state is GuestState) {
        _isAuthenticated = false;
        _stopWatching();
      }
    });
  }

  Future<void> _startWatching() async {
    await _stopWatching();
    if (!_isAuthenticated) return;
    final lastEventId = await syncStateDao.getLastEventId();
    if (!_isAuthenticated) return;
    final stream = syncService.watchChanges(syncProto.WatchChangesRequest(afterId: Int64(lastEventId)));
    _watchSubscription = stream.listen(
      (syncProto.ChangeEvent envelope) {
        final events = envelope.events.map(_mapEvent).toList();
        if (events.isEmpty) return;
        syncEngine.processEvents(events).catchError((e) {
          logPrint('[SyncGrpcListener] processEvents failed: $e');
        });
      },
      onError: (e) {
        logPrint('[SyncGrpcListener] stream error: $e');
        _scheduleReconnect();
      },
      onDone: () {
        _scheduleReconnect();
      },
    );
  }

  Future<void> _stopWatching() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _watchSubscription?.cancel();
    _watchSubscription = null;
  }

  void _scheduleReconnect() {
    if (!_isAuthenticated) return;
    logPrint('[SyncGrpcListener] stream ended, reconnecting in 3s');
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_isAuthenticated) _startWatching();
    });
  }

  ChangeEvent _mapEvent(syncProto.SyncEventDto dto) {
    return ChangeEvent(
      id: dto.id.toInt(),
      entity: dto.entity,
      refId: dto.refId,
      action: dto.action,
    );
  }

  void dispose() {
    _authSubscription.cancel();
    _reconnectTimer?.cancel();
    _watchSubscription?.cancel();
  }
}
