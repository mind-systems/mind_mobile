import 'package:mind/Bci/IBciDevicesGrpcApi.dart';
import 'package:mind/Core/Grpc/generated/bci_devices.pbgrpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';

class BciDevicesGrpcApi implements IBciDevicesGrpcApi {
  final BciDevicesServiceClient _client;

  BciDevicesGrpcApi(this._client);

  @override
  Future<List<({String id, String serial})>> listDevices() async {
    final response = await _client.list(Empty());
    return response.devices.map((d) => (id: d.id, serial: d.serial)).toList();
  }

  @override
  Future<({String id, String serial})> register(String serial) async {
    final response = await _client.register(RegisterBciDeviceRequest(serial: serial));
    return (id: response.id, serial: response.serial);
  }

  @override
  Future<void> delete(String id) async {
    await _client.delete(DeleteBciDeviceRequest(id: id));
  }
}
