abstract class IBciDevicesGrpcApi {
  Future<List<({String id, String serial})>> listDevices();
  Future<({String id, String serial})> register(String serial);
  Future<void> delete(String id);
}
