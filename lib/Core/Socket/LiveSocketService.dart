import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:mind/Core/Environment.dart';

class LiveSocketService {
  final FlutterSecureStorage _storage;

  io.Socket? _liveSocket;
  io.Socket? _telemetrySocket;

  bool get isConnected =>
      (_liveSocket?.connected ?? false) && (_telemetrySocket?.connected ?? false);

  io.Socket? get liveSocket => _liveSocket;
  io.Socket? get telemetrySocket => _telemetrySocket;

  LiveSocketService({required FlutterSecureStorage storage}) : _storage = storage;

  Future<void> connect() async {
    if (isConnected) return;

    final jwt = await _storage.read(key: 'jwt_token');
    if (jwt == null) return;

    final wsUrl = Environment.instance.wsBaseUrl;

    _liveSocket = _buildSocket(wsUrl, '/live', jwt);
    _telemetrySocket = _buildSocket(wsUrl, '/telemetry', jwt);

    _liveSocket!.connect();
    _telemetrySocket!.connect();
  }

  void emitLive(String event, [dynamic data]) {
    _liveSocket?.emit(event, data);
  }

  void emitTelemetry(String event, [dynamic data]) {
    _telemetrySocket?.emit(event, data);
  }

  void disconnect() {
    _liveSocket?.disconnect();
    _telemetrySocket?.disconnect();
    _liveSocket = null;
    _telemetrySocket = null;
  }

  io.Socket _buildSocket(String url, String namespace, String jwt) {
    return io.io(
      '$url$namespace',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': jwt})
          .build(),
    );
  }

}
