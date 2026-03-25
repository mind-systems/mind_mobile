import 'dart:async';
import 'dart:developer';

import 'package:grpc/grpc.dart';
import 'package:mind/Core/Grpc/generated/auth.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/device.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/live.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/stats.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/sync.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/telemetry.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/users.pbgrpc.dart';

class GrpcClient {
  final ClientChannel _channel;
  StreamSubscription<void>? _detachSubscription;

  GrpcClient({required String host, required int port, required bool isSecure, Stream<void>? detachStream})
      : _channel = ClientChannel(host, port: port, options: ChannelOptions(credentials: isSecure ? const ChannelCredentials.secure() : const ChannelCredentials.insecure())) {
    if (detachStream != null) {
      _detachSubscription = detachStream.listen((_) {
        log('[GrpcClient] app detached — shutting down channel', name: 'GrpcClient');
        shutdown();
      });
    }
  }

  late final authService = AuthServiceClient(_channel);
  late final breathSessionService = BreathSessionServiceClient(_channel);
  late final deviceService = DeviceServiceClient(_channel);
  late final liveService = LiveServiceClient(_channel);
  late final statsService = StatsServiceClient(_channel);
  late final syncService = SyncServiceClient(_channel);
  late final telemetryService = TelemetryServiceClient(_channel);
  late final userService = UserServiceClient(_channel);

  Future<void> shutdown() async {
    _detachSubscription?.cancel();
    await _channel.shutdown();
  }
}
