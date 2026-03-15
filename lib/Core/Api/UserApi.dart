import 'package:mind/Core/Api/HttpClient.dart';
import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';
import 'package:mind/User/IUserApi.dart';
import 'package:mind/User/Models/UserStatsDTO.dart';

class UserApi implements IUserApi {
  final HttpClient _http;

  UserApi(this._http);

  @override
  Future<void> updateUser(UpdateUserRequest request) async {
    await _http.patch('/user', data: request.toJson());
  }

  @override
  Future<UserStatsDTO> fetchStats() async {
    final response = await _http.get('/users/me/stats');
    return UserStatsDTO.fromJson(response.data as Map<String, dynamic>);
  }
}
