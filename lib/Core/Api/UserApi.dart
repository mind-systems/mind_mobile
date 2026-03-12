import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/User/IUserApi.dart';

class UserApi implements IUserApi {
  final HttpClient _http;

  UserApi(this._http);

  @override
  Future<void> updateUser(UpdateUserRequest request) async {
    await _http.patch('/user', data: request.toJson());
  }
}
