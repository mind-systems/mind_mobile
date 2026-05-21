import 'dart:async';
import 'dart:developer';

import 'package:grpc/grpc.dart';
import 'package:mind/Core/Grpc/generated/auth.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/bci_devices.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/breath_sessions.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/device.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/module_instruction_stream.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/module_state.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/stats.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/sync.pbgrpc.dart';
import 'package:mind/Core/Grpc/generated/users.pbgrpc.dart';

class GrpcClient {
  final ClientChannel _channel;
  final List<ClientInterceptor> _interceptors;
  StreamSubscription<void>? _detachSubscription;

  GrpcClient({required String host, required int port, required bool isSecure, Stream<void>? detachStream, List<ClientInterceptor> interceptors = const []})
      : _channel = ClientChannel(host, port: port, options: ChannelOptions(credentials: isSecure ? const ChannelCredentials.secure() : const ChannelCredentials.insecure())),
        _interceptors = interceptors {
    if (detachStream != null) {
      _detachSubscription = detachStream.listen((_) {
        log('[GrpcClient] app detached — shutting down channel', name: 'GrpcClient');
        shutdown();
      });
    }
  }

  late final authService = AuthServiceClient(_channel, interceptors: _interceptors);
  late final bciDevicesService = BciDevicesServiceClient(_channel, interceptors: _interceptors);
  late final breathSessionService = BreathSessionServiceClient(_channel, interceptors: _interceptors);
  late final deviceService = DeviceServiceClient(_channel, interceptors: _interceptors);
  late final moduleStateService = ModuleStateServiceClient(_channel, interceptors: _interceptors);
  late final instructionStreamService = ModuleInstructionStreamServiceClient(_channel, interceptors: _interceptors);
  late final statsService = StatsServiceClient(_channel, interceptors: _interceptors);
  late final syncService = SyncServiceClient(_channel, interceptors: _interceptors);
  late final userService = UserServiceClient(_channel, interceptors: _interceptors);

  Future<void> shutdown() async {
    _detachSubscription?.cancel();
    await _channel.shutdown();
  }
}
