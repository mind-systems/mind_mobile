import 'package:mind/User/Models/User.dart';

class AuthRequest {
  final String token;
  final String name;
  final String email;

  AuthRequest({required this.token, required User user})
  : name = user.name,
    email = user.email;

  Map<String, dynamic> toJson() => {
    'token': token,
    'name': name,
    'email': email,
  };
}
