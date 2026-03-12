import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/Models/DevicePingRequest.dart';

class DeviceApi {
  final HttpClient _http;

  DeviceApi(this._http);

  Future<void> ping(DevicePingRequest request) async {
    await _http.post('/device/ping', data: request.toJson());
  }
}
