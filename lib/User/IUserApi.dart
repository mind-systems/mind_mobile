import 'package:mind/Core/Api/Models/UpdateUserRequest.dart';

abstract class IUserApi {
  Future<void> updateUser(UpdateUserRequest request);
}
