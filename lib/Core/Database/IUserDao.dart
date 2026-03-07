import 'package:mind/User/Models/User.dart';

abstract class IUserDao {
  Future<User?> getUser();
  Future<void> saveUser(User user);
  Future<void> deleteUser(String id);
}
