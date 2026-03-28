import 'package:mind/Core/Api/Models/DevicePingRequest.dart';
import 'package:mind/Core/Grpc/generated/device.pb.dart' as proto;
import 'package:mind/Core/Grpc/generated/device.pbgrpc.dart' show DeviceServiceClient;

class DeviceApi {
  final DeviceServiceClient _deviceService;

  DeviceApi(this._deviceService);

  Future<void> ping(DevicePingRequest request) async {
    final protoRequest = proto.PingRequest(
      installationId: request.installationId,
      platform: request.platform,
      osVersion: request.osVersion,
      locale: request.locale,
      timezone: request.timezone,
      screenWidth: request.screenWidth,
      screenHeight: request.screenHeight,
      appVersion: request.appVersion,
      buildNumber: request.buildNumber,
      model: request.model,
      manufacturer: request.manufacturer,
    );
    await _deviceService.ping(protoRequest);
  }
}
