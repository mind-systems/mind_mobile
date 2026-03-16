import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/Socket/ILiveSocketService.dart';
import 'package:mind/Core/Socket/SocketConnectionState.dart';

class LiveSocketService implements ILiveSocketService {
  final FlutterSecureStorage _storage;

  io.Socket? _liveSocket;
  io.Socket? _telemetrySocket;

  final _connectionState = BehaviorSubject<SocketConnectionState>.seeded(
    SocketConnectionState.disconnected,
  );

  final _sessionStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _telemetryStateController = StreamController<void>.broadcast();
  final _dataAckController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SocketConnectionState> get connectionState => _connectionState.stream;
  @override
  Stream<Map<String, dynamic>> get sessionStateEvents => _sessionStateController.stream;
  Stream<void> get telemetryStateEvents => _telemetryStateController.stream;
  Stream<Map<String, dynamic>> get dataAckEvents => _dataAckController.stream;

  final ValueNotifier<String> lastSentMessage = ValueNotifier('');
  final ValueNotifier<String> lastReceivedMessage = ValueNotifier('');

  bool _isConnecting = false;

  bool get isConnected =>
      (_liveSocket?.connected ?? false) && (_telemetrySocket?.connected ?? false);

  io.Socket? get liveSocket => _liveSocket;
  io.Socket? get telemetrySocket => _telemetrySocket;

  LiveSocketService({required FlutterSecureStorage storage}) : _storage = storage;

  // connect() can be called concurrently from two sources:
  //   - SocketConnectionCoordinator auth listener (on login)
  //   - SocketConnectionCoordinator connectivity listener (on network restore)
  //
  // A connectivity flap (none → wifi) can arrive while the first connect() is
  // suspended at `await _storage.read()`, causing a second concurrent call.
  // _isConnecting guards the synchronous entry point, but it is reset in
  // `finally` before the sockets actually establish — so a second caller
  // that arrives after the await gap would pass the entry check and create
  // duplicate socket pairs, causing the server to evict the first connection.
  //
  // Two-level deduplication:
  //   1. _isConnecting — fast path: rejects callers that arrive before the await.
  //   2. _liveSocket != null check after the await — rejects callers that slipped
  //      through while the first call was suspended, or that arrived after a
  //      disconnect() reset _isConnecting to false mid-flight.
  Future<void> connect() async {
    if (isConnected || _isConnecting) {
      log('[Socket] connect() skipped: isConnected=$isConnected _isConnecting=$_isConnecting', name: 'LiveSocketService');
      return;
    }
    _isConnecting = true;
    log('[Socket] connect() start', name: 'LiveSocketService');

    try {
      final jwt = await _storage.read(key: 'jwt_token');
      if (jwt == null) {
        log('[Socket] connect() aborted: no jwt_token in storage', name: 'LiveSocketService');
        return;
      }

      // Second deduplication check (see comment above): disconnect() resets
      // _isConnecting synchronously, so a concurrent connect() call that
      // arrived after the await gap may have already built the sockets.
      if (_liveSocket != null || _telemetrySocket != null) {
        log('[Socket] connect() aborted: sockets already exist after await', name: 'LiveSocketService');
        return;
      }

      _connectionState.add(SocketConnectionState.connecting);

      final wsUrl = Environment.instance.wsBaseUrl;
      log('[Socket] connecting to $wsUrl', name: 'LiveSocketService');

      _liveSocket = _buildSocket(wsUrl, '/live', jwt);
      _telemetrySocket = _buildSocket(wsUrl, '/telemetry', jwt);

      _liveSocket!.onConnect((_) {
        log('[Socket] /live connected', name: 'LiveSocketService');
        _updateConnectionState();
      });
      _liveSocket!.onDisconnect((_) {
        log('[Socket] /live disconnected', name: 'LiveSocketService');
        _updateConnectionState();
      });
      _liveSocket!.onConnectError((e) {
        log('[Socket] /live connect error: $e', name: 'LiveSocketService');
      });
      _liveSocket!.onError((e) {
        log('[Socket] /live error: $e', name: 'LiveSocketService');
      });
      _liveSocket!.on('disconnect', (reason) {
        log('[Socket] /live disconnect reason: $reason', name: 'LiveSocketService');
      });

      _telemetrySocket!.onConnect((_) {
        log('[Socket] /telemetry connected', name: 'LiveSocketService');
        _updateConnectionState();
      });
      _telemetrySocket!.onDisconnect((_) {
        log('[Socket] /telemetry disconnected', name: 'LiveSocketService');
        _updateConnectionState();
      });
      _telemetrySocket!.onConnectError((e) {
        log('[Socket] /telemetry connect error: $e', name: 'LiveSocketService');
      });
      _telemetrySocket!.onError((e) {
        log('[Socket] /telemetry error: $e', name: 'LiveSocketService');
      });
      _telemetrySocket!.on('disconnect', (reason) {
        log('[Socket] /telemetry disconnect reason: $reason', name: 'LiveSocketService');
      });

      _liveSocket!.on('session:state', (data) {
        if (data is Map<String, dynamic>) {
          log('[Socket] ← session:state: $data', name: 'LiveSocketService');
          _sessionStateController.add(data);
          lastReceivedMessage.value = 'live: session:state → ${data['status']}';
        }
      });

      _telemetrySocket!.onConnect((_) => _telemetryStateController.add(null));

      _telemetrySocket!.on('data:ack', (data) {
        if (data is Map<String, dynamic>) {
          log('[Socket] ← data:ack: $data', name: 'LiveSocketService');
          _dataAckController.add(data);
          lastReceivedMessage.value = 'telemetry: data:ack';
        }
      });

      _liveSocket!.connect();
      _telemetrySocket!.connect();
      log('[Socket] connect() called on both sockets', name: 'LiveSocketService');
    } finally {
      _isConnecting = false;
    }
  }

  @override
  void emitLive(String event, [Map<String, dynamic>? data]) {
    log('[Socket] → live $event: $data', name: 'LiveSocketService');
    _liveSocket?.emit(event, data);
    lastSentMessage.value = 'live: $event';
  }

  void emitTelemetry(String event, [dynamic data]) {
    log('[Socket] → telemetry $event', name: 'LiveSocketService');
    _telemetrySocket?.emit(event, data);
    lastSentMessage.value = 'telemetry: $event';
  }

  void disconnect() {
    log('[Socket] disconnect()', name: 'LiveSocketService');
    // Reset _isConnecting so that a subsequent connect() is not blocked.
    // destroy() (not disconnect()) is used to fully tear down the socket and
    // remove all its internal listeners — this prevents stale onConnect /
    // onDisconnect callbacks from firing after the socket references are nulled,
    // which would cause _updateConnectionState() to read null sockets and
    // incorrectly emit disconnected even for a newly created socket pair.
    _isConnecting = false;
    _liveSocket?.destroy();
    _telemetrySocket?.destroy();
    _liveSocket = null;
    _telemetrySocket = null;
    _connectionState.add(SocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    lastSentMessage.dispose();
    lastReceivedMessage.dispose();
    _connectionState.close();
    _sessionStateController.close();
    _telemetryStateController.close();
    _dataAckController.close();
  }

  void _updateConnectionState() {
    if (isConnected) {
      log('[Socket] state → connected', name: 'LiveSocketService');
      _connectionState.add(SocketConnectionState.connected);
    } else {
      log('[Socket] state → disconnected (live=${_liveSocket?.connected} telemetry=${_telemetrySocket?.connected})', name: 'LiveSocketService');
      _connectionState.add(SocketConnectionState.disconnected);
    }
  }

  io.Socket _buildSocket(String url, String namespace, String jwt) {
    return io.io(
      '$url$namespace',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': jwt})
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(double.infinity)
          .build(),
    );
  }
}
