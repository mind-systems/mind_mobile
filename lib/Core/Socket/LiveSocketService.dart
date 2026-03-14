import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rxdart/rxdart.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:mind/Core/Environment.dart';
import 'package:mind/Core/Socket/SocketConnectionState.dart';

class LiveSocketService {
  final FlutterSecureStorage _storage;

  io.Socket? _liveSocket;
  io.Socket? _telemetrySocket;

  final _connectionState = BehaviorSubject<SocketConnectionState>.seeded(
    SocketConnectionState.disconnected,
  );

  final _sessionStateController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<SocketConnectionState> get connectionState => _connectionState.stream;
  Stream<Map<String, dynamic>> get sessionStateEvents => _sessionStateController.stream;

  bool _isConnecting = false;

  bool get isConnected =>
      (_liveSocket?.connected ?? false) && (_telemetrySocket?.connected ?? false);

  io.Socket? get liveSocket => _liveSocket;
  io.Socket? get telemetrySocket => _telemetrySocket;

  LiveSocketService({required FlutterSecureStorage storage}) : _storage = storage;

  Future<void> connect() async {
    if (isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final jwt = await _storage.read(key: 'jwt_token');
      if (jwt == null) return;

      _connectionState.add(SocketConnectionState.connecting);

      final wsUrl = Environment.instance.wsBaseUrl;

      _liveSocket = _buildSocket(wsUrl, '/live', jwt);
      _telemetrySocket = _buildSocket(wsUrl, '/telemetry', jwt);

      _liveSocket!.onConnect((_) => _updateConnectionState());
      _liveSocket!.onDisconnect((_) => _updateConnectionState());
      _telemetrySocket!.onConnect((_) => _updateConnectionState());
      _telemetrySocket!.onDisconnect((_) => _updateConnectionState());

      _liveSocket!.on('session:state', (data) {
        if (data is Map<String, dynamic>) _sessionStateController.add(data);
      });

      _liveSocket!.connect();
      _telemetrySocket!.connect();
    } finally {
      _isConnecting = false;
    }
  }

  void emitLive(String event, [dynamic data]) {
    _liveSocket?.emit(event, data);
  }

  void emitTelemetry(String event, [dynamic data]) {
    _telemetrySocket?.emit(event, data);
  }

  void disconnect() {
    _isConnecting = false;
    _liveSocket?.disconnect();
    _telemetrySocket?.disconnect();
    _liveSocket = null;
    _telemetrySocket = null;
    _connectionState.add(SocketConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _connectionState.close();
    _sessionStateController.close();
  }

  void _updateConnectionState() {
    if (isConnected) {
      _connectionState.add(SocketConnectionState.connected);
    } else {
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
